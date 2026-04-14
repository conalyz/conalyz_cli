import 'compose_oregex_analyzer.dart';
import 'optimized_ast_analyzer.dart';

/// Abstract base class inspired by PR-1 comment to abstract common logic
/// for checking redundant semantics configuration in Jetpack Compose.
abstract class ComposeRedundantSemanticsBaseRule extends ComposeAccessibilityRule {
  String get redundantPattern;
  String get propertyName;

  @override
  List<AccessibilityIssue> check(ComposeWidgetInfo widget, String filePath) {
    final issues = <AccessibilityIssue>[];

    if (targetComposables.contains(widget.type)) {
      if (_isRedundant(widget)) {
        issues.add(AccessibilityIssue(
          id: '$ruleId-redundant-${widget.line}',
          severity: 'low',
          type: 'Redundant Semantics ($propertyName)',
          message: 'The $propertyName configuration in ${widget.type} is redundant as it matches the default behavior.',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion: 'Remove the redundant $propertyName configuration to clean up the code.',
        ));
      }
    }

    return issues;
  }

  bool _isRedundant(ComposeWidgetInfo widget) {
    return RegExp(redundantPattern).hasMatch(widget.sourceCode);
  }
}

/// Rule to check for redundant mergeDescendants = false
class ComposeRedundantMergeDescendantsRule extends ComposeRedundantSemanticsBaseRule {
  @override
  String get ruleId => 'compose-redundant-merge-descendants';

  @override
  String get description => 'mergeDescendants = false is redundant since it is the default behavior.';

  @override
  List<String> get targetComposables => ['Modifier.semantics', 'semantics'];

  @override
  String get propertyName => 'mergeDescendants';

  @override
  String get redundantPattern => r'mergeDescendants\s*=\s*false';
}

/// Rule to check for redundant isTraversalGroup = false
class ComposeRedundantIsTraversalGroupRule extends ComposeRedundantSemanticsBaseRule {
  @override
  String get ruleId => 'compose-redundant-traversal-group';

  @override
  String get description => 'isTraversalGroup = false is redundant since it is the default behavior.';

  @override
  List<String> get targetComposables => ['Modifier.semantics', 'semantics'];

  @override
  String get propertyName => 'isTraversalGroup';

  @override
  String get redundantPattern => r'isTraversalGroup\s*=\s*false';
}
