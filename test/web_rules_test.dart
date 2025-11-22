import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_access_advisor_cli/src/web_rules.dart';
import 'package:flutter_access_advisor_cli/src/optimized_ast_analyzer.dart' show WidgetInfo, OptimizedWidgetExtractionVisitor;
import 'package:flutter_access_advisor_cli/src/platform_type.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';

void main() {
  group('WebSemanticHtmlRule Tests', () {
    late WebSemanticHtmlRule rule;

    setUp(() {
      rule = WebSemanticHtmlRule();
    });

    test('should only apply to web platform', () {
      const code = '''
        Semantics(
          child: Text('Content'),
        )
      ''';
      
      final widget = _createWidgetInfo('Semantics', code, 1, 1);
      
      // Should not flag on mobile
      final mobileIssues = rule.check(widget, 'test.dart', PlatformType.mobile);
      expect(mobileIssues, isEmpty);
      
      // Should flag on web
      final webIssues = rule.check(widget, 'test.dart', PlatformType.web);
      expect(webIssues, hasLength(1));
    });

    test('should flag Semantics without tagName on web', () {
      const code = '''
        Semantics(
          child: Text('Main content'),
        )
      ''';
      
      final widget = _createWidgetInfo('Semantics', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('medium'));
      expect(issues.first.type, equals('Web Semantics'));
      expect(issues.first.rule, equals('Web-Semantics'));
      expect(issues.first.suggestion, contains('tagName'));
    });

    test('should not flag Semantics with tagName on web', () {
      const code = '''
        Semantics(
          tagName: 'main',
          child: Text('Main content'),
        )
      ''';
      
      final widget = _createWidgetInfo('Semantics', code, 1, 1, {'tagName': 'main'});
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, isEmpty);
    });

    test('should not flag Semantics with tagName in source code', () {
      const code = '''
        Semantics(
          tagName: "section",
          child: Column(
            children: [
              Text('Section content'),
            ],
          ),
        )
      ''';
      
      final widget = _createWidgetInfo('Semantics', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, isEmpty);
    });
  });

  group('WebAriaLabelsRule Tests', () {
    late WebAriaLabelsRule rule;

    setUp(() {
      rule = WebAriaLabelsRule();
    });

    test('should only apply to web platform', () {
      const code = '''
        Semantics(
          button: true,
          child: Text('Click me'),
        )
      ''';
      
      final widget = _createWidgetInfo('Semantics', code, 1, 1);
      
      // Should not flag on mobile
      final mobileIssues = rule.check(widget, 'test.dart', PlatformType.mobile);
      expect(mobileIssues, isEmpty);
      
      // Should flag on web
      final webIssues = rule.check(widget, 'test.dart', PlatformType.web);
      expect(webIssues, hasLength(1));
    });

    test('should flag interactive Semantics without ARIA labels on web', () {
      const code = '''
        Semantics(
          button: true,
          onTap: () {},
          child: Icon(Icons.star),
        )
      ''';
      
      final widget = _createWidgetInfo('Semantics', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('high'));
      expect(issues.first.type, equals('Web ARIA'));
      expect(issues.first.rule, equals('Web-ARIA'));
      expect(issues.first.suggestion, contains('label and hint'));
    });

    test('should not flag interactive Semantics with label on web', () {
      const code = '''
        Semantics(
          button: true,
          label: 'Add to favorites',
          onTap: () {},
          child: Icon(Icons.star),
        )
      ''';
      
      final widget = _createWidgetInfo('Semantics', code, 1, 1, {'button': true, 'label': 'Add to favorites', 'onTap': true});
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, isEmpty);
    });

    test('should not flag interactive Semantics with hint on web', () {
      const code = '''
        Semantics(
          button: true,
          hint: 'Tap to add to favorites',
          onTap: () {},
          child: Icon(Icons.star),
        )
      ''';
      
      final widget = _createWidgetInfo('Semantics', code, 1, 1, {'button': true, 'hint': 'Tap to add to favorites', 'onTap': true});
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, isEmpty);
    });

    test('should not flag non-interactive Semantics without labels', () {
      const code = '''
        Semantics(
          child: Text('Static content'),
        )
      ''';
      
      final widget = _createWidgetInfo('Semantics', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, isEmpty);
    });

    test('should detect link semantics as interactive', () {
      const code = '''
        Semantics(
          link: true,
          child: Text('Visit our website'),
        )
      ''';
      
      final widget = _createWidgetInfo('Semantics', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, hasLength(1));
      expect(issues.first.type, equals('Web ARIA'));
    });
  });

  group('WebPageTitlesRule Tests', () {
    late WebPageTitlesRule rule;

    setUp(() {
      rule = WebPageTitlesRule();
    });

    test('should only apply to web platform', () {
      const code = '''
        MaterialApp(
          home: Scaffold(
            body: Text('Hello World'),
          ),
        )
      ''';
      
      final widget = _createWidgetInfo('MaterialApp', code, 1, 1);
      
      // Should not flag on mobile
      final mobileIssues = rule.check(widget, 'test.dart', PlatformType.mobile);
      expect(mobileIssues, isEmpty);
      
      // Should flag on web
      final webIssues = rule.check(widget, 'test.dart', PlatformType.web);
      expect(webIssues, hasLength(1));
    });

    test('should flag MaterialApp without title on web', () {
      const code = '''
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(),
            body: Text('Hello World'),
          ),
        )
      ''';
      
      final widget = _createWidgetInfo('MaterialApp', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('high'));
      expect(issues.first.type, equals('Web Title'));
      expect(issues.first.rule, equals('Web-Titles'));
      expect(issues.first.suggestion, contains('title property'));
    });

    test('should flag CupertinoApp without title on web', () {
      const code = '''
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Text('Hello World'),
          ),
        )
      ''';
      
      final widget = _createWidgetInfo('CupertinoApp', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('high'));
      expect(issues.first.type, equals('Web Title'));
    });

    test('should not flag MaterialApp with title on web', () {
      const code = '''
        MaterialApp(
          title: 'My Flutter App',
          home: Scaffold(
            body: Text('Hello World'),
          ),
        )
      ''';
      
      final widget = _createWidgetInfo('MaterialApp', code, 1, 1, {'title': 'My Flutter App'});
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, isEmpty);
    });

    test('should not flag CupertinoApp with title on web', () {
      const code = '''
        CupertinoApp(
          title: 'My iOS-style App',
          home: CupertinoPageScaffold(
            child: Text('Hello World'),
          ),
        )
      ''';
      
      final widget = _createWidgetInfo('CupertinoApp', code, 1, 1, {'title': 'My iOS-style App'});
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, isEmpty);
    });
  });

  group('WebFocusNavigationRule Tests', () {
    late WebFocusNavigationRule rule;

    setUp(() {
      rule = WebFocusNavigationRule();
    });

    test('should only apply to web platform', () {
      const code = '''
        Focus(
          child: TextField(),
        )
      ''';
      
      final widget = _createWidgetInfo('Focus', code, 1, 1);
      
      // Should not flag on mobile
      final mobileIssues = rule.check(widget, 'test.dart', PlatformType.mobile);
      expect(mobileIssues, isEmpty);
      
      // Should flag on web
      final webIssues = rule.check(widget, 'test.dart', PlatformType.web);
      expect(webIssues, hasLength(1));
    });

    test('should flag Focus without proper focus management on web', () {
      const code = '''
        Focus(
          child: Container(
            child: Text('Focusable content'),
          ),
        )
      ''';
      
      final widget = _createWidgetInfo('Focus', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, hasLength(1));
      expect(issues.first.severity, equals('medium'));
      expect(issues.first.type, equals('Web Focus'));
      expect(issues.first.rule, equals('Web-Focus'));
      expect(issues.first.suggestion, contains('focusNode or autofocus'));
    });

    test('should flag FocusScope without proper focus management on web', () {
      const code = '''
        FocusScope(
          child: Column(
            children: [
              TextField(),
              TextField(),
            ],
          ),
        )
      ''';
      
      final widget = _createWidgetInfo('FocusScope', code, 1, 1);
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, hasLength(1));
      expect(issues.first.type, equals('Web Focus'));
    });

    test('should not flag Focus with focusNode on web', () {
      const code = '''
        Focus(
          focusNode: myFocusNode,
          child: Container(
            child: Text('Focusable content'),
          ),
        )
      ''';
      
      final widget = _createWidgetInfo('Focus', code, 1, 1, {'focusNode': 'myFocusNode'});
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, isEmpty);
    });

    test('should not flag Focus with autofocus on web', () {
      const code = '''
        Focus(
          autofocus: true,
          child: TextField(),
        )
      ''';
      
      final widget = _createWidgetInfo('Focus', code, 1, 1, {'autofocus': true});
      final issues = rule.check(widget, 'test.dart', PlatformType.web);
      
      expect(issues, isEmpty);
    });
  });
}

// Helper function to create WidgetInfo for testing
WidgetInfo _createWidgetInfo(String type, String sourceCode, int line, int column, [Map<String, dynamic>? properties]) {
  // Parse the source code to create a proper AST
  final parseResult = parseString(
    content: sourceCode,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  
  // Create a mock visitor
  final visitor = OptimizedWidgetExtractionVisitor(sourceCode, parseResult.unit, false);
  
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