import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:conalyz/src/optimized_ast_analyzer.dart';
import 'package:conalyz/src/platform_type.dart';
import 'package:test/test.dart';

void main() {
  group('ImageAccessibilityRule Tests', () {
    late ImageAccessibilityRule rule;

    setUp(() {
      rule = ImageAccessibilityRule();
    });

    test('should flag Image without semanticLabel', () {
      const code = '''
        Image.asset('assets/image.png')
      ''';

      final widget = _createWidgetInfo('Image', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('critical'));
      expect(issues.first.type, equals('Missing Alt Text'));
      expect(issues.first.rule, equals('WCAG-1.1.1'));
    });

    test('should not flag Image with semanticLabel', () {
      const code = '''
        Image.asset(
          'assets/image.png',
          semanticLabel: 'A beautiful landscape',
        )
      ''';

      final widget = _createWidgetInfo(
          'Image', code, 1, 1, {'semanticLabel': 'A beautiful landscape'});
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });
  });

  group('FormLabelRule Tests', () {
    late FormLabelRule rule;

    setUp(() {
      rule = FormLabelRule();
    });

    test('should flag TextField without label or decoration', () {
      const code = '''
        TextField()
      ''';

      final widget = _createWidgetInfo('TextField', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('critical'));
      expect(issues.first.type, equals('TextField Without Label'));
      expect(issues.first.rule, equals('WCAG-1.3.1'));
    });

    test('should not flag TextField with labelText', () {
      const code = '''
        TextField(
          decoration: InputDecoration(
            labelText: 'Enter your name',
          ),
        )
      ''';

      final widget = _createWidgetInfo('TextField', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });

    test('should not flag TextField with hintText', () {
      const code = '''
        TextField(
          decoration: InputDecoration(
            hintText: 'Enter your name',
          ),
        )
      ''';

      final widget = _createWidgetInfo('TextField', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });

    test('should flag TextFormField without label', () {
      const code = '''
        TextFormField()
      ''';

      final widget = _createWidgetInfo('TextFormField', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('critical'));
    });
  });

  group('ButtonLabelRule Tests', () {
    late ButtonLabelRule rule;

    setUp(() {
      rule = ButtonLabelRule();
    });

    test('should flag IconButton without tooltip or semanticLabel', () {
      const code = '''
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.star),
        )
      ''';

      final widget = _createWidgetInfo('IconButton', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('high'));
      expect(issues.first.type, equals('Button Without Label'));
      expect(issues.first.rule, equals('WCAG-2.5.3'));
    });

    test('should not flag IconButton with tooltip', () {
      const code = '''
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.star),
          tooltip: 'Add to favorites',
        )
      ''';

      final widget = _createWidgetInfo(
          'IconButton', code, 1, 1, {'tooltip': 'Add to favorites'});
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });

    test('should not flag ElevatedButton with Text child', () {
      const code = '''
        ElevatedButton(
          onPressed: () {},
          child: Text('Click me'),
        )
      ''';

      final widget = _createWidgetInfo('ElevatedButton', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });

    test('should flag FloatingActionButton without label', () {
      const code = '''
        FloatingActionButton(
          onPressed: () {},
          child: Icon(Icons.add),
        )
      ''';

      final widget = _createWidgetInfo('FloatingActionButton', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('high'));
    });
  });

  group('GestureDetectorAccessibilityRule Tests', () {
    late GestureDetectorAccessibilityRule rule;

    setUp(() {
      rule = GestureDetectorAccessibilityRule();
    });

    test('should flag GestureDetector without semantics on mobile', () {
      const code = '''
        GestureDetector(
          onTap: () {},
          child: Container(
            width: 100,
            height: 100,
            color: Colors.blue,
          ),
        )
      ''';

      final widget = _createWidgetInfo('GestureDetector', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('high'));
      expect(issues.first.type, equals('GestureDetector Without Semantics'));
      expect(issues.first.rule, equals('WCAG-2.1.1'));
    });

    test('should flag GestureDetector with critical severity on web', () {
      const code = '''
        GestureDetector(
          onTap: () {},
          child: Container(
            width: 100,
            height: 100,
            color: Colors.blue,
          ),
        )
      ''';

      final widget = _createWidgetInfo('GestureDetector', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.web);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('critical'));
    });
  });

  group('ColorContrastRule Tests', () {
    late ColorContrastRule rule;

    setUp(() {
      rule = ColorContrastRule();
    });

    test('should flag problematic color combinations', () {
      const code = '''
        Container(
          color: Colors.yellow,
          child: Text(
            'Hello',
            style: TextStyle(color: Colors.white),
          ),
        )
      ''';

      final widget = _createWidgetInfo('Container', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(
          issues,
          hasLength(greaterThan(
              0))); // May have multiple issues (contrast + theme recommendation)
      expect(issues.any((issue) => issue.severity == 'critical'), isTrue);
      expect(
          issues.any((issue) => issue.type == 'Color Contrast Issue'), isTrue);
      expect(issues.any((issue) => issue.rule == 'WCAG-1.4.3'), isTrue);
    });

    test('should suggest using theme colors for custom colors', () {
      const code = '''
        Text(
          'Hello',
          style: TextStyle(color: Colors.blue),
        )
      ''';

      final widget = _createWidgetInfo('Text', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('low'));
      expect(issues.first.type, equals('Theme Color Recommendation'));
    });

    test('should not flag theme-based colors', () {
      const code = '''
        Text(
          'Hello',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        )
      ''';

      final widget = _createWidgetInfo('Text', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });
  });

  group('CheckboxAccessibilityRule Tests', () {
    late CheckboxAccessibilityRule rule;

    setUp(() {
      rule = CheckboxAccessibilityRule();
    });

    test('should flag Checkbox without semantic information', () {
      const code = '''
        Checkbox(
          value: true,
          onChanged: (value) {},
        )
      ''';

      final widget = _createWidgetInfo('Checkbox', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('high'));
      expect(issues.first.type, equals('Missing Checkbox Semantics'));
    });

    test('should not flag Checkbox wrapped in MergeSemantics', () {
      const code = '''
        Widget build(BuildContext context) {
          return MergeSemantics(
            child: ListTile(
              title: Text('Accept terms'),
              trailing: Checkbox(
                value: true,
                onChanged: (value) {},
              ),
            ),
          );
        }
      ''';

      final widget = _createWidgetInfo('Checkbox', code, 7, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty,
          reason:
              'Checkbox inside MergeSemantics should be considered accessible');
    });
  });

  group('SwitchAccessibilityRule Tests', () {
    late SwitchAccessibilityRule rule;

    setUp(() {
      rule = SwitchAccessibilityRule();
    });

    test('should flag Switch without semantic information', () {
      const code = '''
        Switch(
          value: true,
          onChanged: (value) {},
        )
      ''';

      final widget = _createWidgetInfo('Switch', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('high'));
      expect(issues.first.type, equals('Missing Switch Semantics'));
    });

    test('should not flag Switch wrapped in MergeSemantics', () {
      const code = '''
        Widget build(BuildContext context) {
          return MergeSemantics(
            child: ListTile(
              title: Text('Enable notifications'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
              ),
            ),
          );
        }
      ''';

      final widget = _createWidgetInfo('Switch', code, 7, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty,
          reason:
              'Switch inside MergeSemantics should be considered accessible');
    });
  });

  group('ProgressIndicatorAccessibilityRule Tests', () {
    late ProgressIndicatorAccessibilityRule rule;

    setUp(() {
      rule = ProgressIndicatorAccessibilityRule();
    });

    test('should flag CircularProgressIndicator without semantic label', () {
      const code = '''
        CircularProgressIndicator()
      ''';

      final widget = _createWidgetInfo('CircularProgressIndicator', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('medium'));
      expect(issues.first.type, equals('Missing Progress Indicator Label'));
    });

    test('should not flag LinearProgressIndicator with semanticsLabel', () {
      const code = '''
        LinearProgressIndicator(
          semanticsLabel: 'Loading progress',
        )
      ''';

      final widget = _createWidgetInfo('LinearProgressIndicator', code, 1, 1,
          {'semanticsLabel': 'Loading progress'});
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });
  });

  group('EmptyTextWidgetsRule Tests', () {
    late EmptyTextWidgetsRule rule;

    setUp(() {
      rule = EmptyTextWidgetsRule();
    });

    test('should flag Text widget with empty string', () {
      const code = '''
        Text("")
      ''';

      final widget = _createWidgetInfo('Text', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('medium'));
      expect(issues.first.type, equals('Empty Text Widget'));
    });

    test('should flag Text widget with empty single quotes', () {
      const code = '''
        Text('')
      ''';

      final widget = _createWidgetInfo('Text', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('medium'));
    });

    test('should not flag Text widget with content', () {
      const code = '''
        Text('Hello World')
      ''';

      final widget = _createWidgetInfo('Text', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });
  });

  group('VagueTextContentRule Tests', () {
    late VagueTextContentRule rule;

    setUp(() {
      rule = VagueTextContentRule();
    });

    test('should flag vague text content', () {
      const code = '''
        Text("Click Here")
      ''';

      final widget = _createWidgetInfo('Text', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('medium'));
      expect(issues.first.type, equals('Vague Text Content'));
      expect(issues.first.rule, equals('WCAG-2.4.4'));
    });

    test('should flag "Read More" text', () {
      const code = '''
        Text("Read More")
      ''';

      final widget = _createWidgetInfo('Text', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.type, equals('Vague Text Content'));
    });

    test('should not flag descriptive text', () {
      const code = '''
        Text("Read more about accessibility guidelines")
      ''';

      final widget = _createWidgetInfo('Text', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });
  });
}

// Helper function to create WidgetInfo for testing
WidgetInfo _createWidgetInfo(
    String type, String sourceCode, int line, int column,
    [Map<String, dynamic>? properties]) {
  // Parse the source code to create a proper AST
  final parseResult = parseString(
    content: sourceCode,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );

  // Create a visitor and visit the unit to populate the widgets list
  final visitor =
      OptimizedWidgetExtractionVisitor(sourceCode, parseResult.unit, false);
  parseResult.unit.visitChildren(visitor);

  // Find the actual node for the widget we want to test if it's in the list
  AstNode node = parseResult.unit;
  try {
    node = visitor.widgets.firstWhere((w) {
      // Match by type name, including handling for named constructors (e.g. Image.asset)
      return w.type == type || w.type.split('.').first == type;
    }).node;
  } catch (_) {
    // If not found in the extracted widgets, fallback to the compilation unit
  }

  return WidgetInfo(
    type: type,
    line: line,
    column: column,
    properties: properties ?? {},
    sourceCode: sourceCode,
    compilationUnit: parseResult.unit,
    node: node,
    visitor: visitor,
  );
}
