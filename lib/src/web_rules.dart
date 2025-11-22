// Web-specific accessibility rules for Flutter

import 'optimized_ast_analyzer.dart';
import 'platform_type.dart';

class WebSemanticHtmlRule extends AccessibilityRule {
  @override
  String get ruleId => 'Web-Semantics';

  @override
  String get description => 'Semantics widgets should have proper HTML tag mapping for web';

  @override
  List<String> get targetWidgets => ['Semantics'];

  @override
  List<AccessibilityIssue> check(WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];
    
    // Only apply to web platform
    if (platform != PlatformType.web) {
      return issues;
    }
    
    if (widget.type == 'Semantics') {
      if (!_hasTagName(widget)) {
        issues.add(AccessibilityIssue(
          id: 'web-semantics-${widget.line}',
          severity: 'medium',
          type: 'Web Semantics',
          message: 'Semantics without proper HTML tag mapping for web',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion: 'Add tagName property to Semantics widget for proper HTML mapping (e.g., tagName: "main", "section", "article")',
        ));
      }
    }
    
    return issues;
  }
  
  bool _hasTagName(WidgetInfo widget) {
    return widget.properties.containsKey('tagName') ||
           widget.sourceCode.contains('tagName:');
  }
}

class WebAriaLabelsRule extends AccessibilityRule {
  @override
  String get ruleId => 'Web-ARIA';

  @override
  String get description => 'Interactive elements should have proper ARIA labels for web';

  @override
  List<String> get targetWidgets => ['Semantics'];

  @override
  List<AccessibilityIssue> check(WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];
    
    // Only apply to web platform
    if (platform != PlatformType.web) {
      return issues;
    }
    
    if (widget.type == 'Semantics' && _isInteractiveElement(widget)) {
      if (!_hasAriaLabels(widget)) {
        issues.add(AccessibilityIssue(
          id: 'web-aria-${widget.line}',
          severity: 'high',
          type: 'Web ARIA',
          message: 'Interactive element without ARIA labels for web',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion: 'Add label and hint properties to Semantics for proper ARIA labeling',
        ));
      }
    }
    
    return issues;
  }
  
  bool _isInteractiveElement(WidgetInfo widget) {
    final code = widget.sourceCode;
    return code.contains('button: true') ||
           code.contains('onTap:') ||
           code.contains('link: true') ||
           widget.properties.containsKey('button') ||
           widget.properties.containsKey('onTap');
  }
  
  bool _hasAriaLabels(WidgetInfo widget) {
    return widget.properties.containsKey('label') ||
           widget.properties.containsKey('hint') ||
           (widget.sourceCode.contains('label:') && widget.sourceCode.contains('hint:'));
  }
}

class WebPageTitlesRule extends AccessibilityRule {
  @override
  String get ruleId => 'Web-Titles';

  @override
  String get description => 'Apps should have proper titles for web accessibility';

  @override
  List<String> get targetWidgets => ['MaterialApp', 'CupertinoApp'];

  @override
  List<AccessibilityIssue> check(WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];
    
    // Only apply to web platform
    if (platform != PlatformType.web) {
      return issues;
    }
    
    if (['MaterialApp', 'CupertinoApp'].contains(widget.type)) {
      if (!_hasTitle(widget)) {
        issues.add(AccessibilityIssue(
          id: 'web-title-${widget.line}',
          severity: 'high',
          type: 'Web Title',
          message: 'App without title for web accessibility',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion: 'Add title property to MaterialApp/CupertinoApp for proper page title',
        ));
      }
    }
    
    return issues;
  }
  
  bool _hasTitle(WidgetInfo widget) {
    return widget.properties.containsKey('title') ||
           widget.sourceCode.contains('title:');
  }
}

class WebFocusNavigationRule extends AccessibilityRule {
  @override
  String get ruleId => 'Web-Focus';

  @override
  String get description => 'Focus elements should have proper management for web';

  @override
  List<String> get targetWidgets => ['Focus', 'FocusScope'];

  @override
  List<AccessibilityIssue> check(WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];
    
    // Only apply to web platform
    if (platform != PlatformType.web) {
      return issues;
    }
    
    if (['Focus', 'FocusScope'].contains(widget.type)) {
      if (!_hasProperFocusManagement(widget)) {
        issues.add(AccessibilityIssue(
          id: 'web-focus-${widget.line}',
          severity: 'medium',
          type: 'Web Focus',
          message: 'Focus element without proper focus management for web',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion: 'Add focusNode or autofocus property for proper focus management',
        ));
      }
    }
    
    return issues;
  }
  
  bool _hasProperFocusManagement(WidgetInfo widget) {
    return widget.properties.containsKey('focusNode') ||
           widget.properties.containsKey('autofocus') ||
           widget.sourceCode.contains('focusNode:') ||
           widget.sourceCode.contains('autofocus:');
  }
}