import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:conalyz/src/ast_report_generator.dart';
import 'package:conalyz/src/optimized_ast_analyzer.dart';
import 'package:conalyz/src/platform_type.dart';
import 'package:conalyz/src/constants.dart';
import 'package:conalyz/src/telemetry.dart';
import 'package:conalyz/src/update_command.dart' show UpdateCommand;
import 'package:conalyz/src/usage_command.dart' show UsageCommand;
import 'package:conalyz/src/usage_models.dart';
import 'package:conalyz/src/usage_storage_service.dart';
import 'package:path/path.dart' as path;

// Version constant — source of truth is lib/src/constants.dart
const String version = conalyzVersion;

void main(List<String> arguments) async {
  await checkFirstRunNotice();

  // Check if this is a usage command
  if (arguments.isNotEmpty && arguments[0] == 'usage') {
    await _handleUsageCommand(arguments.skip(1).toList());
    return;
  }

  // Check if this is an update command
  if (arguments.isNotEmpty && arguments[0] == 'update') {
    await _handleUpdateCommand(arguments.skip(1).toList());
    return;
  }

  // Handle analysis command (default behavior)
  await _handleAnalysisCommand(arguments);
}

/// Handles the usage command and its flags
Future<void> _handleUsageCommand(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('detailed',
        help: 'Show detailed usage statistics with recent sessions',
        negatable: false)
    ..addFlag('help',
        abbr: 'h', help: 'Show usage command help', negatable: false);

  try {
    final results = parser.parse(arguments);

    if (results['help']) {
      _showUsageHelp(parser);
      return;
    }

    final usageCommand = UsageCommand();

    if (results['detailed']) {
      await usageCommand.showDetailedUsage();
    } else {
      await usageCommand.showBasicUsage();
    }
  } catch (e) {
    print('❌ Error: $e');
    print('');
    _showUsageHelp(parser);
    exit(1);
  }
}

/// Handles the update command and its flags
Future<void> _handleUpdateCommand(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', help: 'Show update command help', negatable: false);

  try {
    final results = parser.parse(arguments);

    if (results['help']) {
      _showUpdateHelp(parser);
      return;
    }

    final updateCommand = UpdateCommand();
    await updateCommand.update();
  } catch (e) {
    print('❌ Error: $e');
    print('');
    _showUpdateHelp(parser);
    exit(1);
  }
}

/// Shows help for the update command
void _showUpdateHelp(ArgParser parser) {
  print('🔄 Conalyz CLI - Update');
  print('');
  print('Usage: conalyz update');
  print('');
  print('Updates the conalyz CLI to the latest version available on pub.dev.');
  print('');
  print('Options:');
  print(parser.usage);
}

