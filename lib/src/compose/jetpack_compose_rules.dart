// lib/src/compose/jetpack_compose_rules.dart
import 'compose_oregex_analyzer.dart'; // your new analyzer (see below)
import '../optimized_ast_analyzer.dart';

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
    final match = RegExp(
      r'contentDescription\s*=\s*([^,\n\)]+|"[^"]*"|' "'" r"[^']*'" r')',
    ).firstMatch(code);
    if (match == null) return false;
    final value = match.group(1)?.trim();
    return value != null &&
        value != 'null' &&
        value != '""' &&
        value != "''";
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
    // Check for sizing that guarantees at least a 48x48dp interactive area.
    // Accept:
    // - minimumInteractiveComponentSize()
    // - fillMaxSize()
    // - explicit size(...) >= 48.dp
    // - sizeIn/defaultMinSize with both minWidth and minHeight >= 48.dp
    // - fillMaxWidth() only when paired with height/requiredHeight >= 48.dp
    final hasExplicitSize =
        code.contains(RegExp(r'size\(\s*(?:4[89]|5\d|[6-9]\d)\.dp'));
    final hasMinSizeConstraints = code.contains(RegExp(
        r'(?:sizeIn|defaultMinSize)\((?=[^)]*minWidth\s*=\s*(?:4[89]|5\d|[6-9]\d)\.dp)(?=[^)]*minHeight\s*=\s*(?:4[89]|5\d|[6-9]\d)\.dp)[^)]*\)'));
    final hasFillMaxWidthWithAdequateHeight = code.contains('fillMaxWidth') &&
        code.contains(RegExp(
            r'(?:height|requiredHeight)\(\s*(?:4[89]|5\d|[6-9]\d)\.dp'));
    return code.contains('minimumInteractiveComponentSize') ||
        code.contains('fillMaxSize') ||
        hasExplicitSize ||
        hasMinSizeConstraints ||
        hasFillMaxWidthWithAdequateHeight;
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
    // Match either:
    // - Text("some literal")
    // - Text(text = "some literal")
    // but not Text(stringResource(...)) or Text(text = stringResource(...)).
    // The {2,} quantifier ensures we only flag strings with at least 2 characters.
    // This reduces noise by ignoring single-character decorative strings like "." or "-"
    // which might be used as spacers or delimiters and are less critical for i18n.
    final hasPositionalHardcodedText =
        RegExp(r'Text\s*\(\s*"[^"]{2,}"').hasMatch(code);
    final hasNamedHardcodedText =
        RegExp(r'Text\s*\([\s\S]*?\btext\s*=\s*"[^"]{2,}"', dotAll: true)
            .hasMatch(code);

    return (hasPositionalHardcodedText || hasNamedHardcodedText) &&
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
    return widget.sourceCode.contains(
      RegExp(r'items\s*\(.*key\s*=', dotAll: true),
    );
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

/// Rule: Custom clickables (Rows, Boxes, etc.) should define a Semantic Role
class ComposeClickableRoleRule extends ComposeAccessibilityRule {
  @override
  String get ruleId => 'compose-clickable-role';

  @override
  String get description =>
      'Custom clickable containers should define a semantic role (e.g., Role.Button)';

  @override
  List<String> get targetComposables => ['Modifier.clickable', 'clickable'];

  @override
  List<AccessibilityIssue> check(
      ComposeWidgetInfo widget, String filePath) {
    final issues = <AccessibilityIssue>[];

    // Note: widget.type will match 'clickable' modifier
    if (['Modifier.clickable', 'clickable'].contains(widget.type)) {
      if (!_hasRole(widget)) {
        issues.add(AccessibilityIssue(
          id: 'compose-clickable-role-${widget.line}',
          severity: 'medium',
          type: 'Missing Semantic Role on Clickable',
          message:
              'Clickable modifier does not specify a semantic Role, which limits screen reader context.',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Provide a role: Modifier.clickable(role = Role.Button) { ... } or Role.Checkbox, etc.',
        ));
      }
    }

    return issues;
  }

  bool _hasRole(ComposeWidgetInfo widget) {
    return widget.sourceCode.contains('role =');
  }
}

/// Rule: Toggleables like Checkbox/Switch should have semantic context
class ComposeToggleableSemanticsRule extends ComposeAccessibilityRule {
  @override
  String get ruleId => 'compose-toggleable-semantics';

  @override
  String get description =>
      'Raw toggleables should be wrapped in semantic toggleable/selectable rows for larger touch targets and context.';

  @override
  List<String> get targetComposables => ['Checkbox', 'Switch', 'RadioButton'];

  @override
  List<AccessibilityIssue> check(
      ComposeWidgetInfo widget, String filePath) {
    final issues = <AccessibilityIssue>[];

    if (targetComposables.contains(widget.type)) {
      // Very basic check: are they standalone without interactive modifiers giving them text context?
      if (!_hasProperContext(widget)) {
        issues.add(AccessibilityIssue(
          id: 'compose-toggleable-semantics-${widget.line}',
          severity: 'high',
          type: 'Standalone Toggleable',
          message:
              'Standalone ${widget.type} lacks descriptive text context/large touch target for screen readers.',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Wrap the ${widget.type} and Text in a Row with Modifier.toggleable(...) or Modifier.selectable(...) for unified accessibility.',
        ));
      }
    }

    return issues;
  }

  bool _hasProperContext(ComposeWidgetInfo widget) {
    // This is a simplistic heuristic for identifying if a standalone toggleable
    // is wrapped in a semantics block or has an explicit contentDescription.
    // FIXME: This could be improved by using a more robust Oregex property parser.
    final code = widget.sourceCode;
    return code.contains('Modifier.semantics') ||
        code.contains('contentDescription'); // A simplistic heuristic
  }
}