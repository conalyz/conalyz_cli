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

    final fullCode = await file.readAsString();
    final issues = <AccessibilityIssue>[];

    for (final rule in rules) {
      for (final composable in rule.targetComposables) {
        // Match the composable name followed by an opening brace or parenthesis
        final regex = RegExp('\\b$composable\\s*[{(]');
        final matches = regex.allMatches(fullCode);

        for (final match in matches) {
           // Skip if it is embedded in a line comment
           int lineStart = fullCode.lastIndexOf('\n', match.start);
           lineStart = lineStart == -1 ? 0 : lineStart + 1;
           String linePrefix = fullCode.substring(lineStart, match.start);
           if (linePrefix.contains('//')) {
             continue; // inside a line comment
           }
           
           // Extract block accurately using brace balancing
           String context = _extractComposableContext(fullCode, match.start);
           
           final location = _getLineAndColumn(fullCode, match.start);
           final widget = ComposeWidgetInfo(
             type: composable,
             line: location['line']!,
             column: location['column']!,
             sourceCode: context,
           );
           
           issues.addAll(rule.check(widget, filePath));
        }
      }
    }

    final issuesBySeverity = {
      'critical': issues.where((i) => i.severity == 'critical').length,
      'high': issues.where((i) => i.severity == 'high').length,
      'medium': issues.where((i) => i.severity == 'medium').length,
      'low': issues.where((i) => i.severity == 'low').length,
    };

    final linesScanned = fullCode.split('\n').length;

    return AnalysisResult(
      totalIssues: issues.length,
      issuesBySeverity: issuesBySeverity,
      issues: issues,
      analyzedFiles: [filePath],
      timestamp: DateTime.now().toIso8601String(),
      platform: platform,
      linesScanned: linesScanned,
    );
  }

  /// Calculates the 1-indexed line and column for a given string index
  Map<String, int> _getLineAndColumn(String code, int index) {
    int line = 1;
    int column = 1;
    for (int i = 0; i < index && i < code.length; i++) {
      if (code[i] == '\n') {
        line++;
        column = 1;
      } else {
        column++;
      }
    }
    return {'line': line, 'column': column};
  }

  /// Accurately extracts the source code context block around a composable match 
  /// using character-by-character bracket and parenthesis balancing.
  String _extractComposableContext(String fullCode, int matchIndex) {
    int openCount = 0;
    bool started = false;
    bool inString = false;
    bool inChar = false;
    
    int endIndex = matchIndex;
    
    for (int i = matchIndex; i < fullCode.length; i++) {
      String char = fullCode[i];
      
      // string literal toggle
      if (char == '"' && (i == 0 || fullCode[i-1] != '\\') && !inChar) {
        inString = !inString;
      }
      // char literal toggle
      if (char == "'" && (i == 0 || fullCode[i-1] != '\\') && !inString) {
        inChar = !inChar;
      }
      
      if (!inString && !inChar) {
        if (char == '(' || char == '{') {
          openCount++;
          started = true;
        } else if (char == ')' || char == '}') {
          openCount--;
        }
      }
      
      if (started && openCount == 0) {
        endIndex = i;
        break;
      }
    }
    
    // If we didn't find any block logic (extremely rare for standard composables)
    if (!started) {
      return fullCode.substring(matchIndex, (matchIndex + 50).clamp(0, fullCode.length));
    }
    
    return fullCode.substring(matchIndex, endIndex + 1);
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