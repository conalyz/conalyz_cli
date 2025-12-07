// New Flutter-specific accessibility rules

import 'package:analyzer/dart/ast/ast.dart';
import 'optimized_ast_analyzer.dart';
import 'platform_type.dart';

class MergeSemanticsRule extends AccessibilityRule {
  @override
  String get ruleId => 'merge-semantics';

  @override
  String get description => 'Proper use of MergeSemantics for logical grouping';

  @override
  List<String> get targetWidgets => ['MergeSemantics'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'MergeSemantics') {
      // Check if MergeSemantics is used appropriately with multiple semantic children
      if (!_hasMultipleSemanticChildren(widget)) {
        issues.add(AccessibilityIssue(
          id: 'merge-semantics-${widget.line}',
          severity: 'medium',
          type: 'Unnecessary MergeSemantics',
          message: 'MergeSemantics used without multiple semantic children',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Use MergeSemantics only when grouping multiple widgets with semantic information',
        ));
      }
    }

    return issues;
  }

  bool _hasMultipleSemanticChildren(WidgetInfo widget) {
    // Simplified check - in real implementation would traverse AST
    final semanticsCount = 'Semantics'.allMatches(widget.sourceCode).length;
    return semanticsCount >= 2;
  }
}

class TapTargetSizeRule extends AccessibilityRule {
  @override
  String get ruleId => 'tap-target-size';

  @override
  String get description => 'Interactive targets must be at least 48x48dp';

  @override
  List<String> get targetWidgets => [
        'GestureDetector',
        'InkWell',
        'IconButton',
        'ElevatedButton',
        'TextButton'
      ];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if ([
      'GestureDetector',
      'InkWell',
      'IconButton',
      'ElevatedButton',
      'TextButton'
    ].contains(widget.type)) {
      if (!_hasAdequateTapTargetSize(widget)) {
        issues.add(AccessibilityIssue(
          id: 'tap-target-size-${widget.line}',
          severity: 'high',
          type: 'Small Tap Target',
          message: 'Interactive element may be smaller than 48x48dp minimum',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Ensure interactive targets are at least 48x48dp. Use padding, constraints, or SizedBox to increase touch area.',
        ));
      }
    }

    return issues;
  }

  bool _hasAdequateTapTargetSize(WidgetInfo widget) {
    final code = widget.sourceCode;
    // Check for explicit sizing
    if (code.contains(RegExp(r'width:\s*[4-9][0-9]')) ||
        code.contains(RegExp(r'height:\s*[4-9][0-9]')) ||
        code.contains('constraints:') ||
        code.contains('padding:')) {
      return true;
    }
    // IconButton and buttons typically have adequate default sizes
    return ['IconButton', 'ElevatedButton', 'TextButton'].contains(widget.type);
  }
}

class AnimationControlRule extends AccessibilityRule {
  @override
  String get ruleId => 'animation-control';

  @override
  String get description =>
      'Animations should respect reduced motion preferences';

  @override
  List<String> get targetWidgets =>
      ['AnimatedContainer', 'AnimatedOpacity', 'AnimationController'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (['AnimatedContainer', 'AnimatedOpacity', 'AnimationController']
        .contains(widget.type)) {
      if (!_respectsReducedMotion(widget)) {
        issues.add(AccessibilityIssue(
          id: 'animation-control-${widget.line}',
          severity: 'medium',
          type: 'Animation Without Motion Control',
          message: 'Animation does not respect reduced motion preferences',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Check MediaQuery.of(context).disableAnimations or provide animation toggle',
        ));
      }
    }

    return issues;
  }

  bool _respectsReducedMotion(WidgetInfo widget) {
    final code = widget.sourceCode;
    return code.contains('disableAnimations') ||
        code.contains('MediaQuery') ||
        code.contains('ReducedMotion');
  }
}

class CustomErrorAnnouncementRule extends AccessibilityRule {
  @override
  String get ruleId => 'custom-error-announcement';

  @override
  String get description =>
      'Custom errors should be announced to assistive technology';

  @override
  List<String> get targetWidgets => ['Form', 'TextFormField', 'Scaffold'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (_hasCustomErrorHandling(widget) && !_announcesErrors(widget)) {
      issues.add(AccessibilityIssue(
        id: 'error-announcement-${widget.line}',
        severity: 'high',
        type: 'Error Not Announced',
        message: 'Custom error handling without accessibility announcements',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Use SemanticsService.announce() or Semantics liveRegion for error announcements',
      ));
    }

    return issues;
  }

  bool _hasCustomErrorHandling(WidgetInfo widget) {
    final code = widget.sourceCode;
    return code.contains('error') &&
        (code.contains('setState') ||
            code.contains('showDialog') ||
            code.contains('SnackBar'));
  }