/// Handles the analysis command (original functionality)
Future<void> _handleAnalysisCommand(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('version',
        abbr: 'v', help: 'Show version information', negatable: false)
    ..addOption('dir',
        abbr: 'd',
        help: 'Flutter project root; analysis runs on <dir>/lib',
        mandatory: false)
    ..addOption('path',
        abbr: 'p',
        help:
            '(Deprecated) Path to Flutter project directory or dart file; use --dir instead',
        mandatory: false)
    ..addOption('platform',
        abbr: 't',
        help: 'Target platform (mobile/web)',
        defaultsTo: 'mobile',
        allowed: ['mobile', 'web'])
    ..addOption('output',
        abbr: 'o',
        help: 'Output directory for reports',
        defaultsTo: 'accessibility_report')
    ..addFlag('json', help: 'Generate JSON report', defaultsTo: true)
    ..addFlag('html', help: 'Generate HTML report', defaultsTo: true)
    ..addFlag('debug',
        help: 'Enable debug output for troubleshooting', defaultsTo: false)
    ..addFlag('help',
        abbr: 'h', help: 'Show this help message', negatable: false);

  try {
    final results = parser.parse(arguments);

    if (results['help']) {
      _showAnalysisHelp(parser);
      return;
    }

    if (results['version']) {
      print('Conalyz CLI v$version');
      print('A powerful Flutter accessibility analyzer');
      return;
    }

    // Resolve project path: --dir takes precedence, then --path (deprecated), then default to current dir.
    final String projectPath;
    if (results.wasParsed('path')) {
      stderr.writeln(
          'Warning: --path is deprecated, use --dir instead. '
          'Example: conalyz --dir ${results['path']}');
      projectPath = results['path'] as String;
    } else {
      final dir = (results['dir'] as String?) ?? '.';
      projectPath = path.join(dir, 'lib');
    }
    final platform = results['platform'] as String;
    final outputDir = results['output'] as String;
    final generateJson = results['json'] as bool;
    final generateHtml = results['html'] as bool;
    final enableDebug = results['debug'] as bool;

    // Check daily file limit before proceeding
    final usageService = UsageStorageService();
    // Estimate files to analyze (1 for single file, will be more for directories)
    final filesToAnalyze = FileSystemEntity.isFileSync(projectPath) ? 1 : 100;

    final limitCheck = await usageService.checkDailyLimit(filesToAnalyze);
    if (limitCheck != null) {
      print('❌ $limitCheck');
      print('💡 You can check your usage with: conalyz usage');
      exit(1);
    }

    // Validate path exists and is either a file or directory
    final pathEntity = FileSystemEntity.typeSync(projectPath);
    if (pathEntity == FileSystemEntityType.notFound) {
      print('Error: Path does not exist: $projectPath');
      exit(1);
    }

    final isFile = pathEntity == FileSystemEntityType.file;
    if (isFile && !projectPath.endsWith('.dart')) {
      print('Error: File must be a Dart file (.dart): $projectPath');
      exit(1);
    }

    // Create output directory if it doesn't exist
    final outputDirectory = Directory(outputDir);
    if (!outputDirectory.existsSync()) {
      outputDirectory.createSync(recursive: true);
    }

    if (isFile) {
      print(
          '🔍 Analyzing Dart file for accessibility issues: ${projectPath.split('/').last}');
    } else {
      print('🔍 Analyzing Flutter project for accessibility issues...');
    }
    if (enableDebug) {
      print('📁 Project path: $projectPath');
      print('🎯 Target platform: $platform');
      print('');
    }

    // Create optimized analyzer with built-in rules (includes all latest rules and widget recognition)
    final analyzer = OptimizedAstFlutterAccessibilityAnalyzer(
        enableDebugOutput: enableDebug);

    final startTime = DateTime.now();

    // Analyze the project or file
    final analysisResult = isFile
        ? await analyzer.analyzeFile(
            projectPath,
            platform:
                platform == 'mobile' ? PlatformType.mobile : PlatformType.web,
          )
        : await analyzer.analyzeProject(
            projectPath,
            platform:
                platform == 'mobile' ? PlatformType.mobile : PlatformType.web,
          );

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    // Record usage statistics
    try {
      final usageService = UsageStorageService();
      final usageRecord = UsageRecord(
        timestamp: startTime,
        linesScanned: analysisResult.linesScanned,
        projectPath: projectPath,
        platform: platform,
        analysisTimeMs: duration.inMilliseconds,
        filesAnalyzed: analysisResult.analyzedFiles.length,
        analysisDate: DateTime.now().toUtc(),
      );
      await usageService.recordUsage(usageRecord);
    } catch (e) {
      // Don't fail the analysis if usage recording fails
      print('Warning: Failed to record usage statistics: $e');
    }

    // Generate reports
    final reportGenerator = AstReportGenerator();

    if (generateJson) {
      final jsonPath = path.join(outputDir, 'accessibility_report.json');
      await reportGenerator.generateJsonReport(analysisResult, jsonPath);
      print('📄 JSON report generated at: $jsonPath');
    }

    if (generateHtml) {
      final htmlPath = path.join(outputDir, 'accessibility_report.html');
      await reportGenerator.generateHtmlReport(analysisResult, htmlPath);
      print('🌐 HTML report generated at: $htmlPath');
    }

    print('');
    print('✅ Analysis complete!');
    print('⏱️  Time: ${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s');
    print(
        '📊 Files: ${analysisResult.analyzedFiles.length} | Lines: ${analysisResult.linesScanned}');
    print(
        '🐛 Issues: ${analysisResult.totalIssues} (🔴${analysisResult.issuesBySeverity['critical']} 🟠${analysisResult.issuesBySeverity['high']} 🟡${analysisResult.issuesBySeverity['medium']} 🟢${analysisResult.issuesBySeverity['low']})');

    if (enableDebug) {
      print('');
      print(
          '💡 Tip: Run "conalyz usage" to view your analysis statistics and track your progress over time.');
    }

    // Compute per-type issue counts for telemetry
    final issueCounts = <String, int>{};
    for (final issue in analysisResult.issues) {
      issueCounts[issue.type] = (issueCounts[issue.type] ?? 0) + 1;
    }

    // Map internal severity names to telemetry buckets
    final severityBreakdown = {
      'error': (analysisResult.issuesBySeverity['critical'] ?? 0) +
          (analysisResult.issuesBySeverity['high'] ?? 0),
      'warning': analysisResult.issuesBySeverity['medium'] ?? 0,
      'info': analysisResult.issuesBySeverity['low'] ?? 0,
    };

    final outputFormat = (generateJson && generateHtml)
        ? 'both'
        : (generateJson ? 'json' : (generateHtml ? 'html' : 'none'));

    await Telemetry.trackAnalysis(
      durationMs: duration.inMilliseconds,
      filesScanned: analysisResult.analyzedFiles.length,
      linesScanned: analysisResult.linesScanned,
      totalIssues: analysisResult.totalIssues,
      issueCounts: issueCounts,
      severityBreakdown: severityBreakdown,
      outputFormat: outputFormat,
      platformTarget: platform,
      usedCustomOutputPath: results.wasParsed('output'),
      usedDebugFlag: enableDebug,
      specificFileScan: isFile,
      exitReason: 'success',
      projectPath: projectPath,
    );

    await _printEndHints();

    // Exit with error code if critical issues found
    if ((analysisResult.issuesBySeverity['critical'] ?? 0) > 0) {
      print('');
      print('⚠️  Critical accessibility issues found. Consider fixing them.');
      exit(1);
    }
  } catch (e) {
    Telemetry.trackError(e.runtimeType.toString());
    print('❌ Error: $e');
    print('');
    _showAnalysisHelp(parser);
    exit(1);
  }
}

