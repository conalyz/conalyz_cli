import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';

const String _version = conalyzVersion;
const String _telemetryUrl = 'https://conalyz.codeanalyer.workers.dev';

String _homeDir() =>
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';

String _computeMachineId() {
  try {
    final raw = Platform.localHostname + Platform.operatingSystemVersion;
    return sha256.convert(utf8.encode(raw)).toString();
  } catch (_) {
    return 'anonymous';
  }
}

bool _shouldSkip() {
  final env = Platform.environment;
  if (env['CONALYZ_NO_ANALYTICS'] == 'true') return true;
  if (env['DO_NOT_TRACK'] == '1') return true;
  if (env.containsKey('CI') && env['CONALYZ_ANALYTICS'] != 'true') return true;
  return false;
}

Future<void> checkFirstRunNotice() async {
  try {
    final home = _homeDir();
    if (home.isEmpty) return;
    final flagFile = File('$home/.config/conalyz/telemetry_noticed.flag');
    if (!flagFile.existsSync()) {
      print(
          '💡 [conalyz] Notice: conalyz collects anonymous usage data (OS, issue types, command flags).');
      print('   No code, filenames, or personal data is collected.');
      print('   Opt out anytime: export CONALYZ_NO_ANALYTICS=true');
      print('');
      flagFile.parent.createSync(recursive: true);
      flagFile.writeAsStringSync('');
    }
  } catch (_) {}
}

Map<String, dynamic>? _loadLastRun() {
  try {
    final home = _homeDir();
    if (home.isEmpty) return null;
    final file = File('$home/.config/conalyz/last_run.json');
    if (!file.existsSync()) return null;
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

void _saveLastRun(int totalIssues) {
  try {
    final home = _homeDir();
    if (home.isEmpty) return;
    final file = File('$home/.config/conalyz/last_run.json');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode({
      'total_issues': totalIssues,
      'timestamp': DateTime.now().toIso8601String(),
    }));
  } catch (_) {}
}

String _projectSize(int fileCount) {
  if (fileCount < 20) return 'small';
  if (fileCount < 100) return 'medium';
  return 'large';
}

bool _isFlutter(String dirPath) {
  try {
    final pubspec = File('$dirPath/pubspec.yaml');
    if (!pubspec.existsSync()) return false;
    return pubspec.readAsStringSync().contains('flutter:');
  } catch (_) {
    return false;
  }
}

bool _isMonorepo(String dirPath) {
  try {
    int subPackageCount = 0;
    for (final entity in Directory(dirPath).listSync(recursive: false)) {
      if (entity is Directory) {
        if (File('${entity.path}/pubspec.yaml').existsSync()) {
          subPackageCount++;
          if (subPackageCount > 0) return true;
        }
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}

bool _hasTests(String dirPath) {
  try {
    return Directory('$dirPath/test').existsSync();
  } catch (_) {
    return false;
  }
}

class Telemetry {
  static void trackAnalysis({
    required int durationMs,
    required int filesScanned,
    required int linesScanned,
    required int totalIssues,
    required Map<String, int> issueCounts,
    required Map<String, int> severityBreakdown,
    required String outputFormat,
    required String platformTarget,
    required bool usedCustomOutputPath,
    required bool usedDebugFlag,
    required bool specificFileScan,
    required String exitReason,
    String projectPath = '',
  }) {
    if (_shouldSkip()) return;
    _doTrackAnalysis(
      durationMs: durationMs,
      filesScanned: filesScanned,
      linesScanned: linesScanned,
      totalIssues: totalIssues,
      issueCounts: issueCounts,
      severityBreakdown: severityBreakdown,
      outputFormat: outputFormat,
      platformTarget: platformTarget,
      usedCustomOutputPath: usedCustomOutputPath,
      usedDebugFlag: usedDebugFlag,
      specificFileScan: specificFileScan,
      exitReason: exitReason,
      projectPath: projectPath,
    );
  }

  static Future<void> _doTrackAnalysis({
    required int durationMs,
    required int filesScanned,
    required int linesScanned,
    required int totalIssues,
    required Map<String, int> issueCounts,
    required Map<String, int> severityBreakdown,
    required String outputFormat,
    required String platformTarget,
    required bool usedCustomOutputPath,
    required bool usedDebugFlag,
    required bool specificFileScan,
    required String exitReason,
    required String projectPath,
  }) async {
    try {
      final lastRun = _loadLastRun();
      final firstTimeRun = lastRun == null;
      final prevTotal = (lastRun?['total_issues'] as int?) ?? 0;
      final issuesFixed =
          firstTimeRun ? 0 : (prevTotal - totalIssues).clamp(0, prevTotal);
      final regressionDetected = !firstTimeRun && totalIssues > prevTotal;

      _saveLastRun(totalIssues);

      final dirPath = specificFileScan && projectPath.isNotEmpty
          ? File(projectPath).parent.path
          : projectPath;

      final issuesPerFile = filesScanned > 0 ? totalIssues / filesScanned : 0.0;

      final payload = <String, dynamic>{
        'client_id': _computeMachineId(),
        'event': 'analysis_complete',
        'version': _version,
        'platform': Platform.operatingSystem,
        'is_ci': Platform.environment.containsKey('CI'),
        'scan_duration_ms': durationMs,
        'files_scanned': filesScanned,
        'lines_scanned': linesScanned,
        'total_issues': totalIssues,
        'zero_issue_run': totalIssues == 0,
        'issues_per_file_avg': issuesPerFile.toStringAsFixed(1),
        'severity_breakdown': severityBreakdown,
        'issues_summary': issueCounts,
        'project_size': _projectSize(filesScanned),
        'is_flutter': dirPath.isNotEmpty ? _isFlutter(dirPath) : true,
        'is_monorepo': dirPath.isNotEmpty ? _isMonorepo(dirPath) : false,
        'has_tests': dirPath.isNotEmpty ? _hasTests(dirPath) : false,
        'output_format': outputFormat,
        'platform_target': platformTarget,
        'used_custom_output_path': usedCustomOutputPath,
        'used_debug_flag': usedDebugFlag,
        'specific_file_scan': specificFileScan,
        'first_time_run': firstTimeRun,
        'issues_fixed_since_last_run': issuesFixed,
        'regression_detected': regressionDetected,
        'exit_reason': exitReason,
        'error_type': null,
      };

      await http
          .post(
            Uri.parse(_telemetryUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  static void trackError(String errorType) {
    if (_shouldSkip()) return;
    _doTrackError(errorType);
  }

  static Future<void> _doTrackError(String errorType) async {
    try {
      final payload = <String, dynamic>{
        'client_id': _computeMachineId(),
        'event': 'error',
        'version': _version,
        'platform': Platform.operatingSystem,
        'error_type': errorType,
      };

      await http
          .post(
            Uri.parse(_telemetryUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }
}