  bool _announcesErrors(WidgetInfo widget) {
    final code = widget.sourceCode;
    return code.contains('SemanticsService.announce') ||
        code.contains('liveRegion:') ||
        code.contains('errorText:');
  }
}

class HeadingStructureRule extends AccessibilityRule {
  @override
  String get ruleId => 'WCAG-1.3.1-Heading';

  @override
  String get description => 'Semantic headings should have proper hierarchy';

  @override
  List<String> get targetWidgets => ['Semantics'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Semantics' && _isHeader(widget)) {
      if (!_hasSortKey(widget)) {
        issues.add(AccessibilityIssue(
          id: 'heading-structure-${widget.line}',
          severity: 'medium',
          type: 'Heading Structure',
          message: 'Semantic heading without proper hierarchy level',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Add sortKey property to define heading hierarchy (e.g., sortKey: OrdinalSortKey(1.0))',
        ));
      }
    }

    return issues;
  }

  bool _isHeader(WidgetInfo widget) {
    return widget.properties.containsKey('header') ||
        widget.sourceCode.contains('header: true');
  }

  bool _hasSortKey(WidgetInfo widget) {
    return widget.properties.containsKey('sortKey') ||
        widget.sourceCode.contains('sortKey:');
  }
}

class TableHeadersRule extends AccessibilityRule {
  @override
  String get ruleId => 'WCAG-1.3.1-Table';

  @override
  String get description => 'Tables should have proper row and cell structure';

  @override
  List<String> get targetWidgets => ['Table'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Table') {
      if (!_hasProperTableStructure(widget)) {
        issues.add(AccessibilityIssue(
          id: 'table-structure-${widget.line}',
          severity: 'high',
          type: 'Table Structure',
          message: 'Table without proper row and cell structure',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Use TableRow and TableCell widgets to structure table content properly',
        ));
      }
    }

    return issues;
  }

  bool _hasProperTableStructure(WidgetInfo widget) {
    final code = widget.sourceCode;
    // Check if table has proper structure with actual TableRow and TableCell widgets
    // Look for widget instantiation patterns, not just the strings in comments
    return code.contains('TableRow(') && code.contains('TableCell(');
  }
}

class TabOrderRule extends AccessibilityRule {
  @override
  String get ruleId => 'WCAG-2.4.3';

  @override
  String get description => 'Focus traversal order should be explicit';

  @override
  List<String> get targetWidgets => ['FocusTraversalOrder'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'FocusTraversalOrder') {
      if (!_hasExplicitOrder(widget)) {
        issues.add(AccessibilityIssue(
          id: 'tab-order-${widget.line}',
          severity: 'medium',
          type: 'Tab Order',
          message: 'FocusTraversalOrder without explicit order',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Add order property to define explicit focus traversal order (e.g., order: NumericFocusOrder(1.0))',
        ));
      }
    }

    return issues;
  }

  bool _hasExplicitOrder(WidgetInfo widget) {
    return widget.properties.containsKey('order') ||
        widget.sourceCode.contains('order:');
  }
}

class LiveRegionRule extends AccessibilityRule {
  @override
  String get ruleId => 'WCAG-4.1.3-Mobile';

  @override
  String get description =>
      'Dynamic content should be announced to assistive technology';

  @override
  List<String> get targetWidgets => ['Column', 'Row'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    // Only check widgets that have dynamic content
    if (_hasDynamicContent(widget)) {
      // Check if the entire source code has live region support
      if (!_hasLiveRegion(widget)) {
        issues.add(AccessibilityIssue(
          id: 'live-region-${widget.line}',
          severity: 'high',
          type: 'Live Region',
          message: 'Dynamic content without live region announcement',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Wrap dynamic content with Semantics(liveRegion: true) or use SemanticsService.announce()',
        ));
      }
    }

    return issues;
  }

  bool _hasDynamicContent(WidgetInfo widget) {
    final code = widget.sourceCode;
    // Only check Column/Row widgets that contain both setState and buttons
    // This indicates they manage dynamic content
    return widget.type == 'Column' &&
        code.contains('setState') &&
        code.contains('ElevatedButton');
  }

  bool _hasLiveRegion(WidgetInfo widget) {
    // Check if the entire compilation unit contains live region
    final fullSourceCode = widget.compilationUnit.toSource();
    return fullSourceCode.contains('liveRegion: true') ||
        fullSourceCode.contains('SemanticsService.announce');
  }
}

class SemanticTraversalOrderRule extends AccessibilityRule {
  @override
  String get ruleId => 'WCAG-2.4.3-Mobile';

  @override
  String get description =>
      'Semantic traversal order should use OrdinalSortKey';

