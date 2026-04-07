// Jetpack Compose specific rules

import 'compose_ast_analyzer.dart'; // your new analyzer (see below)
import 'optimized_ast_analyzer.dart';

/// Rule: All clickable composables must have contentDescription
class ComposeContentDescriptionRule extends ComposeAccessibilityRule {
  @override
  String get ruleId => 'compose-content-description';

  @override
  String get description =>
      'Clickable composables must have a contentDescription for screen readers';

  @override
  List<String> get targetComposables => [
        'Image',
        'Icon',
        'IconButton',
        'FloatingActionButton',
        'Button',
      ];

  @override
  List<AccessibilityIssue> check(
      ComposeWidgetInfo widget, String filePath) {
    final issues = <AccessibilityIssue>[];

    if (targetComposables.contains(widget.type)) {
      if (!_hasContentDescription(widget)) {
        issues.add(AccessibilityIssue(
          id: 'compose-content-desc-${widget.line}',
          severity: 'high',
          type: 'Missing Content Description',
          message:
              '${widget.type} is missing contentDescription for screen readers (TalkBack)',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Add contentDescription = "..." to the Modifier or directly to the composable. '
              'Example: Image(..., contentDescription = "User avatar")',
        ));
      }
    }

    return issues;
  }

  bool _hasContentDescription(ComposeWidgetInfo widget) {
    final code = widget.sourceCode;
    return code.contains('contentDescription') &&
        !code.contains('contentDescription = null') &&
        !code.contains('contentDescription = ""');
  }
}

/// Rule: Touch targets must be at least 48dp (Material Design + WCAG)
class ComposeTouchTargetRule extends ComposeAccessibilityRule {
  @override
  String get ruleId => 'compose-touch-target';

  @override
  String get description =>
      'Touch targets must be at least 48dp (Material Design + WCAG 2.5.5)';

  @override
  List<String> get targetComposables => [
        'Box',
        'IconButton',
        'TextButton',
        'OutlinedButton',
        'ElevatedButton',
        'FilledButton',
        'Surface',
      ];

  @override
  List<AccessibilityIssue> check(
      ComposeWidgetInfo widget, String filePath) {
    final issues = <AccessibilityIssue>[];

    if (targetComposables.contains(widget.type)) {
      if (!_hasAdequateTouchTarget(widget)) {
        issues.add(AccessibilityIssue(
          id: 'compose-touch-target-${widget.line}',
          severity: 'high',
          type: 'Small Touch Target',
          message:
              '${widget.type} may be smaller than the 48dp minimum touch target',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Use Modifier.minimumInteractiveComponentSize() (Material3) or '
              'Modifier.size(48.dp) / Modifier.padding to ensure at least 48x48dp',
        ));
      }
    }

    return issues;
  }

  bool _hasAdequateTouchTarget(ComposeWidgetInfo widget) {
    final code = widget.sourceCode;
    // Material3 IconButton has 48dp by default
    if (widget.type == 'IconButton') return true;
    // Check for explicit sizing
    return code.contains('minimumInteractiveComponentSize') ||
        code.contains(RegExp(r'size\(4[89]\.dp|5\d\.dp|[6-9]\d\.dp')) ||
        code.contains(RegExp(r'fillMaxWidth|fillMaxSize'));
  }
}

/// Rule: Detect hardcoded text (should use string resources for i18n + a11y)
class ComposeHardcodedTextRule extends ComposeAccessibilityRule {
  @override
  String get ruleId => 'compose-hardcoded-text';

  @override
  String get description =>
      'Text content should use string resources, not hardcoded strings';

  @override
  List<String> get targetComposables => ['Text'];

  @override
  List<AccessibilityIssue> check(
      ComposeWidgetInfo widget, String filePath) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Text' && _hasHardcodedText(widget)) {
      issues.add(AccessibilityIssue(
        id: 'compose-hardcoded-text-${widget.line}',
        severity: 'low',
        type: 'Hardcoded Text',
        message: 'Text composable uses a hardcoded string instead of a string resource',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Use stringResource(R.string.your_key) for better i18n/a11y support',
      ));
    }

    return issues;
  }

  bool _hasHardcodedText(ComposeWidgetInfo widget) {
    final code = widget.sourceCode;
    // Match Text("some literal") but not Text(stringResource(...))
    return RegExp(r'Text\s*\(\s*"[^"]{2,}"').hasMatch(code) &&
        !code.contains('stringResource');
  }
}

