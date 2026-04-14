import 'dart:io';
import 'package:test/test.dart';
import 'package:conalyz/src/compose_oregex_analyzer.dart';
import 'package:conalyz/src/jetpack_compose_rules.dart';
import 'package:conalyz/src/compose_redundant_semantics_rules.dart';
import 'package:conalyz/src/platform_type.dart';
import 'package:conalyz/src/optimized_ast_analyzer.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('compose_rules_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<AnalysisResult> analyzeSource(String source, ComposeAccessibilityRule rule) async {
    final analyzer = ComposeAnalyzer(rules: [rule]);
    final file = File('${tempDir.path}/Test.kt');
    await file.writeAsString(source);
    return await analyzer.analyzeFile(file.path, platform: PlatformType.mobile);
  }

  group('ComposeTouchTargetRule', () {
    final rule = ComposeTouchTargetRule();

    test('should flag small touch targets', () async {
      const source = 'Box(modifier = Modifier.size(32.dp)) { }';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 1);
      expect(result.issues.first.type, 'Small Touch Target');
    });

    test('should not flag targets with 48dp or larger', () async {
      const source = 'Box(modifier = Modifier.size(48.dp)) { }';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 0);
    });

    test('should not flag targets with fillMaxWidth', () async {
      const source = 'Box(modifier = Modifier.fillMaxWidth()) { }';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 0);
    });

    test('should not flag IconButton (assumed 48dp by Material3)', () async {
      const source = 'IconButton(onClick = {}) { Icon(...) }';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 0);
    });
  });

  group('ComposeHardcodedTextRule', () {
    final rule = ComposeHardcodedTextRule();

    test('should flag hardcoded text literals', () async {
      const source = 'Text("Hello World")';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 1);
      expect(result.issues.first.type, 'Hardcoded Text');
    });

    test('should not flag stringResource', () async {
      const source = 'Text(stringResource(R.string.hello))';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 0);
    });

    test('should ignore short strings (noise reduction)', () async {
      const source = 'Text("-")';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 0);
    });
  });

  group('ComposeLazyListSemanticKeyRule', () {
    final rule = ComposeLazyListSemanticKeyRule();

    test('should flag items block without keys', () async {
      const source = '''
      LazyColumn {
          items(list) { item -> Text(item) }
      }
      ''';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 1);
      expect(result.issues.first.type, 'Missing Semantic Keys in Lazy List');
    });

    test('should not flag items block with keys', () async {
      const source = '''
      LazyColumn {
          items(list, key = { it.id }) { item -> Text(item) }
      }
      ''';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 0);
    });
  });

  group('ComposeReducedMotionRule', () {
    final rule = ComposeReducedMotionRule();

    test('should flag animations without reduced motion check', () async {
      const source = 'AnimatedVisibility(visible = true) { }';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 1);
      expect(result.issues.first.type, 'Animation Without Motion Control');
    });

    test('should not flag if LocalReduceMotion is checked', () async {
      const source = 'AnimatedVisibility(visible = !LocalReduceMotion.current) { }';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 0);
    });
  });

  group('ComposeTextFieldLabelRule', () {
    final rule = ComposeTextFieldLabelRule();

    test('should flag TextField without label or placeholder', () async {
      const source = 'TextField(value = text, onValueChange = {})';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 1);
      expect(result.issues.first.type, 'TextField Missing Label');
    });

    test('should not flag TextField with label', () async {
      const source = 'TextField(value = text, onValueChange = {}, label = { Text("Name") })';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 0);
    });
  });

  group('ComposeClickableRoleRule', () {
    final rule = ComposeClickableRoleRule();

    test('should flag clickable modifier without role', () async {
      const source = 'Modifier.clickable { }';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 1);
      expect(result.issues.first.type, 'Missing Semantic Role on Clickable');
    });

    test('should not flag clickable modifier with role', () async {
      const source = 'Modifier.clickable(role = Role.Button) { }';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 0);
    });
  });

  group('ComposeToggleableSemanticsRule', () {
    final rule = ComposeToggleableSemanticsRule();

    test('should flag standalone toggleables', () async {
      const source = 'Checkbox(checked = true, onCheckedChange = {})';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 1);
      expect(result.issues.first.type, 'Standalone Toggleable');
    });

    test('should not flag toggleable with semantics', () async {
      const source = 'Checkbox(checked = true, onCheckedChange = {}, modifier = Modifier.semantics { contentDescription = "..." })';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 0);
    });
  });

  group('Redundant Semantics Rules', () {
    test('should flag redundant mergeDescendants = false', () async {
      final rule = ComposeRedundantMergeDescendantsRule();
      const source = 'Modifier.semantics(mergeDescendants = false) { }';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 1);
      expect(result.issues.first.type, 'Redundant Semantics (mergeDescendants)');
    });

    test('should flag redundant isTraversalGroup = false', () async {
      final rule = ComposeRedundantIsTraversalGroupRule();
      const source = 'Modifier.semantics(isTraversalGroup = false) { }';
      final result = await analyzeSource(source, rule);
      expect(result.totalIssues, 1);
      expect(result.issues.first.type, 'Redundant Semantics (isTraversalGroup)');
    });
  });
}