  @override
  List<String> get targetWidgets => ['Semantics'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Semantics' &&
        _hasSortKey(widget) &&
        !_hasOrdinalSortKey(widget)) {
      issues.add(AccessibilityIssue(
        id: 'semantic-traversal-${widget.line}',
        severity: 'medium',
        type: 'Semantic Traversal',
        message: 'Consider using OrdinalSortKey for explicit traversal order',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Use OrdinalSortKey instead of custom sort keys for better accessibility support',
      ));
    }

    return issues;
  }

  bool _hasSortKey(WidgetInfo widget) {
    return widget.properties.containsKey('sortKey') ||
        widget.sourceCode.contains('sortKey:');
  }

  bool _hasOrdinalSortKey(WidgetInfo widget) {
    return widget.sourceCode.contains('OrdinalSortKey');
  }
}

class ScaffoldNavigationRule extends AccessibilityRule {
  @override
  String get ruleId => 'WCAG-2.4.1';

  @override
  String get description => 'Scaffolds should have clear navigation elements';

  @override
  List<String> get targetWidgets => ['Scaffold'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Scaffold') {
      if (!_hasNavigationElements(widget)) {
        issues.add(AccessibilityIssue(
          id: 'scaffold-navigation-${widget.line}',
          severity: 'medium',
          type: 'Scaffold Navigation',
          message: 'Scaffold without clear navigation elements',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Add AppBar, BottomNavigationBar, or Drawer for clear navigation structure',
        ));
      }
    }

    return issues;
  }

  bool _hasNavigationElements(WidgetInfo widget) {
    final code = widget.sourceCode;
    return code.contains('appBar:') ||
        code.contains('bottomNavigationBar:') ||
        code.contains('drawer:') ||
        code.contains('endDrawer:');
  }
}

class TextScalingSupportRule extends AccessibilityRule {
  @override
  String get ruleId => 'text-scaling';

  @override
  String get description =>
      'Text should scale properly with system font size settings';

  @override
  List<String> get targetWidgets => ['Text'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Text') {
      final sourceCode = widget.sourceCode;

      // Check for hardcoded font sizes or styles that may not scale
      final hasHardcodedSize = RegExp(r'fontSize:\s*\d+').hasMatch(sourceCode);
      final hasFixedStyle = sourceCode.contains('textScaleFactor') &&
          sourceCode.contains('textScaleFactor: 1.0');

      // Check if the hardcoded size is being properly scaled
      final isProperlyScaled = sourceCode.contains('textScaleFactor') &&
          !sourceCode.contains('textScaleFactor: 1.0');

      // Check if the widget is wrapped in MediaQuery which provides scaling context
      final isWrappedInMediaQuery = _isWrappedInMediaQuery(widget);

      // Check for text scaling issues
      if ((hasHardcodedSize && !isProperlyScaled && !isWrappedInMediaQuery) ||
          hasFixedStyle) {
        final isMobile = platform == PlatformType.mobile;
        final issueId = isMobile ? 'mobile-text-scaling' : 'text-scaling';

        issues.add(AccessibilityIssue(
          id: '$issueId-${widget.line}',
          severity: isMobile ? 'medium' : 'low',
          type: isMobile ? 'Text Scaling Issue' : 'Text Scaling',
          message: 'Text may not scale properly with system font size settings',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion: isMobile
              ? 'Use theme-based text styles, wrap with MediaQuery, or ensure textScaleFactor is not fixed to support dynamic text scaling'
              : 'Use MediaQuery.textScaleFactorOf(context) or Theme-based text styles for proper scaling',
        ));
      }

      // Check for potential scaling issues with small text (mobile-specific)
      if (platform == PlatformType.mobile &&
          sourceCode.contains('fontSize') &&
          (sourceCode.contains('fontSize: 8') ||
              sourceCode.contains('fontSize: 9') ||
              sourceCode.contains('fontSize: 10'))) {
        issues.add(AccessibilityIssue(
          id: 'small-text-${widget.line}',
          severity: 'high',
          type: 'Small Text Size',
          message: 'Very small text size may be hard to read on mobile devices',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Use minimum font size of 12sp or theme-based text styles that scale appropriately',
        ));
      }
    }

    return issues;
  }

  bool _isWrappedInMediaQuery(WidgetInfo widget) {
    // Use AST traversal to check if the widget is wrapped in MediaQuery
    return _isNodeWrappedInMediaQuery(widget.node, widget.compilationUnit);
  }

  bool _isNodeWrappedInMediaQuery(AstNode node, CompilationUnit unit) {
    // Traverse up the AST to find if this node is inside a MediaQuery
    AstNode? current = node.parent;

    while (current != null) {
      if (current is InstanceCreationExpression) {
        final namedType = current.constructorName.type;
        final name = namedType.name.lexeme;
        if (name == 'MediaQuery') {
          return true;
        }
      } else if (current is MethodInvocation) {
        if (current.methodName.name == 'MediaQuery') {
          return true;
        }
      }
      current = current.parent;
    }

    return false;
  }
}