/// Shows help for the usage command
void _showUsageHelp(ArgParser parser) {
  print('📊 Conalyz CLI - Usage Statistics');
  print('');
  print('Usage: conalyz usage [options]');
  print('');
  print(
      'Display usage statistics and analytics for your Flutter accessibility analysis sessions.');
  print(
      'Track lines scanned, analysis frequency, and productivity insights over time.');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  conalyz usage                    # Show basic usage statistics');
  print(
      '  conalyz usage --detailed         # Show detailed usage with recent sessions');
  print('');
  print('Basic Statistics Include:');
  print('  • Total lines scanned across all analysis sessions');
  print('  • Number of analysis sessions performed');
  print('  • Date range of usage (first and last analysis)');
  print('  • Average lines scanned per session');
  print('  • Total files analyzed and average analysis time');
  print('');
  print('Detailed Statistics Include:');
  print('  • Platform usage breakdown (mobile vs web)');
  print('  • Recent analysis session history');
  print('  • Productivity insights and largest sessions');
  print('  • Most productive days');
}

/// Shows help for the analysis command
void _showAnalysisHelp(ArgParser parser) {
  print('🔍 Conalyz CLI - Accessibility Analyzer');
  print('');
  print('Usage: conalyz [options]');
  print('       conalyz usage [usage-options]');
  print('');
  print(
      'AST-based Flutter Accessibility Analyzer with comprehensive widget coverage.');
  print(
      'Automatically tracks usage statistics including lines scanned and analysis frequency.');
  print('');
  print('Analysis Options:');
  print(parser.usage);
  print('');
  print('Commands:');
  print(
      '  usage                                              # Show usage statistics and analytics');
  print(
      '  usage --detailed                                   # Show detailed usage with session history');
  print(
      '  update                                             # Update Conalyz to the latest version');
  print('');
  print('Examples:');
  print('  conalyz --dir .             # Analyze current Flutter project');
  print('  conalyz --dir ./my_app      # Analyze a specific project');
  print(
      '  conalyz --dir ./my_app --platform web  # Analyze for web platform');
  print('  conalyz --output ./reports  # Custom output directory');
  print('  conalyz usage               # View your usage statistics');
  print('  conalyz usage --detailed    # View detailed usage analytics');
  print('  conalyz update              # Update to the latest version');
  print('');
  print('Features:');
  print('  • Comprehensive Flutter widget accessibility analysis');
  print('  • Support for both mobile and web platforms');
  print('  • Automatic usage tracking (lines scanned, analysis time)');
  print('  • JSON and HTML report generation');
  print('  • Detailed usage statistics and productivity insights');
}

// ── End-of-run hints ──────────────────────────────────────────────────────────

/// Prints an update hint if a newer version is on pub.dev, and a runtime hint
/// if the user is not already running the Homebrew binary.
Future<void> _printEndHints() async {
  final isHomebrew = await _isHomebrewOnPath();
  if (isHomebrew) return;

  final latestVersion = await _latestPubDevVersion()
      .timeout(const Duration(milliseconds: 1500), onTimeout: () => null);

  final hints = <String>[];
  if (latestVersion != null && _isNewerVersion(latestVersion, version)) {
    hints.add('  Update available: v$latestVersion → run conalyz update');
  }
  hints.add('  Runtime analysis available → brew install conalyz/tap/conalyz');

  print('');
  for (final h in hints) {
    print(h);
  }
}

/// Returns true when `which conalyz` resolves to a Homebrew-managed path.
Future<bool> _isHomebrewOnPath() async {
  try {
    final result = await Process.run('which', ['conalyz']);
    final p = result.stdout.toString().trim().toLowerCase();
    return p.contains('homebrew') || p.contains('cellar');
  } catch (_) {
    return false;
  }
}

/// Fetches the latest published version from pub.dev. Returns null on failure.
Future<String?> _latestPubDevVersion() async {
  try {
    final client = HttpClient();
    final req = await client
        .getUrl(Uri.parse('https://pub.dev/api/packages/conalyz'));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    client.close();
    final data = jsonDecode(body) as Map<String, dynamic>;
    return (data['latest'] as Map<String, dynamic>)['version'] as String?;
  } catch (_) {
    return null;
  }
}

/// Returns true when [latest] is strictly newer than [current] (X.Y.Z).
bool _isNewerVersion(String latest, String current) {
  int part(String v, int i) {
    final parts = v.split('.');
    return i < parts.length ? int.tryParse(parts[i]) ?? 0 : 0;
  }

  for (var i = 0; i < 3; i++) {
    final l = part(latest, i);
    final c = part(current, i);
    if (l > c) return true;
    if (l < c) return false;
  }
  return false;
}
