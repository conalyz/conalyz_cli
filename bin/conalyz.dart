import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:conalyz/src/optimized_ast_analyzer.dart';
import 'package:conalyz/src/platform_type.dart';
import 'package:conalyz/src/ast_report_generator.dart';
import 'package:conalyz/src/usage_storage_service.dart';
import 'package:conalyz/src/usage_models.dart';
import 'package:conalyz/src/usage_command.dart' show UsageCommand;
import 'package:conalyz/src/compose_oregex_analyzer.dart';
import 'package:conalyz/src/jetpack_compose_rules.dart';
import 'package:conalyz/src/compose_redundant_semantics_rules.dart';

// Version constant
const String version = '1.0.0';

void main(List<String> arguments) async {
  // Check if this is a usage command
  if (arguments.isNotEmpty && arguments[0] == 'usage') {
    await _handleUsageCommand(arguments.skip(1).toList());
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

/// Handles the analysis command (original functionality)
Future<void> _handleAnalysisCommand(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('version',
        abbr: 'v',
        help: 'Show version information',
        negatable: false)
    ..addOption('path',
        abbr: 'p', help: 'Path to Flutter project directory or dart file', mandatory: false)
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
    ..addFlag('debug', help: 'Enable debug output for troubleshooting', defaultsTo: false)
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
      print('A powerful Flutter & Jetpack Compose accessibility analyzer');
      return;
    }

    final projectPath = results['path'] as String?;
    if (projectPath == null) {
      print('Error: Project directory path is required. Use -h for help.');
      exit(1);
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
    if (isFile && !projectPath.endsWith('.dart') && !projectPath.endsWith('.kt')) {
      print('Error: File must be a Dart file (.dart) or Kotlin file (.kt): $projectPath');
      exit(1);
    }

    // Create output directory if it doesn't exist
    final outputDirectory = Directory(outputDir);
    if (!outputDirectory.existsSync()) {
      outputDirectory.createSync(recursive: true);
    }

    if (isFile) {
      final ext = projectPath.split('.').last;
      print('🔍 Analyzing $ext file for accessibility issues: ${projectPath.split('/').last}');
    } else {
      print('🔍 Analyzing project for accessibility issues (Platform: $platform)...');
    }
    
    if (enableDebug) {
      print('📁 Project path: $projectPath');
      print('🎯 Target platform: $platform');
      print('');
    }

    final startTime = DateTime.now();
    late AnalysisResult analysisResult;

    if (platform == 'mobile') {
      final isDirectory = FileSystemEntity.isDirectorySync(projectPath);
      
      bool hasDart = false;
      bool hasKotlin = false;
      
      if (isDirectory) {
        final dir = Directory(projectPath);
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            if (entity.path.endsWith('.dart')) hasDart = true;
            if (entity.path.endsWith('.kt')) hasKotlin = true;
          }
          if (hasDart && hasKotlin) break;
        }
      } else {
        hasDart = projectPath.endsWith('.dart');
        hasKotlin = projectPath.endsWith('.kt');
      }

      AnalysisResult? dartResult;
      AnalysisResult? kotlinResult;

      if (hasDart) {
        final flutterAnalyzer = OptimizedAstFlutterAccessibilityAnalyzer(enableDebugOutput: enableDebug);
        dartResult = isFile 
            ? await flutterAnalyzer.analyzeFile(projectPath, platform: PlatformType.mobile)
            : await flutterAnalyzer.analyzeProject(projectPath, platform: PlatformType.mobile);
      }

      if (hasKotlin) {
        final composeRules = [
          ComposeContentDescriptionRule(),
          ComposeTouchTargetRule(),
          ComposeHardcodedTextRule(),
          ComposeLazyListSemanticKeyRule(),
          ComposeReducedMotionRule(),
          ComposeTextFieldLabelRule(),
          ComposeClickableRoleRule(),
          ComposeToggleableSemanticsRule(),
          ComposeRedundantMergeDescendantsRule(),
          ComposeRedundantIsTraversalGroupRule(),
        ];
        final composeAnalyzer = ComposeAnalyzer(rules: composeRules);
        kotlinResult = isFile
            ? await composeAnalyzer.analyzeFile(projectPath, platform: PlatformType.mobile)
            : await composeAnalyzer.analyzeProject(projectPath, platform: PlatformType.mobile);
      }

      if (dartResult != null && kotlinResult != null) {
        analysisResult = _mergeAnalysisResults(dartResult, kotlinResult);
      } else {
        analysisResult = dartResult ?? kotlinResult ?? _emptyResult(PlatformType.mobile, projectPath);
      }
    } else {
      // web logic
      final analyzer = OptimizedAstFlutterAccessibilityAnalyzer(enableDebugOutput: enableDebug);

      analysisResult = isFile
          ? await analyzer.analyzeFile(
              projectPath,
              platform: PlatformType.web,
            )
          : await analyzer.analyzeProject(
              projectPath,
              platform: PlatformType.web,
            );
    }

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
    print('📊 Files: ${analysisResult.analyzedFiles.length} | Lines: ${analysisResult.linesScanned}');
    print('🐛 Issues: ${analysisResult.totalIssues} (🔴${analysisResult.issuesBySeverity['critical']} 🟠${analysisResult.issuesBySeverity['high']} 🟡${analysisResult.issuesBySeverity['medium']} 🟢${analysisResult.issuesBySeverity['low']})');
    
    if (enableDebug) {
      print('');
      print('💡 Tip: Run "conalyz usage" to view your analysis statistics and track your progress over time.');
    }

    // Exit with error code if critical issues found
    if ((analysisResult.issuesBySeverity['critical'] ?? 0) > 0) {
      print('');
      print('⚠️  Critical accessibility issues found. Consider fixing them.');
      exit(1);
    }
  } catch (e) {
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
  print(
      '  conalyz usage                    # Show basic usage statistics');
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
      'AST & Oregex-based Accessibility Analyzer with comprehensive widget coverage.');
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
  print('');
  print('Examples:');
  print(
      '  conalyz --path ./my_app         # Analyze Flutter project for mobile');
  print(
      '  conalyz --path ./my_app --platform web  # Analyze for web platform');
  print(
      '  conalyz --output ./reports      # Custom output directory');
  print(
      '  conalyz usage                   # View your usage statistics');
  print(
      '  conalyz usage --detailed        # View detailed usage analytics');
  print('');
  print('Features:');
  print('  • Comprehensive Flutter/Compose widget accessibility analysis');
  print('  • Support for mobile and web platforms');
  print('  • Automatic usage tracking (lines scanned, analysis time)');
  print('  • JSON and HTML report generation');
  print('  • Detailed usage statistics and productivity insights');
}

