import 'package:test/test.dart';
import 'package:conalyz/src/flutter_specific_rules.dart';
import 'package:conalyz/src/optimized_ast_analyzer.dart'
    show WidgetInfo, OptimizedWidgetExtractionVisitor;
import 'package:conalyz/src/platform_type.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';

void main() {
  group('MergeSemanticsRule Tests', () {
    late MergeSemanticsRule rule;

    setUp(() {
      rule = MergeSemanticsRule();
    });

    test('should identify MergeSemantics without multiple semantic children',
        () {
      const code = '''
        MergeSemantics(
          child: Text('Single child'),
        )
      ''';

      final widget = _createWidgetInfo('MergeSemantics', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('medium'));
      expect(issues.first.type, equals('Unnecessary MergeSemantics'));
    });

    test('should not flag MergeSemantics with multiple semantic children', () {
      const code = '''
        MergeSemantics(
          child: Column(
            children: [
              Semantics(label: 'First', child: Text('First')),
              Semantics(label: 'Second', child: Text('Second')),
            ],
          ),
        )
      ''';

      final widget = _createWidgetInfo('MergeSemantics', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });
  });

  group('TapTargetSizeRule Tests', () {
    late TapTargetSizeRule rule;

    setUp(() {
      rule = TapTargetSizeRule();
    });

    test('should flag GestureDetector without adequate tap target size', () {
      const code = '''
        GestureDetector(
          onTap: () {},
          child: Icon(Icons.star),
        )
      ''';

      final widget = _createWidgetInfo('GestureDetector', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('high'));
      expect(issues.first.type, equals('Small Tap Target'));
    });

    test('should not flag IconButton with default adequate size', () {
      const code = '''
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.star),
        )
      ''';

      final widget = _createWidgetInfo('IconButton', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });

    test('should not flag widget with explicit sizing', () {
      const code = '''
        GestureDetector(
          onTap: () {},
          child: Container(
            width: 48,
            height: 48,
            child: Icon(Icons.star),
          ),
        )
      ''';

      final widget = _createWidgetInfo('GestureDetector', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });
  });

  group('AnimationControlRule Tests', () {
    late AnimationControlRule rule;

    setUp(() {
      rule = AnimationControlRule();
    });

    test('should flag AnimatedContainer without reduced motion support', () {
      const code = '''
        AnimatedContainer(
          duration: Duration(seconds: 1),
          width: 100,
          height: 100,
        )
      ''';

      final widget = _createWidgetInfo('AnimatedContainer', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('medium'));
      expect(issues.first.type, equals('Animation Without Motion Control'));
    });

    test('should not flag animation with reduced motion support', () {
      const code = '''
        AnimatedContainer(
          duration: MediaQuery.of(context).disableAnimations 
            ? Duration.zero 
            : Duration(seconds: 1),
          width: 100,
          height: 100,
        )
      ''';

      final widget = _createWidgetInfo('AnimatedContainer', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });
  });

  group('CustomErrorAnnouncementRule Tests', () {
    late CustomErrorAnnouncementRule rule;

    setUp(() {
      rule = CustomErrorAnnouncementRule();
    });

    test('should flag custom error handling without announcements', () {
      const code = '''
        Form(
          child: Column(
            children: [
              TextFormField(),
              if (hasError) {
                setState(() {});
                Text('An error occurred');
              }
            ],
          ),
        )
      ''';

      final widget = _createWidgetInfo('Form', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('high'));
      expect(issues.first.type, equals('Error Not Announced'));
    });

    test('should not flag error handling with SemanticsService.announce', () {
      const code = '''
        Form(
          child: Column(
            children: [
              TextFormField(),
              if (hasError) {
                SemanticsService.announce('Error occurred', TextDirection.ltr);
                Text('Error occurred');
              }
            ],
          ),
        )
      ''';

      final widget = _createWidgetInfo('Form', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });
  });

  group('HeadingStructureRule Tests', () {
    late HeadingStructureRule rule;

    setUp(() {
      rule = HeadingStructureRule();
    });

    test('should flag semantic heading without sort key', () {
      const code = '''
        Semantics(
          header: true,
          child: Text('Heading'),
        )
      ''';

      final widget = _createWidgetInfo('Semantics', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('medium'));
      expect(issues.first.type, equals('Heading Structure'));
    });

    test('should not flag heading with sort key', () {
      const code = '''
        Semantics(
          header: true,
          sortKey: OrdinalSortKey(1.0),
          child: Text('Heading'),
        )
      ''';

      final widget = _createWidgetInfo('Semantics', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });
  });

  group('TableHeadersRule Tests', () {
    late TableHeadersRule rule;

    setUp(() {
      rule = TableHeadersRule();
    });

    test('should flag Table without proper structure', () {
      const code = '''
        Table(
          children: [
            TableRow(children: [Text('Cell 1'), Text('Cell 2')]),
          ],
        )
      ''';

      final widget = _createWidgetInfo('Table', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('high'));
      expect(issues.first.type, equals('Table Structure'));
    });

    test('should not flag Table with proper TableRow and TableCell structure',
        () {
      const code = '''
        Table(
          children: [
            TableRow(
              children: [
                TableCell(child: Text('Header 1')),
                TableCell(child: Text('Header 2')),
              ],
            ),
          ],
        )
      ''';

      final widget = _createWidgetInfo('Table', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });
  });

  group('LiveRegionRule Tests', () {
    late LiveRegionRule rule;

    setUp(() {
      rule = LiveRegionRule();
    });

    test('should flag dynamic content without live region', () {
      const code = '''
        Column(
          children: [
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: Text('Update'),
            ),
            Text(dynamicContent),
          ],
        )
      ''';

      final widget = _createWidgetInfo('Column', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('high'));
      expect(issues.first.type, equals('Live Region'));
    });
  });

  group('TextScalingSupportRule Tests', () {
    late TextScalingSupportRule rule;

    setUp(() {
      rule = TextScalingSupportRule();
    });

    test('should flag Text with hardcoded font size on mobile', () {
      const code = '''
        Text(
          'Hello',
          style: TextStyle(fontSize: 16),
        )
      ''';

      final widget = _createWidgetInfo('Text', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('medium'));
      expect(issues.first.type, equals('Text Scaling Issue'));
    });

    test('should flag very small text size on mobile', () {
      const code = '''
        Text(
          'Small text',
          style: TextStyle(fontSize: 8),
        )
      ''';

      final widget = _createWidgetInfo('Text', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(2)); // Both hardcoded size and small text issues
      expect(issues.any((issue) => issue.type == 'Small Text Size'), isTrue);
      expect(issues.any((issue) => issue.severity == 'high'), isTrue);
    });

    test('should not flag Text with theme-based styling', () {
      const code = '''
        Text(
          'Hello',
          style: Theme.of(context).textTheme.bodyLarge,
        )
      ''';

      final widget = _createWidgetInfo('Text', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });

    test('should have lower severity on web platform', () {
      const code = '''
        Text(
          'Hello',
          style: TextStyle(fontSize: 16),
        )
      ''';

      final widget = _createWidgetInfo('Text', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.web);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('low'));
      expect(issues.first.type, equals('Text Scaling'));
    });
  });

  group('ScaffoldNavigationRule Tests', () {
    late ScaffoldNavigationRule rule;

    setUp(() {
      rule = ScaffoldNavigationRule();
    });

    test('should flag Scaffold without navigation elements', () {
      const code = '''
        Scaffold(
          body: Center(
            child: Text('Hello World'),
          ),
        )
      ''';

      final widget = _createWidgetInfo('Scaffold', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('medium'));
      expect(issues.first.type, equals('Scaffold Navigation'));
    });

    test('should not flag Scaffold with AppBar', () {
      const code = '''
        Scaffold(
          appBar: AppBar(title: Text('Title')),
          body: Center(
            child: Text('Hello World'),
          ),
        )
      ''';

      final widget = _createWidgetInfo('Scaffold', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });

    test('should not flag Scaffold with BottomNavigationBar', () {
      const code = '''
        Scaffold(
          body: Center(child: Text('Hello World')),
          bottomNavigationBar: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
            ],
          ),
        )
      ''';

      final widget = _createWidgetInfo('Scaffold', code, 1, 1);
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

  // Create a mock visitor
  final visitor =
      OptimizedWidgetExtractionVisitor(sourceCode, parseResult.unit, false);

  return WidgetInfo(
    type: type,
    line: line,
    column: column,
    properties: properties ?? {},
    sourceCode: sourceCode,
    compilationUnit: parseResult.unit,
    node: parseResult.unit, // Using compilation unit as a placeholder node
    visitor: visitor,
  );
}