/// Rule: LazyColumn/LazyRow items need semantic keys for TalkBack
class ComposeLazyListSemanticKeyRule extends ComposeAccessibilityRule {
  @override
  String get ruleId => 'compose-lazy-semantic-key';

  @override
  String get description =>
      'LazyColumn/LazyRow items should have semantic keys for correct TalkBack traversal';

  @override
  List<String> get targetComposables => ['LazyColumn', 'LazyRow'];

  @override
  List<AccessibilityIssue> check(
      ComposeWidgetInfo widget, String filePath) {
    final issues = <AccessibilityIssue>[];

    if (['LazyColumn', 'LazyRow'].contains(widget.type)) {
      if (!_hasItemKeys(widget)) {
        issues.add(AccessibilityIssue(
          id: 'compose-lazy-key-${widget.line}',
          severity: 'medium',
          type: 'Missing Semantic Keys in Lazy List',
          message:
              '${widget.type} items may not have stable keys, causing TalkBack reordering issues',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Add key = { item.id } inside items { } block for stable recomposition and correct accessibility traversal',
        ));
      }
    }

    return issues;
  }

  bool _hasItemKeys(ComposeWidgetInfo widget) {
    return widget.sourceCode.contains(RegExp(r'items\s*\(.*key\s*='));
  }
}

/// Rule: ReducedMotion — animations must check LocalReduceMotion
class ComposeReducedMotionRule extends ComposeAccessibilityRule {
  @override
  String get ruleId => 'compose-reduced-motion';

  @override
  String get description =>
      'Animations should respect the system reduced-motion setting';

  @override
  List<String> get targetComposables => [
        'AnimatedVisibility',
        'animateFloatAsState',
        'animateDpAsState',
        'AnimatedContent',
        'rememberInfiniteTransition',
      ];

  @override
  List<AccessibilityIssue> check(
      ComposeWidgetInfo widget, String filePath) {
    final issues = <AccessibilityIssue>[];

    if (targetComposables.contains(widget.type)) {
      if (!_respectsReducedMotion(widget)) {
        issues.add(AccessibilityIssue(
          id: 'compose-reduced-motion-${widget.line}',
          severity: 'medium',
          type: 'Animation Without Motion Control',
          message:
              '${widget.type} does not check for reduced motion preferences',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Check LocalReduceMotion.current or use '
              'val transition = updateTransition(...) with '
              'if (LocalReduceMotion.current.enabled) { ... }',
        ));
      }
    }

    return issues;
  }

  bool _respectsReducedMotion(ComposeWidgetInfo widget) {
    final code = widget.sourceCode;
    return code.contains('LocalReduceMotion') ||
        code.contains('getAccessibilityManager') ||
        code.contains('isAnimationEnabled');
  }
}

/// Rule: TextField must have a label for screen reader context
class ComposeTextFieldLabelRule extends ComposeAccessibilityRule {
  @override
  String get ruleId => 'compose-textfield-label';

  @override
  String get description =>
      'TextField/OutlinedTextField must have a visible label or placeholder';

  @override
  List<String> get targetComposables => ['TextField', 'OutlinedTextField', 'BasicTextField'];

  @override
  List<AccessibilityIssue> check(
      ComposeWidgetInfo widget, String filePath) {
    final issues = <AccessibilityIssue>[];

    if (targetComposables.contains(widget.type)) {
      if (!_hasLabel(widget)) {
        issues.add(AccessibilityIssue(
          id: 'compose-textfield-label-${widget.line}',
          severity: 'high',
          type: 'TextField Missing Label',
          message:
              '${widget.type} is missing a label, making it inaccessible to TalkBack',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Add label = { Text("Your label") } or placeholder = { Text("...") } '
              'to the TextField. For BasicTextField, use semantics { contentDescription = "..." }.',
        ));
      }
    }

    return issues;
  }

  bool _hasLabel(ComposeWidgetInfo widget) {
    final code = widget.sourceCode;
    return code.contains('label =') ||
        code.contains('placeholder =') ||
        code.contains('contentDescription');
  }
}