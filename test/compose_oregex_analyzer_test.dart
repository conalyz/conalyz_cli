import 'dart:io';
import 'package:test/test.dart';
import 'package:conalyz/src/compose_oregex_analyzer.dart';
import 'package:conalyz/src/jetpack_compose_rules.dart';
import 'package:conalyz/src/platform_type.dart';
import 'package:conalyz/src/optimized_ast_analyzer.dart';

void main() {
  group('Compose Oregex Analyzer Core Parsing Tests', () {
    late Directory tempDir;
    late ComposeAnalyzer analyzer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('compose_test_');
      analyzer = ComposeAnalyzer(rules: [ComposeContentDescriptionRule()]);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<AnalysisResult> analyzeSource(String source) async {
      final file = File('${tempDir.path}/Test.kt');
      await file.writeAsString(source);
      return await analyzer.analyzeFile(file.path, platform: PlatformType.mobile);
    }

    test('should match composables properly and extract context', () async {
      const source = '''
      @Composable
      fun MyComponent() {
          Image(
              painter = painterResource(R.drawable.img),
              contentDescription = "Valid desc"
          )
      }
      ''';
      
      final result = await analyzeSource(source);
      // It has contentDescription, so 0 issues
      expect(result.totalIssues, 0);
    });

    test('should flag missing content description', () async {
      const source = '''
      @Composable
      fun BadComponent() {
          Image(
              painter = painterResource(R.drawable.img)
          )
      }
      ''';
      
      final result = await analyzeSource(source);
      expect(result.totalIssues, 1);
      expect(result.issues.first.type, 'Missing Content Description');
    });

    test('should skip line comments inside string literals', () async {
      const source = '''
      val url = "https://example.com"
      Image(painter = painterResource(id)) // Missing content description
      ''';
      
      final result = await analyzeSource(source);
      // Should not skip the Image due to the url containing "//"
      expect(result.totalIssues, 1);
    });

    test('should skip genuine line comments', () async {
      const source = '''
      // Image(painter = p)
      ''';
      
      final result = await analyzeSource(source);
      // The image is commented out, shouldn't be matched
      expect(result.totalIssues, 0);
    });

    test('should balance braces properly', () async {
      // Create a dummy rule just to capture the widget info
      final captureRule = _MockCaptureRule('Button');
      final customAnalyzer = ComposeAnalyzer(rules: [captureRule]);
      
      final file = File('${tempDir.path}/Test.kt');
      await file.writeAsString('''
      Button(onClick = { 
         val a = { 1 + 1 }
      }) {
         Text("Hello")
      }
      ''');
      await customAnalyzer.analyzeFile(file.path, platform: PlatformType.mobile);
      
      expect(captureRule.capturedContext, isNotNull);
      expect(captureRule.capturedContext!.contains('Text("Hello")'), isTrue);
    });
  });
}

class _MockCaptureRule extends ComposeAccessibilityRule {
  final String target;
  String? capturedContext;

  _MockCaptureRule(this.target);

  @override
  String get ruleId => 'mock-rule';

  @override
  String get description => 'Mock';

  @override
  List<String> get targetComposables => [target];

  @override
  List<AccessibilityIssue> check(ComposeWidgetInfo widget, String filePath) {
    capturedContext = widget.sourceCode;
    return [];
  }
}
