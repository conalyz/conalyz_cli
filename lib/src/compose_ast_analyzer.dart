// lib/src/compose_ast_analyzer.dart

import 'dart:io';
import 'optimized_ast_analyzer.dart'; // reuse AccessibilityIssue and AnalysisResult
import 'platform_type.dart';

/// Holds metadata about a detected Jetpack Compose UI component (e.g. composable)
/// including its position, type, and surrounding code context for rule evaluation.
class ComposeWidgetInfo {
  final String type;
  final int line;
  final int column;
  final String sourceCode; // surrounding source context
  final Map<String, String> properties;

  const ComposeWidgetInfo({
    required this.type,
    required this.line,
    required this.column,
    required this.sourceCode,
    this.properties = const {},
  });
}

/// Abstract base class for defining Native Android (Jetpack Compose) accessibility checks.
/// Rules inherited from this must specify their target composables and their evaluation logic.
abstract class ComposeAccessibilityRule {
  String get ruleId;
  String get description;
  List<String> get targetComposables;

  List<AccessibilityIssue> check(ComposeWidgetInfo widget, String filePath);
}

/// Main AST-based analyzer for parsing Kotlin code and validating Jetpack Compose UI
/// nodes against a suite of accessibility rules. Processes `.kt` files to generate
/// a comprehensive [AnalysisResult].
class ComposeAnalyzer {
  final List<ComposeAccessibilityRule> rules;
  static const int _contextLines = 30;

  ComposeAnalyzer({required this.rules});

  Future<AnalysisResult> analyzeFile(String filePath, {required PlatformType platform}) async {
    final file = File(filePath);
    if (!file.existsSync() || !filePath.endsWith('.kt')) {
      return AnalysisResult(
        totalIssues: 0,
        issuesBySeverity: {},
        issues: [],
        analyzedFiles: [filePath],
        timestamp: DateTime.now().toIso8601String(),
        platform: platform,
        linesScanned: 0,
      );
    }

    final lines = await file.readAsLines();
    final issues = <AccessibilityIssue>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final rule in rules) {
        for (final composable in rule.targetComposables) {
          // Match composable call at start of a line (ignoring comments)
          if (RegExp('^\\s*$composable\\s*[\\({(]').hasMatch(line) &&
              !line.trimLeft().startsWith('//')) {
            final startLine = (i - _contextLines).clamp(0, lines.length - 1);
            final endLine = (i + _contextLines).clamp(0, lines.length - 1);
            final context = lines.sublist(startLine, endLine + 1).join('\n');

            final widget = ComposeWidgetInfo(
              type: composable,
              line: i + 1,
              column: line.indexOf(composable) + 1,
              sourceCode: context,
            );

            issues.addAll(rule.check(widget, filePath));
          }
        }
      }
    }

    final issuesBySeverity = {
      'critical': issues.where((i) => i.severity == 'critical').length,
      'high': issues.where((i) => i.severity == 'high').length,
      'medium': issues.where((i) => i.severity == 'medium').length,
      'low': issues.where((i) => i.severity == 'low').length,
    };

    return AnalysisResult(
      totalIssues: issues.length,
      issuesBySeverity: issuesBySeverity,
      issues: issues,
      analyzedFiles: [filePath],
      timestamp: DateTime.now().toIso8601String(),
      platform: platform,
      linesScanned: lines.length,
    );
  }

  Future<AnalysisResult> analyzeProject(String projectPath, {required PlatformType platform}) async {
    final issues = <AccessibilityIssue>[];
    final analyzedFiles = <String>[];
    int totalLinesScanned = 0;

    final dir = Directory(projectPath);
    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.kt')) {
          final result = await analyzeFile(entity.path, platform: platform);
          issues.addAll(result.issues);
          if (result.linesScanned > 0) {
            analyzedFiles.add(entity.path);
          }
          totalLinesScanned += result.linesScanned;
        }
      }
    }

    final issuesBySeverity = {
      'critical': issues.where((i) => i.severity == 'critical').length,
      'high': issues.where((i) => i.severity == 'high').length,
      'medium': issues.where((i) => i.severity == 'medium').length,
      'low': issues.where((i) => i.severity == 'low').length,
    };

    return AnalysisResult(
      totalIssues: issues.length,
      issuesBySeverity: issuesBySeverity,
      issues: issues,
      analyzedFiles: analyzedFiles,
      timestamp: DateTime.now().toIso8601String(),
      platform: platform,
      linesScanned: totalLinesScanned,
    );
  }
}