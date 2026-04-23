// lib/src/compose/compose_oregex_analyzer.dart

import 'dart:io';
import '../optimized_ast_analyzer.dart'; // reuse AccessibilityIssue and AnalysisResult
import '../platform_type.dart';

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

/// Main Oregex-based analyzer for parsing Kotlin code and validating Jetpack Compose UI
/// nodes against a suite of accessibility rules. Processes `.kt` files to generate
/// a comprehensive [AnalysisResult].
class ComposeAnalyzer {
  final List<ComposeAccessibilityRule> rules;

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

    // Precompute block comment ranges to skip matches inside /* ... */
    final blockCommentRanges = _computeBlockCommentRanges(fullCode);

    // Precompute line start offsets using native indexOf for maximum performance (O(N) with fast path)
    // This allows us to use binary search for line/column calculation in O(log N) instead of O(N).
    final lineStarts = <int>[0];
    int nlIndex = -1;
    while ((nlIndex = fullCode.indexOf('\n', nlIndex + 1)) != -1) {
      lineStarts.add(nlIndex + 1);
    }

    for (final rule in rules) {
      for (final composable in rule.targetComposables) {
        // Match the composable name followed by an opening brace or parenthesis
        // \b ensures we don't match substrings (e.g. 'CustomImage' instead of 'Image')
        // \s*[{(] matches the beginning of the parameter list or trailing lambda block
        // We filter out member-access matches (e.g., Modifier.clickable) post-hoc
        // instead of using lookbehind, which Dart does not reliably support.
        final regex = RegExp('\\b${RegExp.escape(composable)}\\s*[{(]');
        final matches = regex.allMatches(fullCode);

        for (final match in matches) {
           // Skip member-access matches for composables that don't contain a dot
           if (!composable.contains('.')) {
             var precedingIndex = match.start - 1;
             while (precedingIndex >= 0 && fullCode[precedingIndex].trim().isEmpty) {
               precedingIndex--;
             }
             if (precedingIndex >= 0 && fullCode[precedingIndex] == '.') {
               continue;
             }
           }
           // Skip if it is embedded in a line comment
           int lineStart = fullCode.lastIndexOf('\n', match.start);
           lineStart = lineStart == -1 ? 0 : lineStart + 1;
           String linePrefix = fullCode.substring(lineStart, match.start);
           if (_isInLineComment(linePrefix)) {
             continue; // inside a line comment
           }

           // Skip if inside a block comment (/* ... */)
           if (_isInBlockComment(match.start, blockCommentRanges)) {
             continue;
           }

           // Extract block accurately using brace balancing
           String context = _extractComposableContext(fullCode, match.start);
           
           final location = _getLineAndColumn(match.start, lineStarts);
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

    final linesScanned = lineStarts.length;

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

  /// Calculates the 1-indexed line and column for a given string index using binary search (O(log N))
  /// This is used for every reported issue, so O(log N) is significantly faster than O(N) linear search
  /// for large files with thousands of lines.
  Map<String, int> _getLineAndColumn(int index, List<int> lineStarts) {
    int low = 0;
    int high = lineStarts.length - 1;
    
    while (low <= high) {
      int mid = low + (high - low) ~/ 2;
      if (lineStarts[mid] == index) {
        low = mid + 1;
        break;
      } else if (lineStarts[mid] < index) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    
    final line = low;
    final column = index - lineStarts[line - 1] + 1;
    return {'line': line, 'column': column};
  }

  /// Evaluates if the line prefix contains a legitimate comment marker
  /// by skipping '//' tokens wrapped inside text literals like URLs, 
  /// escaped quotes, and triple-quoted blocks.
  /// Example: val url = "https://example.com" // This is a comment
  /// Only the second '//' should be treated as a comment marker.
  bool _isInLineComment(String linePrefix) {
    bool inString = false;
    bool inTripleString = false;
    bool inChar = false;
    bool escaped = false;
    
    for (int i = 0; i < linePrefix.length; i++) {
      if (inTripleString) {
        if (i + 2 < linePrefix.length && 
            linePrefix[i] == '"' && 
            linePrefix[i+1] == '"' && 
            linePrefix[i+2] == '"') {
          inTripleString = false;
          i += 2;
        }
        continue;
      }
      
      if (escaped) {
        escaped = false;
        continue;
      }
      
      if (linePrefix[i] == '\\' && !inTripleString) {
        escaped = true;
        continue;
      }
      
      // Triple string start
      if (i + 2 < linePrefix.length && 
          linePrefix[i] == '"' && 
          linePrefix[i+1] == '"' && 
          linePrefix[i+2] == '"' && 
          !inChar && !inString) {
        inTripleString = true;
        i += 2;
        continue;
      }

      String c = linePrefix[i];
      if (c == '"' && !inChar && !inTripleString) {
        inString = !inString;
      } else if (c == "'" && !inString && !inTripleString) {
        inChar = !inChar;
      } else if (!inString && !inChar && !inTripleString && 
                 c == '/' && i + 1 < linePrefix.length && 
                 linePrefix[i+1] == '/') {
        return true;
      }
    }
    return false;
  }

  /// Precomputes all block comment ranges (/* ... */) in the source code.
  /// Returns a list of [start, end] pairs sorted by start offset.
  List<List<int>> _computeBlockCommentRanges(String code) {
    final ranges = <List<int>>[];
    final regex = RegExp(r'/\*[\s\S]*?\*/');
    for (final match in regex.allMatches(code)) {
      ranges.add([match.start, match.end]);
    }
    return ranges;
  }

  /// Returns true if the given offset falls inside any precomputed block comment range.
  bool _isInBlockComment(int offset, List<List<int>> ranges) {
    for (final range in ranges) {
      if (offset >= range[0] && offset < range[1]) return true;
      if (range[0] > offset) break; // ranges are sorted
    }
    return false;
  }

  /// Accurately extracts the source code context block around a composable match 
  /// using character-by-character bracket and parenthesis balancing, heavily accounting
  /// for Jetpack Compose's trailing lambda syntax.
  /// 
  /// How it works:
  /// 1. Iterates from the match index, keeping track of open/closed brackets () and braces {}.
  /// 2. Ignores brackets inside string or char literals to avoid false closing.
  /// 3. If a block is closed, it performs a 1-character lookahead to see if a trailing lambda {} follows.
  /// 4. If a trailing lambda is found, it continues balancing until that block is also closed.
  String _extractComposableContext(String fullCode, int matchIndex) {
    int openCount = 0;
    bool started = false;
    bool inString = false;
    bool inChar = false;
    bool waitingForTrailingLambda = false;
    
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
          waitingForTrailingLambda = false;
        } else if (char == ')' || char == '}') {
          openCount--;
        }
      }
      
      if (started && openCount == 0 && !waitingForTrailingLambda) {
        bool hasTrailingLambda = false;
        for (int j = i + 1; j < fullCode.length; j++) {
          if (fullCode[j].trim().isEmpty) continue;
          if (fullCode[j] == '{') {
            hasTrailingLambda = true;
          }
          break;
        }
        
        if (hasTrailingLambda) {
          waitingForTrailingLambda = true;
        } else {
          endIndex = i;
          break;
        }
      }
    }
    
    // If we didn't find any block logic (extremely rare for standard composables)
    // We fallback to a fixed 50 character context to avoid crashing and still provide some info.
    if (!started) {
      final end = (matchIndex + 50).clamp(0, fullCode.length);
      return fullCode.substring(matchIndex, end);
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