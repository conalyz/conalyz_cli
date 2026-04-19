import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:conalyz/src/optimized_ast_analyzer.dart';
import 'package:conalyz/src/platform_type.dart';
import 'package:test/test.dart';

void main() {
  group('MobileTabAccessibilityRule Tests', () {
    late MobileTabAccessibilityRule rule;

    setUp(() {
      rule = MobileTabAccessibilityRule();
    });

    test('should flag TabBar without semanticLabel AND without readable tabs',
        () {
      const code = '''
        TabBar(
          tabs: [
            Tab(icon: Icon(Icons.home)),
            Tab(icon: Icon(Icons.settings)),
          ],
        )
      ''';

      final widget = _extractWidgetInfo('TabBar', code);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
      expect(issues.first.type, equals('Missing Tab Semantics'));
    });

    test(
        'should NOT flag TabBar without semanticLabel but with readable text tabs',
        () {
      const code = '''
        TabBar(
          tabs: [
            Tab(text: 'Home'),
            Tab(text: 'Settings'),
          ],
        )
      ''';

      final widget = _extractWidgetInfo('TabBar', code);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });

    test('should NOT flag TabBar with child Text widgets', () {
      const code = '''
        TabBar(
          tabs: [
            Tab(child: Text('Home')),
            Tab(child: Text('Settings')),
          ],
        )
      ''';

      final widget = _extractWidgetInfo('TabBar', code);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });

    test('should flag TabBar if at least one tab is not readable', () {
      const code = '''
        TabBar(
          tabs: [
            Tab(text: 'Home'),
            Tab(icon: Icon(Icons.settings)),
          ],
        )
      ''';

      final widget = _extractWidgetInfo('TabBar', code);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
    });

    test('should NOT flag TabBar with RichText in child tree', () {
      const code = '''
        TabBar(
          tabs: [
            Tab(child: Column(children: [RichText(text: TextSpan(text: 'Home'))])),
            Tab(text: 'Settings'),
          ],
        )
      ''';

      final widget = _extractWidgetInfo('TabBar', code);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, isEmpty);
    });

    test('should flag TabBar with empty text tabs', () {
      const code = '''
        TabBar(
          tabs: [
            Tab(text: ''),
            Tab(text: 'Settings'),
          ],
        )
      ''';

      final widget = _extractWidgetInfo('TabBar', code);
      final issues = rule.check(widget, 'test.dart', PlatformType.mobile);

      expect(issues, hasLength(1));
    });
  });
}

WidgetInfo _extractWidgetInfo(String type, String sourceCode) {
  final fullCode = '''
class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return $sourceCode;
  }
}
''';
  final parseResult = parseString(
    content: fullCode,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );

  final visitor =
      OptimizedWidgetExtractionVisitor(fullCode, parseResult.unit, false);
  parseResult.unit.accept(visitor);

  if (visitor.widgets.isEmpty) {
    throw Exception(
        'No widgets found in source code. Found nodes: ${parseResult.unit.childEntities}');
  }

  return visitor.widgets.firstWhere(
    (w) => w.type == type,
    orElse: () => throw Exception(
        'Widget of type $type not found. Found: ${visitor.widgets.map((w) => w.type)}'),
  );
}