/// Merges two AnalysisResults into one
AnalysisResult _mergeAnalysisResults(AnalysisResult a, AnalysisResult b) {
  final mergedIssues = [...a.issues, ...b.issues];
  final mergedFiles = {...a.analyzedFiles, ...b.analyzedFiles}.toList();
  final mergedSeverity = <String, int>{};
  
  for (final severity in ['critical', 'high', 'medium', 'low']) {
    mergedSeverity[severity] = (a.issuesBySeverity[severity] ?? 0) + (b.issuesBySeverity[severity] ?? 0);
  }

  return AnalysisResult(
    totalIssues: a.totalIssues + b.totalIssues,
    issuesBySeverity: mergedSeverity,
    issues: mergedIssues,
    analyzedFiles: mergedFiles,
    timestamp: a.timestamp,
    platform: a.platform,
    linesScanned: a.linesScanned + b.linesScanned,
  );
}

/// Returns an empty AnalysisResult
AnalysisResult _emptyResult(PlatformType platform, String projectPath) {
  return AnalysisResult(
    totalIssues: 0,
    issuesBySeverity: {'critical': 0, 'high': 0, 'medium': 0, 'low': 0},
    issues: [],
    analyzedFiles: [projectPath],
    timestamp: DateTime.now().toIso8601String(),
    platform: platform,
    linesScanned: 0,
  );
}
