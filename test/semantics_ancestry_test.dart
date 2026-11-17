import 'dart:io';

import 'package:conalyz/src/optimized_ast_analyzer.dart';
import 'package:conalyz/src/platform_type.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('semantics_ancestry_');
  });
  tearDown(() => directory.delete(recursive: true));

  Future<AnalysisResult> analyze(String expression) async {
    final file = File('${directory.path}/widget.dart');
    await file.writeAsString('Widget build() => $expression;');
    return OptimizedAstFlutterAccessibilityAnalyzer().analyzeFile(
      file.path,
      platform: PlatformType.mobile,
    );
  }

  int count(AnalysisResult result, String rule) =>
      result.issues.where((issue) => issue.rule == rule).length;
  const button = 'IconButton(icon: Icon(Icons.add), onPressed: () {})';

  test('identical sibling source does not inherit semantics', () async {
    final result = await analyze(
        "Column(children: [Semantics(label: 'Add', child: $button), $button])");
    for (final rule in [
      'WCAG-2.5.3',
      'iconbutton-accessibility',
      'WCAG-1.1.1-Icon'
    ]) {
      expect(count(result, rule), 1, reason: rule);
    }
  });

  test('a wrapper in a different function does not suppress findings',
      () async {
    final file = File('${directory.path}/functions.dart');
    await file.writeAsString(
        "Widget first() => Semantics(label: 'Add', child: $button);\nWidget second() => $button;");
    final result = await OptimizedAstFlutterAccessibilityAnalyzer()
        .analyzeFile(file.path, platform: PlatformType.mobile);
    for (final rule in [
      'WCAG-2.5.3',
      'iconbutton-accessibility',
      'WCAG-1.1.1-Icon'
    ]) {
      final issues = result.issues.where((issue) => issue.rule == rule);
      expect(issues, hasLength(1), reason: rule);
      expect(issues.single.line, 2);
    }
  });

  for (final properties in ['', "key: Key('k'), "]) {
    test(
        'empty or key-only semantics do not supply accessibility information: $properties',
        () async {
      final result = await analyze('Semantics(${properties}child: $button)');
      for (final rule in [
        'WCAG-2.5.3',
        'iconbutton-accessibility',
        'WCAG-1.1.1-Icon'
      ]) {
        expect(count(result, rule), 1, reason: rule);
      }
    });
  }

  for (final type in ['Semantics', 'SliverSemantics']) {
    test('$type with a label covers actual descendants through layout widgets',
        () async {
      final result = await analyze(
          "$type(label: 'Add', ${type == 'SliverSemantics' ? 'sliver' : 'child'}: Padding(padding: EdgeInsets.zero, child: $button))");
      expect(count(result, 'WCAG-2.5.3'), 0);
      expect(count(result, 'iconbutton-accessibility'), 0);
      expect(count(result, 'WCAG-1.1.1-Icon'), 0);
    });
  }

  test('attributed labels also label their descendant buttons', () async {
    final result = await analyze(
        "Semantics(attributedLabel: AttributedString('Add'), child: $button)");
    expect(count(result, 'WCAG-2.5.3'), 0);
    expect(count(result, 'iconbutton-accessibility'), 0);
  });

  test('roles and merging do not substitute for a button label', () async {
    final result = await analyze(
        'Column(children: [Semantics(button: true, child: $button), MergeSemantics(child: $button)])');
    expect(count(result, 'WCAG-2.5.3'), 2);
    expect(count(result, 'iconbutton-accessibility'), 2);
  });

  for (final label in ["''", "'   '", 'null', "('')", '(null)']) {
    test('literal $label does not label a button', () async {
      final result = await analyze('Semantics(label: $label, child: $button)');
      expect(count(result, 'WCAG-2.5.3'), 1);
      expect(count(result, 'iconbutton-accessibility'), 1);
    });
  }

  test('MergeSemantics still supplies context for switches and checkboxes',
      () async {
    final result = await analyze(
        'Column(children: [MergeSemantics(child: Switch(value: true, onChanged: (_) {})), MergeSemantics(child: Checkbox(value: true, onChanged: (_) {}))])');
    expect(
        result.issues.where((issue) =>
            issue.type == 'Missing Switch Semantics' ||
            issue.type == 'Missing Checkbox Semantics'),
        isEmpty);
  });

  test('tooltip covers its own disabled child, not an identical sibling',
      () async {
    const disabled = "TextButton(onPressed: null, child: Text('Save'))";
    final result = await analyze(
        "Column(children: [Tooltip(message: 'Saving', child: $disabled), $disabled])");
    expect(count(result, 'disabled-elements'), 1);
  });

  test('direct button labels and unrelated empty-text checks remain active',
      () async {
    final result = await analyze(
        "Semantics(label: 'Add', child: Column(children: [IconButton(tooltip: 'Add', icon: Icon(Icons.add), onPressed: () {}), Text('')]))");
    expect(count(result, 'WCAG-2.5.3'), 0);
    expect(count(result, 'iconbutton-accessibility'), 0);
    expect(result.issues.where((issue) => issue.rule == 'empty-text-widgets'),
        isNotEmpty);
  });
}
