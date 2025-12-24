import 'dart:io';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'flutter_specific_rules.dart';
import 'platform_type.dart';

class AccessibilityIssue {
  final String id;
  final String severity;
  final String type;
  final String message;
  final String file;
  final int line;
  final int column;
  final String rule;
  final String suggestion;

  AccessibilityIssue({
    required this.id,
    required this.severity,
    required this.type,
    required this.message,
    required this.file,
    required this.line,
    required this.column,
    required this.rule,
    required this.suggestion,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'severity': severity,
        'type': type,
        'message': message,
        'file': file,
        'line': line,
        'column': column,
        'rule': rule,
        'suggestion': suggestion,
      };
}

class AnalysisResult {
  final int totalIssues;
  final Map<String, int> issuesBySeverity;
  final List<AccessibilityIssue> issues;
  final List<String> analyzedFiles;
  final String timestamp;
  final PlatformType platform;
  final int linesScanned;

  AnalysisResult({
    required this.totalIssues,
    required this.issuesBySeverity,
    required this.issues,
    required this.analyzedFiles,
    required this.timestamp,
    required this.platform,
    required this.linesScanned,
  });

  Map<String, dynamic> toJson() => {
        'totalIssues': totalIssues,
        'issuesBySeverity': issuesBySeverity,
        'issues': issues.map((issue) => issue.toJson()).toList(),
        'analyzedFiles': analyzedFiles,
        'timestamp': timestamp,
        'platform': platform.toString().split('.').last,
        'linesScanned': linesScanned,
      };
}

/// Widget information extracted from AST
class WidgetInfo {
  final String type;
  final int line;
  final int column;
  final Map<String, dynamic> properties;
  final String sourceCode;
  final CompilationUnit compilationUnit;
  final AstNode node;
  final OptimizedWidgetExtractionVisitor visitor;

  WidgetInfo({
    required this.type,
    required this.line,
    required this.column,
    required this.properties,
    required this.sourceCode,
    required this.compilationUnit,
    required this.node,
    required this.visitor,
  });
}

/// Base class for accessibility rules
abstract class AccessibilityRule {
  String get ruleId;
  String get description;
  List<String> get targetWidgets;

  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform);

  /// Optimized method to check if a widget is wrapped with Semantics
  bool isWrappedWithSemantics(WidgetInfo widget) {
    return widget.visitor.isWrappedWithSemantics(widget.node);
  }
}

/// Optimized AST-based Flutter accessibility analyzer with performance improvements
class OptimizedAstFlutterAccessibilityAnalyzer {
  final List<AccessibilityRule> _rules = [];
  int _issueIdCounter = 1;
  final bool _enableDebugOutput;

  OptimizedAstFlutterAccessibilityAnalyzer({bool enableDebugOutput = false})
      : _enableDebugOutput = enableDebugOutput {
    _initializeRules();
  }

  // Allow external access to rules for customization
  List<AccessibilityRule> get rules => _rules;

  void _initializeRules() {
    // Core Flutter accessibility rules (keep and enhance)
    _rules.addAll([
      ImageAccessibilityRule(),
      FormLabelRule(),
      ButtonLabelRule(),
      GestureDetectorAccessibilityRule(),
      IconButtonAccessibilityRule(),
      EmptyTextWidgetsRule(),
      DisabledElementsRule(),
      CheckboxAccessibilityRule(),
      SwitchAccessibilityRule(),
      SliderAccessibilityRule(),
      ProgressIndicatorAccessibilityRule(),
      IconAccessibilityRule(),

      MobileFocusManagementRule(),
      MobileTabAccessibilityRule(),
      MobileDismissibleRule(),
      MobileRefreshIndicatorRule(),
      MobileFormFieldGroupingRule(),
      MobileTimeoutRule(),
      ReducedMotionSupportRule(),
      ExcludeSemanticsRule(),
      BlockSemanticsRule(),
      MergeSemanticsRule(),
      TapTargetSizeRule(),
      CustomErrorAnnouncementRule(),
      HeadingStructureRule(),
      TableHeadersRule(),
      LiveRegionRule(),

      // Rules to be revised for better Flutter fit
      ColorContrastRule(),
      VagueTextContentRule(),
      SemanticRoleCompletenessRule(),

      // Additional Flutter-specific rules for tests
      TabOrderRule(),
      SemanticTraversalOrderRule(),
      ScaffoldNavigationRule(),
      TextScalingSupportRule(),
    ]);

    // Add web-specific rules
    if (_shouldIncludeWebRules()) {
      _rules.addAll([
        WebSemanticHtmlRule(),
        WebAriaLabelsRule(),
        WebPageTitlesRule(),
        WebFocusNavigationRule(),
      ]);
    }

    if (_enableDebugOutput) {
      print('Initialized ${_rules.length} Flutter accessibility rules');
    }
  }

  bool _shouldIncludeWebRules() {
    return true;
  }

  /// Analyze a single Dart file for accessibility issues
  Future<AnalysisResult> analyzeFile(
    String filePath, {
    required PlatformType platform,
  }) async {
    final issues = <AccessibilityIssue>[];
    final analyzedFiles = <String>[];
    _issueIdCounter = 1;

    if (_enableDebugOutput) {
      print('Analyzing single file: $filePath');
    }

    // Process the single file
    final fileResult = await _processFile(filePath, platform);

    if (fileResult != null) {
      issues.addAll(fileResult.issues);
      analyzedFiles.addAll(fileResult.analyzedFiles);
    }

    // Calculate issues by severity
    final issuesBySeverity = {
      'critical': issues.where((i) => i.severity == 'critical').length,
      'high': issues.where((i) => i.severity == 'high').length,
      'medium': issues.where((i) => i.severity == 'medium').length,
      'low': issues.where((i) => i.severity == 'low').length,
    };

    return AnalysisResult(
      totalIssues: issues.length,
      issuesBySeverity: issuesBySeverity,
      issues: issues,
      analyzedFiles: analyzedFiles,
      timestamp: DateTime.now().toIso8601String(),
      platform: platform,
      linesScanned: fileResult?.linesScanned ?? 0,
    );
  }

  Future<AnalysisResult> analyzeProject(
    String projectPath, {
    required PlatformType platform,
  }) async {
    final issues = <AccessibilityIssue>[];
    final analyzedFiles = <String>[];
    _issueIdCounter = 1;

    // Get all Dart files in the project
    final dartFiles = await _findDartFiles(projectPath);

    if (_enableDebugOutput) {
      print('Found ${dartFiles.length} Dart files to analyze');
    }

    // Process files in parallel for better performance
    final fileResults = await _processFilesInParallel(dartFiles, platform);

    // Combine results and count lines during processing
    int totalLinesScanned = 0;
    for (final result in fileResults) {
      if (result != null) {
        issues.addAll(result.issues);
        analyzedFiles.addAll(result.analyzedFiles);
        totalLinesScanned += result.linesScanned;
      }
    }

    // Calculate issues by severity
    final issuesBySeverity = {
      'critical': issues.where((i) => i.severity == 'critical').length,
      'high': issues.where((i) => i.severity == 'high').length,
      'medium': issues.where((i) => i.severity == 'medium').length,
      'low': issues.where((i) => i.severity == 'low').length,
    };

    return AnalysisResult(
      totalIssues: issues.length,
      issuesBySeverity: issuesBySeverity,
      issues: issues,
      analyzedFiles: analyzedFiles,
      timestamp: DateTime.now().toIso8601String(),
      platform: platform,
      linesScanned: totalLinesScanned,
    );
  }

  /// Process files in parallel for better performance
  Future<List<FileAnalysisResult?>> _processFilesInParallel(
      List<String> dartFiles, PlatformType platform) async {
    // Process files one by one to avoid getting stuck
    final results = <FileAnalysisResult?>[];

    for (int i = 0; i < dartFiles.length; i++) {
      final filePath = dartFiles[i];

      // Show progress for large projects
      if (dartFiles.length > 20 && (i + 1) % 20 == 0) {
        final progress =
            ((i + 1) / dartFiles.length * 100).clamp(0, 100).toInt();
        print('📊 Processing: ${i + 1}/${dartFiles.length} files ($progress%)');
      }

      // Add timeout to prevent getting stuck on problematic files
      try {
        final result = await _processFileWithTimeout(filePath, platform);
        results.add(result);
      } catch (e) {
        print('⚠️  Error processing file $filePath, skipping');
        results.add(FileAnalysisResult(
          issues: [],
          analyzedFiles: [filePath],
          linesScanned: 0,
        ));
      }
    }

    return results;
  }

  /// Process a single file with optimized performance
  Future<FileAnalysisResult?> _processFile(
      String filePath, PlatformType platform) async {
    try {
      // Skip very large files that might cause issues
      final file = File(filePath);
      final fileSize = await file.length();
      if (fileSize > 100000) {
        // Skip files larger than 100KB
        if (_enableDebugOutput) {
          print(
              '⏭️  Skipping large file: ${filePath.split('/').last} (${(fileSize / 1024).toStringAsFixed(1)}KB)');
        }
        return FileAnalysisResult(
          issues: [],
          analyzedFiles: [filePath],
          linesScanned: 0,
        );
      }

      final content = await file.readAsString();

      // Count lines efficiently during file processing
      final linesScanned = _countLinesInContent(content);

      // Skip files with too many lines that might cause performance issues
      // if (linesScanned > 1500) {
      //   if (_enableDebugOutput) {
      //     print('⏭️  Skipping large file: ${filePath.split('/').last} ($linesScanned lines)');
      //   }
      //   return FileAnalysisResult(
      //     issues: [],
      //     analyzedFiles: [filePath],
      //     linesScanned: linesScanned,
      //   );
      // }

      if (_enableDebugOutput) {
        print(
            '📝 Processing: ${filePath.split('/').last} ($linesScanned lines)');
        print('🔍 Parsing AST...');
      }

      // Parse the file into AST
      final parseResult = parseString(
        content: content,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );

      if (_enableDebugOutput) {
        print('✅ AST parsed successfully');
      }

      if (parseResult.errors.isNotEmpty) {
        if (_enableDebugOutput) {
          print('Warning: Parse errors in $filePath:');
          for (final error in parseResult.errors) {
            print('  ${error.message}');
          }
        }
        return FileAnalysisResult(
          issues: [],
          analyzedFiles: [filePath],
          linesScanned: linesScanned,
        );
      }

      if (_enableDebugOutput) {
        print('Parsed successfully, unit: ${parseResult.unit}');
      }

      // Extract widget information from AST with optimized visitor
      if (_enableDebugOutput) {
        print('🔍 Creating visitor...');
        print('🔍 Building parent map...');
      }
      final visitor = OptimizedWidgetExtractionVisitor(
          content, parseResult.unit, _enableDebugOutput);
      visitor.buildParentMap(parseResult.unit);

      if (_enableDebugOutput) {
        print('✅ Parent map built');
        print('🔍 Visiting AST...');
      }

      parseResult.unit.visitChildren(visitor);

      if (_enableDebugOutput) {
        print('✅ AST visit completed');
        print('📊 Found ${visitor.widgets.length} widgets');
      }

      // Apply accessibility rules to each widget with optimized rule matching
      if (_enableDebugOutput) {
        print('🔍 Applying rules to ${visitor.widgets.length} widgets...');
      }
      final issues = <AccessibilityIssue>[];
      for (int i = 0; i < visitor.widgets.length; i++) {
        final widget = visitor.widgets[i];
        if (_enableDebugOutput && i % 10 == 0) {
          print(
              '  Processing widget ${i + 1}/${visitor.widgets.length}: ${widget.type}');
        }

        final relevantRules = _getRelevantRules(widget.type);

        for (final rule in relevantRules) {
          final ruleIssues = rule.check(widget, filePath, platform);
          for (final issue in ruleIssues) {
            issues.add(AccessibilityIssue(
              id: 'issue-${_issueIdCounter++}',
              severity: issue.severity,
              type: issue.type,
              message: issue.message,
              file: issue.file,
              line: issue.line,
              column: issue.column,
              rule: issue.rule,
              suggestion: issue.suggestion,
            ));
          }
        }
      }
      if (_enableDebugOutput) {
        print('✅ Rules applied, found ${issues.length} issues');
      }

      return FileAnalysisResult(
        issues: issues,
        analyzedFiles: [filePath],
        linesScanned: linesScanned,
      );
    } catch (e) {
      if (_enableDebugOutput) {
        print('Error analyzing file $filePath: $e');
      }
      return FileAnalysisResult(
        issues: [],
        analyzedFiles: [filePath],
        linesScanned: 0,
      );
    }
  }

  /// Process a single file with timeout protection
  Future<FileAnalysisResult?> _processFileWithTimeout(
      String filePath, PlatformType platform) async {
    try {
      return await _processFile(filePath, platform).timeout(
        Duration(seconds: 5), // 5 second timeout per file
        onTimeout: () {
          if (_enableDebugOutput) {
            print('⏰ Timeout processing file: ${filePath.split('/').last}');
          }
          return FileAnalysisResult(
            issues: [],
            analyzedFiles: [filePath],
            linesScanned: 0,
          );
        },
      );
    } catch (e) {
      if (_enableDebugOutput) {
        print('❌ Error processing file ${filePath.split('/').last}: $e');
      }
      return FileAnalysisResult(
        issues: [],
        analyzedFiles: [filePath],
        linesScanned: 0,
      );
    }
  }

  /// Efficiently count lines in content
  int _countLinesInContent(String content) {
    if (content.isEmpty) return 0;
    return content.split('\n').length;
  }

  /// Get only relevant rules for a widget type to improve performance
  List<AccessibilityRule> _getRelevantRules(String widgetType) {
    return _rules
        .where((rule) =>
            rule.targetWidgets.isEmpty ||
            rule.targetWidgets.contains(widgetType))
        .toList();
  }

  Future<List<String>> _findDartFiles(String projectPath) async {
    final dartFiles = <String>[];
    final dir = Directory(projectPath);

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        dartFiles.add(entity.path);
      }
    }

    return dartFiles;
  }
}

/// Result of analyzing a single file
class FileAnalysisResult {
  final List<AccessibilityIssue> issues;
  final List<String> analyzedFiles;
  final int linesScanned;

  FileAnalysisResult({
    required this.issues,
    required this.analyzedFiles,
    required this.linesScanned,
  });
}

/// Optimized AST visitor to extract widget information with better performance
class OptimizedWidgetExtractionVisitor extends RecursiveAstVisitor<void> {
  final String sourceCode;
  final CompilationUnit compilationUnit;
  final List<WidgetInfo> widgets = [];
  final Map<AstNode, AstNode?> _parentMap = {};
  final bool _enableDebugOutput;

  OptimizedWidgetExtractionVisitor(
      this.sourceCode, this.compilationUnit, this._enableDebugOutput);

  /// Build parent map for the entire AST (optimized)
  void buildParentMap(AstNode root) {
    _parentMap.clear();
    _buildParentMapRecursive(root, null, 0);
  }

  void _buildParentMapRecursive(AstNode node, AstNode? parent, int depth) {
    // Limit recursion depth to prevent stack overflow on very large files
    if (depth > 50) {
      return;
    }

    if (parent != null) {
      _parentMap[node] = parent;
    }

    // Only process method invocations for widget relationships
    if (node is MethodInvocation) {
      // Limit the number of arguments processed to prevent performance issues
      final arguments = node.argumentList.arguments;
      final maxArgs = arguments.length > 20 ? 20 : arguments.length;
      for (int i = 0; i < maxArgs; i++) {
        final arg = arguments[i];
        _buildParentMapRecursive(arg, node, depth + 1);
      }
    }

    // Process children more efficiently with depth limit
    final children = node.childEntities.toList();
    final maxChildren = children.length > 100 ? 100 : children.length;
    for (int i = 0; i < maxChildren; i++) {
      final child = children[i];
      if (child is AstNode) {
        _buildParentMapRecursive(child, node, depth + 1);
      }
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _trackParentChild(node);

    // Extract constructor name more efficiently
    final type = node.constructorName.type;
    final constructorName = type.name.lexeme;

    // Handle named constructors
    String fullConstructorName = constructorName;
    if (node.constructorName.name != null) {
      fullConstructorName =
          '$constructorName.${node.constructorName.name!.name}';
    }

    if (_enableDebugOutput) {
      print('Found constructor: $fullConstructorName');
    }

    // Check if this is a Flutter widget with optimized lookup
    if (_isFlutterWidget(constructorName) ||
        _isFlutterWidget(fullConstructorName)) {
      if (_enableDebugOutput) {
        print('  -> Identified as Flutter widget');
      }
      _addWidget(constructorName, node, node.argumentList.arguments);
    } else if (_enableDebugOutput) {
      print('  -> NOT a Flutter widget (filtered out)');
    }

    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _trackParentChild(node);

    final methodName = node.methodName.name;
    if (_enableDebugOutput) {
      print('Found method invocation: $methodName');
    }

    // Handle named constructors like Image.asset(), Image.network()
    String? targetType;
    if (node.target != null) {
      targetType = node.target.toString();
      final fullName = '$targetType.$methodName';

      if (_enableDebugOutput) {
        print('  Full method name: $fullName');
      }

      // Check if this is a Flutter widget constructor
      if (_isFlutterWidget(targetType)) {
        if (_enableDebugOutput) {
          print('  -> Identified as Flutter widget named constructor');
        }
        _addWidget(targetType, node, node.argumentList.arguments);
        super.visitMethodInvocation(node);
        return;
      }
    }

    // Many Flutter widgets appear as method invocations
    if (_isFlutterWidget(methodName)) {
      if (_enableDebugOutput) {
        print('  -> Identified as Flutter widget (method invocation)');
      }
      _addWidget(methodName, node, node.argumentList.arguments);
    } else if (_enableDebugOutput) {
      print('  -> NOT a Flutter widget (filtered out)');
    }

    super.visitMethodInvocation(node);
  }

  void _trackParentChild(AstNode node) {
    // Track parent-child relationships more efficiently
    for (final child in node.childEntities) {
      if (child is AstNode) {
        _parentMap[child] = node;
      }
    }
  }

  void _addWidget(
      String widgetType, AstNode node, NodeList<Expression> arguments) {
    final lineInfo = compilationUnit.lineInfo;
    final location = lineInfo.getLocation(node.offset);

    final properties = <String, dynamic>{};

    // Extract properties from arguments more efficiently
    for (final arg in arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        final value = _extractArgumentValue(arg.expression);
        properties[name] = value;
        if (_enableDebugOutput) {
          print('    Property: $name = $value');
        }
      }
    }

    // Only store source code snippet if needed (optimize memory usage)
    final sourceCodeSnippet = sourceCode.substring(node.offset, node.end);
    widgets.add(WidgetInfo(
      type: widgetType,
      line: location.lineNumber,
      column: location.columnNumber,
      properties: properties,
      sourceCode: sourceCodeSnippet,
      compilationUnit: compilationUnit,
      node: node,
      visitor: this,
    ));

    if (_enableDebugOutput) {
      print('    Added widget: $widgetType at line ${location.lineNumber}');
    }
  }

  /// Optimized method to check if a widget is wrapped by a Semantics widget
  bool isWrappedWithSemantics(AstNode widgetNode) {
    // Get the line info for the widget
    final lineInfo = compilationUnit.lineInfo;
    final widgetLocation = lineInfo.getLocation(widgetNode.offset);
    final widgetLine = widgetLocation.lineNumber;

    // Look for Semantics widgets that appear before this widget in the source
    for (final widget in widgets) {
      if (widget.type == 'Semantics' && widget.line < widgetLine) {
        // Check if this widget appears in the Semantics widget's child property
        final semanticsSourceCode = widget.sourceCode;
        final widgetSourceSnippet =
            sourceCode.substring(widgetNode.offset, widgetNode.end);

        // Simple check: if the widget's source code appears within the Semantics widget's source code
        if (semanticsSourceCode.contains(widgetSourceSnippet)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _isFlutterWidget(String name) {
    // Extract base widget name (before any dots for named constructors)
    final baseName = name.split('.').first;

    // Use a more efficient lookup with a pre-computed set
    return _flutterWidgets.contains(baseName) || _flutterWidgets.contains(name);
  }

  // Pre-computed set of Flutter widgets for O(1) lookup
  static final Set<String> _flutterWidgets = {
    // Core Framework Widgets
    'MaterialApp', 'Scaffold', 'StatefulWidget', 'StatelessWidget',

    // Layout Widgets
    'Align', 'AspectRatio', 'Center', 'Column', 'ConstrainedBox', 'Container',
    'Expanded', 'Flexible', 'FittedBox', 'FractionallySizedBox', 'OverflowBox',
    'Padding', 'Positioned', 'Row', 'SizedBox', 'Stack', 'UnconstrainedBox',
    'Wrap',

    // Scrolling Widgets
    'CustomScrollView', 'GridView', 'ListView', 'PageView',
    'SingleChildScrollView',
    'SliverGrid', 'SliverList',

    // Navigation and App Structure
    'AppBar', 'BackButton', 'BottomAppBar', 'BottomNavigationBar',
    'BottomSheet',
    'Drawer', 'MenuBar', 'Navigator', 'SafeArea', 'TabBar', 'TabBarView',

    // Button Widgets
    'ElevatedButton', 'FloatingActionButton', 'IconButton', 'OutlinedButton',
    'PopupMenuButton', 'RawMaterialButton', 'SegmentedButton', 'TextButton',

    // Input and Form Widgets
    'Autocomplete', 'CalendarDatePicker', 'Checkbox', 'DropdownButton', 'Form',
    'Radio', 'Slider', 'Switch', 'TextField', 'TextFormField',

    // Dialog and Alert Widgets
    'AboutDialog', 'AboutListTile', 'AlertDialog', 'DatePickerDialog',
    'DateRangePickerDialog', 'SimpleDialog', 'TimePickerDialog',

    // Chip Widgets
    'ActionChip', 'Chip', 'ChoiceChip', 'InputChip',

    // List and Panel Widgets
    'ButtonBar', 'CheckboxListTile', 'ExpansionPanel', 'ExpansionPanelList',
    'ExpansionTile', 'ListTile', 'RadioListTile', 'UserAccountsDrawerHeader',

    // Display and Media Widgets
    'Badge', 'Card', 'Divider', 'Icon', 'Image', 'Text', 'Tooltip',
    'VerticalDivider',

    // Progress and Loading Widgets
    'CircularProgressIndicator', 'LinearProgressIndicator', 'ProgressIndicator',
    'RefreshIndicator',

    // Interaction and Gesture Widgets
    'Dismissible', 'GestureDetector', 'InkResponse', 'InkWell',

    // Data Display Widgets
    'DataTable', 'PaginatedDataTable', 'RangeSlider', 'Stepper', 'Table',
    'TableCell', 'TableRow',

    // Accessibility and Semantics Widgets
    'ExcludeSemantics', 'Focus', 'FocusScope', 'FocusTraversalOrder',
    'Semantics',

    // Animation and Visual Effects
    'AnimatedContainer', 'AnimationController', 'ClipRRect', 'Hero', 'Material',
    'Opacity', 'Transform',

    // Utility Widgets
    'AbsorbPointer', 'Banner', 'Spacer',

    // Cupertino (iOS-style) Widgets
    'CupertinoActionSheet', 'CupertinoAlertDialog', 'CupertinoApp',
    'CupertinoPageScaffold',
    'CupertinoButton', 'CupertinoSlider', 'CupertinoSwitch',
    'CupertinoTextField',
    'CupertinoActivityIndicator', 'CupertinoCheckBox', 'CupertinoContextMenu',
    'CupertinoDatePicker', 'CupertinoPicker', 'CupertinoPopupSurface',
    'CupertinoScrollbar',
    'CupertinoSearchTextField', 'CupertinoSegmentedControl',
    'CupertinoSlidingSegmentedControl',
    'CupertinoTimerPicker', 'CupertinoListSection', 'CupertinoListTile',
    'CupertinoNavigationBar', 'CupertinoTabBar', 'CupertinoTabScaffold',
    'CupertinoTabView',
    'CupertinoFormRow', 'CupertinoFormSection',

    // Theme and Styling
    'ColorScheme', 'TabController', 'ThemeData',

    // Legacy/Deprecated
    'DatePicker', 'TimePicker',
  };

  dynamic _extractArgumentValue(Expression expression) {
    if (expression is StringLiteral) {
      return expression.stringValue;
    } else if (expression is BooleanLiteral) {
      return expression.value;
    } else if (expression is IntegerLiteral) {
      return expression.value;
    } else if (expression is DoubleLiteral) {
      return expression.value;
    } else if (expression is PrefixedIdentifier) {
      return expression.toString();
    } else if (expression is SimpleIdentifier) {
      return expression.name;
    } else if (expression is PropertyAccess) {
      return expression.toString();
    }
    return expression.toString();
  }
}

class ImageAccessibilityRule extends AccessibilityRule {
  @override
  String get ruleId => 'WCAG-1.1.1';

  @override
  String get description => 'Images must have alternative text';

  @override
  List<String> get targetWidgets => ['Image'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Image' &&
        !widget.properties.containsKey('semanticLabel') &&
        !_isWrappedWithSemantics(widget)) {
      issues.add(AccessibilityIssue(
        id: '',
        severity: 'critical',
        type: 'Missing Alt Text',
        message: 'Image without alternative text for screen readers',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Add semanticLabel property or wrap with Semantics widget providing meaningful description',
      ));
    }

    return issues;
  }

  bool _isWrappedWithSemantics(WidgetInfo widget) {
    // Use the visitor's proper AST traversal method
    return widget.visitor.isWrappedWithSemantics(widget.node);
  }
}

class FormLabelRule extends AccessibilityRule {
  @override
  String get ruleId => 'WCAG-1.3.1';

  @override
  String get description => 'Form inputs must have accessible labels';

  @override
  List<String> get targetWidgets => ['TextField', 'TextFormField'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if ((widget.type == 'TextField' || widget.type == 'TextFormField')) {
      final hasDecoration = widget.properties.containsKey('decoration');
      final hasLabel = widget.sourceCode.contains('labelText') ||
          widget.sourceCode.contains('hintText');
      final hasSemantics = isWrappedWithSemantics(widget);

      if (!hasDecoration && !hasLabel && !hasSemantics) {
        issues.add(AccessibilityIssue(
          id: '',
          severity: 'critical',
          type: 'TextField Without Label',
          message:
              'TextField without hint, label, or external text for screen readers',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Add decoration with labelText/hintText, external Text label, or wrap with Semantics',
        ));
      }
    }

    return issues;
  }

  // Removed - using centralized method from base class
}

class ColorContrastRule extends AccessibilityRule {
  @override
  String get ruleId => 'WCAG-1.4.3';

  @override
  String get description =>
      'Colors must meet WCAG contrast requirements (4.5:1 for normal text, 3:1 for large text)';

  @override
  List<String> get targetWidgets =>
      ['Text', 'RichText', 'Container', 'Card', 'Material'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    // Check for problematic color combinations that commonly fail contrast requirements
    final problematicCombinations = [
      {
        'bg': 'Colors.yellow',
        'fg': 'Colors.white',
        'ratio': 1.07,
        'severity': 'critical'
      },
      {
        'bg': 'Colors.grey\\[300\\]',
        'fg': 'Colors.white',
        'ratio': 2.31,
        'severity': 'high'
      },
      {
        'bg': 'Colors.lightBlue',
        'fg': 'Colors.white',
        'ratio': 2.37,
        'severity': 'high'
      },
      {
        'bg': 'Colors.orange',
        'fg': 'Colors.white',
        'ratio': 2.85,
        'severity': 'high'
      },
      {
        'bg': 'Colors.grey\\[400\\]',
        'fg': 'Colors.black',
        'ratio': 4.24,
        'severity': 'medium'
      },
    ];

    for (final combo in problematicCombinations) {
      if (_hasColorCombination(
          widget, combo['bg'] as String, combo['fg'] as String)) {
        final ratio = combo['ratio'] as double;
        issues.add(AccessibilityIssue(
          id: 'color-contrast-${widget.line}',
          severity: combo['severity'] as String,
          type: 'Color Contrast Issue',
          message:
              'Color combination fails WCAG contrast requirements (${ratio.toStringAsFixed(2)}:1 ratio)',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Use colors with contrast ratio ≥4.5:1 for normal text, ≥3:1 for large text. Consider using Theme.of(context).colorScheme for accessible colors.',
        ));
      }
    }

    // Check for use of Theme colors which are generally more accessible
    if (_usesCustomColorsWithoutTheme(widget)) {
      issues.add(AccessibilityIssue(
        id: 'theme-colors-${widget.line}',
        severity: 'low',
        type: 'Theme Color Recommendation',
        message:
            'Consider using Theme colors for better accessibility compliance',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Use Theme.of(context).colorScheme.primary, secondary, etc. for automatic contrast compliance',
      ));
    }

    return issues;
  }

  bool _hasColorCombination(WidgetInfo widget, String bgColor, String fgColor) {
    final code = widget.sourceCode;
    return code.contains(RegExp(bgColor)) && code.contains(RegExp(fgColor));
  }

  bool _usesCustomColorsWithoutTheme(WidgetInfo widget) {
    final code = widget.sourceCode;
    final hasCustomColors = code.contains(RegExp(r'Colors\.[a-zA-Z]+')) ||
        code.contains(RegExp(r'Color\(0x[0-9A-Fa-f]+\)'));
    final usesTheme =
        code.contains('Theme.of(context)') || code.contains('colorScheme');
    return hasCustomColors && !usesTheme;
  }
}

class ErrorIdentificationRule extends AccessibilityRule {
  @override
  String get ruleId => 'WCAG-3.3.1';

  @override
  String get description => 'Form errors must be clearly identified';

  @override
  List<String> get targetWidgets => ['TextField', 'TextFormField'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.sourceCode.contains('validator:') &&
        !widget.sourceCode.contains('errorText')) {
      issues.add(AccessibilityIssue(
        id: '',
        severity: 'high',
        type: 'Error Identification',
        message: 'Form validation without accessible error messages',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion: 'Provide clear error messages using errorText property',
      ));
    }

    return issues;
  }
}

class IconAccessibilityRule extends AccessibilityRule {
  @override
  String get ruleId => 'WCAG-1.1.1-Icon';

  @override
  String get description => 'Icons must have semantic information';

  @override
  List<String> get targetWidgets => ['Icon'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Icon' &&
        !widget.properties.containsKey('semanticLabel') &&
        !isWrappedWithSemantics(widget)) {
      issues.add(AccessibilityIssue(
        id: '',
        severity: 'medium',
        type: 'Missing Icon Label',
        message: 'Icon without semantic information',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Add semanticLabel or wrap with Semantics widget. Use ExcludeSemantics for decorative icons',
      ));
    }

    return issues;
  }

  // Removed - using centralized method from base class
}

class ExcludeSemanticsRule extends AccessibilityRule {
  @override
  String get ruleId => 'exclude-semantics';

  @override
  String get description =>
      'Content excluded from semantics - verify if intentional';

  @override
  List<String> get targetWidgets => ['ExcludeSemantics'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'ExcludeSemantics' &&
        !widget.sourceCode.contains('// decorative')) {
      issues.add(AccessibilityIssue(
        id: 'exclude-semantics-${widget.line}',
        severity: 'low',
        type: 'Semantic Exclusion Review',
        message: 'Content excluded from semantics - verify if intentional',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Ensure ExcludeSemantics is only used for purely decorative elements',
      ));
    }

    return issues;
  }
}

class TabOrderRule extends AccessibilityRule {
  @override
  String get ruleId => 'tab-order';

  @override
  String get description => 'FocusTraversalOrder without explicit order';

  @override
  List<String> get targetWidgets => ['FocusTraversalOrder'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'FocusTraversalOrder' &&
        !widget.properties.containsKey('order')) {
      issues.add(AccessibilityIssue(
        id: 'tab-order-${widget.line}',
        severity: 'medium',
        type: 'Missing Focus Order',
        message: 'FocusTraversalOrder without explicit order',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: 'WCAG-2.4.3',
        suggestion: 'Add explicit order parameter for proper focus traversal',
      ));
    }

    return issues;
  }
}

class SemanticRoleCompletenessRule extends AccessibilityRule {
  @override
  String get ruleId => 'semantic-role-completeness';

  @override
  String get description => 'Semantics widget without meaningful properties';

  @override
  List<String> get targetWidgets => ['Semantics'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Semantics' &&
        !_hasMeaningfulSemanticsProperties(widget)) {
      issues.add(AccessibilityIssue(
        id: 'semantic-role-completeness-${widget.line}',
        severity: 'high',
        type: 'Incomplete Semantics',
        message:
            'Semantics widget without meaningful properties for Flutter accessibility',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Add meaningful properties like label, hint, value, or semantic roles (button, header, etc.)',
      ));
    }

    return issues;
  }

  bool _hasMeaningfulSemanticsProperties(WidgetInfo widget) {
    final meaningfulProperties = [
      'label',
      'hint',
      'value',
      'button',
      'link',
      'header',
      'image',
      'onTap',
      'onLongPress',
      'onTapHint',
      'enabled',
      'checked',
      'selected',
      'expanded',
      'hidden',
      'obscured',
      'multiline',
      'readOnly',
      'focused',
      'inMutuallyExclusiveGroup',
      'namesRoute',
      'scopesRoute',
      'explicitChildNodes',
      'excludeSemantics',
      'container',
      'slider',
      'keyboardKey',
      'liveRegion',
      'maxValueLength',
      'currentValueLength',
      'textDirection',
      'sortKey',
    ];

    return meaningfulProperties
        .any((prop) => widget.properties.containsKey(prop));
  }
}

class ButtonLabelRule extends AccessibilityRule {
  @override
  String get ruleId => 'WCAG-2.5.3';
  @override
  String get description => 'Buttons must have labels';
  @override
  List<String> get targetWidgets => [
        'ElevatedButton',
        'TextButton',
        'IconButton',
        'FloatingActionButton',
        'RawMaterialButton',
        'SegmentedButton'
      ];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if ([
      'ElevatedButton',
      'TextButton',
      'IconButton',
      'FloatingActionButton',
      'RawMaterialButton',
      'SegmentedButton'
    ].contains(widget.type)) {
      final hasChild = widget.sourceCode.contains(RegExp(r'child:.*Text\('));
      final hasSemanticLabel = widget.properties.containsKey('semanticLabel');
      final hasTooltip = widget.properties.containsKey('tooltip');
      final hasSemantics = isWrappedWithSemantics(widget);

      if (!hasChild && !hasSemanticLabel && !hasTooltip && !hasSemantics) {
        issues.add(AccessibilityIssue(
          id: '',
          severity: 'high',
          type: 'Button Without Label',
          message: 'Button missing visible label, semanticLabel, or tooltip',
          file: filePath,
          line: widget.line,
          column: widget.column,
          rule: ruleId,
          suggestion:
              'Add a visible Text child, semanticLabel, tooltip, or wrap with Semantics',
        ));
      }
    }

    return issues;
  }

  // Removed - using centralized method from base class
}

class InteractiveElementsRule extends AccessibilityRule {
  @override
  String get ruleId => 'interactive-elements';

  @override
  String get description => 'Container used as interactive element';

  @override
  List<String> get targetWidgets => ['Container'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Container' &&
        (widget.properties.containsKey('onTap') ||
            widget.sourceCode.contains('GestureDetector'))) {
      issues.add(AccessibilityIssue(
        id: 'interactive-elements-${widget.line}',
        severity: 'high',
        type: 'Non-semantic Interactive Element',
        message: 'Container used as interactive element',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: 'WCAG-4.1.2',
        suggestion:
            'Use semantic button widgets like ElevatedButton or TextButton',
      ));
    }

    return issues;
  }
}

class GestureDetectorAccessibilityRule extends AccessibilityRule {
  @override
  String get ruleId => 'WCAG-2.1.1';
  @override
  String get description => 'GestureDetectors need semantic information';
  @override
  List<String> get targetWidgets => ['GestureDetector'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'GestureDetector' && !isWrappedWithSemantics(widget)) {
      final severity = platform == PlatformType.web ? 'critical' : 'high';
      issues.add(AccessibilityIssue(
        id: '',
        severity: severity,
        type: 'GestureDetector Without Semantics',
        message: 'GestureDetector without semantic information',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Wrap with Semantics widget providing button role and label',
      ));
    }

    return issues;
  }

  // Removed - using centralized method from base class
}

class InkWellAccessibilityRule extends AccessibilityRule {
  @override
  String get ruleId => 'inkwell-accessibility';

  @override
  String get description => 'InkWell with Icon missing semantic information';

  @override
  List<String> get targetWidgets => ['InkWell'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'InkWell' &&
        widget.sourceCode.contains('Icon') &&
        !widget.properties.containsKey('semanticLabel') &&
        !widget.sourceCode.contains('Semantics')) {
      issues.add(AccessibilityIssue(
        id: 'inkwell-accessibility-${widget.line}',
        severity: 'high',
        type: 'Missing InkWell Semantics',
        message: 'InkWell with Icon missing semantic information',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: 'WCAG-1.1.1',
        suggestion: 'Add semanticLabel to Icon or wrap with Semantics widget',
      ));
    }

    return issues;
  }
}

class IconButtonAccessibilityRule extends AccessibilityRule {
  @override
  String get ruleId => 'iconbutton-accessibility';

  @override
  String get description => 'IconButton without tooltip or semantic label';

  @override
  List<String> get targetWidgets => ['IconButton'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'IconButton' &&
        !widget.properties.containsKey('tooltip') &&
        !widget.properties.containsKey('semanticLabel')) {
      issues.add(AccessibilityIssue(
        id: 'iconbutton-accessibility-${widget.line}',
        severity: 'critical',
        type: 'Missing IconButton Label',
        message: 'IconButton without tooltip or semantic label',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion: 'Add tooltip or semanticLabel to describe button purpose',
      ));
    }

    return issues;
  }
}

class EmptyTextWidgetsRule extends AccessibilityRule {
  @override
  String get ruleId => 'empty-text-widgets';

  @override
  String get description => 'Text widget with empty content';

  @override
  List<String> get targetWidgets => ['Text'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Text' &&
        (widget.sourceCode.contains('Text("")') ||
            widget.sourceCode.contains("Text('')"))) {
      issues.add(AccessibilityIssue(
        id: 'empty-text-widgets-${widget.line}',
        severity: 'medium',
        type: 'Empty Text Widget',
        message: 'Text widget with empty content',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion: 'Remove empty Text widget or add meaningful content',
      ));
    }

    return issues;
  }
}

class DisabledElementsRule extends AccessibilityRule {
  @override
  String get ruleId => 'disabled-elements';

  @override
  String get description =>
      'Disabled button without explanation for screen readers';

  @override
  List<String> get targetWidgets =>
      ['ElevatedButton', 'TextButton', 'OutlinedButton'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if ((widget.type == 'ElevatedButton' ||
            widget.type == 'TextButton' ||
            widget.type == 'OutlinedButton') &&
        widget.properties.containsKey('onPressed') &&
        (widget.properties['onPressed'] == null ||
            widget.properties['onPressed'] == 'null' ||
            widget.properties['onPressed'].toString().trim() == 'null') &&
        !widget.properties.containsKey('tooltip') &&
        !widget.properties.containsKey('semanticLabel') &&
        !_isWrappedWithTooltip(widget)) {
      issues.add(AccessibilityIssue(
        id: 'disabled-elements-${widget.line}',
        severity: 'medium',
        type: 'Disabled Element Without Explanation',
        message: 'Disabled button without explanation for screen readers',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Add tooltip or semanticLabel explaining why button is disabled',
      ));
    }

    return issues;
  }

  bool _isWrappedWithTooltip(WidgetInfo widget) {
    // Check if the button is wrapped with a Tooltip widget
    // Look for Tooltip widgets that appear before this widget in the source
    final lineInfo = widget.visitor.compilationUnit.lineInfo;
    final widgetLocation = lineInfo.getLocation(widget.node.offset);
    final widgetLine = widgetLocation.lineNumber;

    for (final otherWidget in widget.visitor.widgets) {
      if (otherWidget.type == 'Tooltip' && otherWidget.line < widgetLine) {
        // Check if this widget appears in the Tooltip widget's child property
        final tooltipSourceCode = otherWidget.sourceCode;
        final widgetSourceSnippet = widget.visitor.sourceCode
            .substring(widget.node.offset, widget.node.end);

        if (tooltipSourceCode.contains(widgetSourceSnippet)) {
          return true;
        }
      }
    }

    return false;
  }
}

class VagueTextContentRule extends AccessibilityRule {
  @override
  String get ruleId => 'vague-text-content';

  @override
  String get description => 'Text with vague content that lacks context';

  @override
  List<String> get targetWidgets => ['Text'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    final vagueTexts = [
      '"Click Here"',
      '"Read More"',
      '"Learn More"',
      '"More"',
      '"Continue"'
    ];

    if (widget.type == 'Text' &&
        vagueTexts.any((vague) => widget.sourceCode.contains(vague))) {
      issues.add(AccessibilityIssue(
        id: 'vague-text-content-${widget.line}',
        severity: 'medium',
        type: 'Vague Text Content',
        message: 'Text with vague content that lacks context',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: 'WCAG-2.4.4',
        suggestion:
            'Use more descriptive text that explains purpose or destination',
      ));
    }

    return issues;
  }
}

class CheckboxAccessibilityRule extends AccessibilityRule {
  @override
  String get ruleId => 'checkbox-accessibility';

  @override
  String get description => 'Checkbox without proper semantic information';

  @override
  List<String> get targetWidgets => ['Checkbox', 'CheckboxListTile'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if ((widget.type == 'Checkbox' || widget.type == 'CheckboxListTile') &&
        !_hasAccessibleLabel(widget)) {
      issues.add(AccessibilityIssue(
        id: 'checkbox-accessibility-${widget.line}',
        severity: 'high',
        type: 'Missing Checkbox Semantics',
        message: 'Checkbox without proper semantic information',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Wrap Checkbox with Semantics widget providing label and state',
      ));
    }

    return issues;
  }

  bool _hasAccessibleLabel(WidgetInfo widget) {
    // CheckboxListTile has built-in accessibility through title property
    if (widget.type == 'CheckboxListTile') {
      return widget.properties.containsKey('title') ||
          widget.sourceCode.contains('title:');
    }

    return widget.properties.containsKey('semanticLabel') ||
        isWrappedWithSemantics(widget) ||
        widget.sourceCode.contains('label:');
  }
}

class SwitchAccessibilityRule extends AccessibilityRule {
  @override
  String get ruleId => 'switch-accessibility';

  @override
  String get description => 'Switch without proper semantic information';

  @override
  List<String> get targetWidgets => ['Switch'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Switch' && !isWrappedWithSemantics(widget)) {
      issues.add(AccessibilityIssue(
        id: 'switch-accessibility-${widget.line}',
        severity: 'high',
        type: 'Missing Switch Semantics',
        message: 'Switch without proper semantic information',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Wrap Switch with Semantics widget providing label and state',
      ));
    }

    return issues;
  }
}

class SliderAccessibilityRule extends AccessibilityRule {
  @override
  String get ruleId => 'slider-accessibility';

  @override
  String get description => 'Slider without proper semantic information';

  @override
  List<String> get targetWidgets => ['Slider'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Slider' &&
        !widget.properties.containsKey('semanticFormatterCallback') &&
        !isWrappedWithSemantics(widget)) {
      issues.add(AccessibilityIssue(
        id: 'slider-accessibility-${widget.line}',
        severity: 'medium',
        type: 'Missing Slider Semantics',
        message: 'Slider without proper semantic value formatting',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Add semanticFormatterCallback or wrap with Semantics for proper value announcement',
      ));
    }

    return issues;
  }
}

class ProgressIndicatorAccessibilityRule extends AccessibilityRule {
  @override
  String get ruleId => 'progress-indicator-accessibility';

  @override
  String get description => 'Progress indicator without semantic information';

  @override
  List<String> get targetWidgets =>
      ['CircularProgressIndicator', 'LinearProgressIndicator'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if ((widget.type == 'CircularProgressIndicator' ||
            widget.type == 'LinearProgressIndicator') &&
        !widget.properties.containsKey('semanticsLabel') &&
        !isWrappedWithSemantics(widget)) {
      issues.add(AccessibilityIssue(
        id: 'progress-indicator-accessibility-${widget.line}',
        severity: 'medium',
        type: 'Missing Progress Indicator Label',
        message: 'Progress indicator without semantic label',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Add semanticsLabel or wrap with Semantics to describe progress state',
      ));
    }

    return issues;
  }
}

class ScaffoldNavigationRule extends AccessibilityRule {
  @override
  String get ruleId => 'scaffold-navigation';

  @override
  String get description => 'Scaffold without proper navigation structure';

  @override
  List<String> get targetWidgets => ['Scaffold'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Scaffold' &&
        !widget.properties.containsKey('appBar') &&
        !widget.properties.containsKey('drawer') &&
        !widget.properties.containsKey('bottomNavigationBar')) {
      issues.add(AccessibilityIssue(
        id: 'scaffold-navigation-${widget.line}',
        severity: 'low',
        type: 'Missing Navigation Structure',
        message: 'Scaffold without clear navigation elements',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: 'WCAG-2.4.1',
        suggestion:
            'Consider adding AppBar, Drawer, or BottomNavigationBar for better navigation',
      ));
    }

    return issues;
  }
}

class ColorOnlyInformationRule extends AccessibilityRule {
  @override
  String get ruleId => 'color-only-information';
  @override
  String get description => 'Information conveyed only through color';

  @override
  List<String> get targetWidgets => ['Container', 'Text', 'Icon'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if ((widget.sourceCode.contains('color:') ||
            widget.sourceCode.contains('backgroundColor:')) &&
        widget.sourceCode.contains('Colors.red') &&
        !widget.sourceCode.contains('Icon(') &&
        !widget.sourceCode.contains('semanticLabel')) {
      issues.add(AccessibilityIssue(
        id: 'color-only-information-${widget.line}',
        severity: 'high',
        type: 'Color-Only Information',
        message: 'Information conveyed only through color (e.g., error states)',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Provide additional visual or semantic cues beyond color (icons, text, semantic labels)',
      ));
    }

    return issues;
  }
}

class ReducedMotionSupportRule extends AccessibilityRule {
  @override
  String get ruleId => 'reduced-motion-support';

  @override
  String get description => 'Animation without reduced motion support';

  @override
  List<String> get targetWidgets =>
      ['AnimatedContainer', 'AnimationController', 'Tween'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if ((widget.type == 'AnimatedContainer' ||
            widget.sourceCode.contains('AnimationController') ||
            widget.sourceCode.contains('Tween')) &&
        !widget.sourceCode
            .contains('MediaQuery.of(context).disableAnimations') &&
        !widget.sourceCode.contains('disableAnimations')) {
      issues.add(AccessibilityIssue(
        id: 'reduced-motion-support-${widget.line}',
        severity: 'medium',
        type: 'Missing Reduced Motion Support',
        message: 'Animation without reduced motion support',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Check MediaQuery.of(context).disableAnimations to respect user motion preferences',
      ));
    }

    return issues;
  }
}

class SemanticTraversalOrderRule extends AccessibilityRule {
  @override
  String get ruleId => 'semantic-traversal-order';

  @override
  String get description => 'Missing semantic traversal order';

  @override
  List<String> get targetWidgets => ['Semantics'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (widget.type == 'Semantics' &&
        widget.sourceCode.contains('sortKey') &&
        !widget.sourceCode.contains('OrdinalSortKey')) {
      issues.add(AccessibilityIssue(
        id: 'semantic-traversal-order-${widget.line}',
        severity: 'low',
        type: 'Semantic Traversal Order',
        message: 'Consider using OrdinalSortKey for explicit traversal order',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: 'WCAG-2.4.3-Mobile',
        suggestion:
            'Use OrdinalSortKey for predictable screen reader navigation order',
      ));
    }

    return issues;
  }
}

class MobileFocusManagementRule extends AccessibilityRule {
  @override
  String get ruleId => 'mobile-focus-management';

  @override
  String get description => 'Missing focus management for mobile';

  @override
  List<String> get targetWidgets => [
        'ElevatedButton',
        'TextButton',
        'OutlinedButton',
        'IconButton',
        'FloatingActionButton'
      ];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (platform != PlatformType.mobile) return issues;

    // Skip Navigator widgets as they only contain the push call, not the context
    if (widget.type == 'Navigator') return issues;

    if (widget.sourceCode.contains('Navigator.push') &&
        !widget.sourceCode.contains('FocusScope.of(context).unfocus()')) {
      issues.add(AccessibilityIssue(
        id: 'mobile-focus-management-${widget.line}',
        severity: 'medium',
        type: 'Missing Focus Management',
        message: 'Navigation without proper focus management',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Manage focus when navigating to ensure screen reader follows navigation',
      ));
    }

    return issues;
  }
}

class MobileTabAccessibilityRule extends AccessibilityRule {
  @override
  String get ruleId => 'mobile-tab-accessibility';

  @override
  String get description => 'Tab accessibility issues for mobile';

  @override
  List<String> get targetWidgets => ['TabBar', 'Tab'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (platform != PlatformType.mobile) return issues;

    if (widget.type == 'TabBar' &&
        !widget.properties.containsKey('semanticLabel')) {
      issues.add(AccessibilityIssue(
        id: 'mobile-tab-accessibility-${widget.line}',
        severity: 'medium',
        type: 'Missing Tab Semantics',
        message: 'TabBar without semantic labels',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Add semantic labels to tabs for better screen reader support',
      ));
    }

    return issues;
  }
}

class MobileFormFieldGroupingRule extends AccessibilityRule {
  @override
  String get ruleId => 'mobile-form-field-grouping';

  @override
  String get description => 'Form field grouping issues for mobile';

  @override
  List<String> get targetWidgets => ['Form', 'TextField'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (platform != PlatformType.mobile) return issues;

    if (widget.type == 'Form' && !isWrappedWithSemantics(widget)) {
      issues.add(AccessibilityIssue(
        id: 'mobile-form-field-grouping-${widget.line}',
        severity: 'medium',
        type: 'Missing Form Grouping',
        message: 'Form without semantic grouping',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion:
            'Group related form fields with Semantics for better navigation',
      ));
    }

    return issues;
  }
}

class MobileDismissibleRule extends AccessibilityRule {
  @override
  String get ruleId => 'mobile-dismissible';

  @override
  String get description => 'Dismissible accessibility issues for mobile';

  @override
  List<String> get targetWidgets => ['Dismissible'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (platform != PlatformType.mobile) return issues;

    if (widget.type == 'Dismissible' &&
        !widget.properties.containsKey('onDismissed')) {
      issues.add(AccessibilityIssue(
        id: 'mobile-dismissible-${widget.line}',
        severity: 'high',
        type: 'Missing Dismissible Handler',
        message: 'Dismissible without proper dismiss handling',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion: 'Provide onDismissed callback and semantic feedback',
      ));
    }

    return issues;
  }
}

class MobileRefreshIndicatorRule extends AccessibilityRule {
  @override
  String get ruleId => 'mobile-refresh-indicator';

  @override
  String get description => 'Refresh indicator accessibility issues for mobile';

  @override
  List<String> get targetWidgets => ['RefreshIndicator'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (platform != PlatformType.mobile) return issues;

    if (widget.type == 'RefreshIndicator' &&
        !widget.properties.containsKey('semanticsLabel')) {
      issues.add(AccessibilityIssue(
        id: 'mobile-refresh-indicator-${widget.line}',
        severity: 'medium',
        type: 'Missing Refresh Semantics',
        message: 'RefreshIndicator without semantic label',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion: 'Add semanticsLabel to describe refresh action',
      ));
    }

    return issues;
  }
}

class MobileTimeoutRule extends AccessibilityRule {
  @override
  String get ruleId => 'mobile-timeout';

  @override
  String get description => 'Timeout accessibility issues for mobile';

  @override
  List<String> get targetWidgets => ['Container', 'Scaffold', 'Column', 'Row'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (platform != PlatformType.mobile) return issues;

    // Only check once per file - use the first widget
    if (widget != widget.visitor.widgets.first) return issues;

    // Check the full source code from the visitor for Timer usage
    final fullSourceCode = widget.visitor.sourceCode;

    if (fullSourceCode.contains('Timer(') &&
        !fullSourceCode.contains('.cancel()')) {
      issues.add(AccessibilityIssue(
        id: 'mobile-timeout-${widget.line}',
        severity: 'high',
        type: 'Missing Timeout Control',
        message: 'Timer without user control or cancellation',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: ruleId,
        suggestion: 'Provide user control to extend or cancel timeouts',
      ));
    }

    return issues;
  }
}

class WebSemanticHtmlRule extends AccessibilityRule {
  @override
  String get ruleId => 'web-semantic-html';

  @override
  String get description => 'Missing semantic HTML structure for web';

  @override
  List<String> get targetWidgets => ['Semantics'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (platform != PlatformType.web) return issues;

    if (widget.type == 'Semantics' &&
        !widget.properties.containsKey('tagName')) {
      issues.add(AccessibilityIssue(
        id: 'web-semantic-html-${widget.line}',
        severity: 'medium',
        type: 'Missing Semantic HTML',
        message: 'Semantics without proper HTML tag mapping for web',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: 'Web-Semantics',
        suggestion: 'Use tagName property to map to appropriate HTML elements',
      ));
    }

    return issues;
  }
}

class WebAriaLabelsRule extends AccessibilityRule {
  @override
  String get ruleId => 'web-aria-labels';

  @override
  String get description => 'Missing ARIA labels for web';

  @override
  List<String> get targetWidgets => ['Semantics'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (platform != PlatformType.web) return issues;

    if (widget.type == 'Semantics' &&
        !widget.properties.containsKey('label') &&
        !widget.properties.containsKey('hint')) {
      issues.add(AccessibilityIssue(
        id: 'web-aria-labels-${widget.line}',
        severity: 'high',
        type: 'Missing ARIA Labels',
        message: 'Interactive element without ARIA labels for web',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: 'Web-ARIA',
        suggestion: 'Add label or hint properties for proper ARIA labeling',
      ));
    }

    return issues;
  }
}

class WebPageTitlesRule extends AccessibilityRule {
  @override
  String get ruleId => 'web-page-titles';

  @override
  String get description => 'Missing page titles for web';

  @override
  List<String> get targetWidgets => ['MaterialApp', 'CupertinoApp'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (platform != PlatformType.web) return issues;

    if ((widget.type == 'MaterialApp' || widget.type == 'CupertinoApp') &&
        !widget.properties.containsKey('title')) {
      issues.add(AccessibilityIssue(
        id: 'web-page-titles-${widget.line}',
        severity: 'high',
        type: 'Missing Page Title',
        message: 'App without title for web accessibility',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: 'Web-Titles',
        suggestion: 'Add title property to app for proper web page titles',
      ));
    }

    return issues;
  }
}

class WebFocusNavigationRule extends AccessibilityRule {
  @override
  String get ruleId => 'web-focus-navigation';

  @override
  String get description => 'Focus navigation issues for web';

  @override
  List<String> get targetWidgets => ['Focus', 'FocusScope'];

  @override
  List<AccessibilityIssue> check(
      WidgetInfo widget, String filePath, PlatformType platform) {
    final issues = <AccessibilityIssue>[];

    if (platform != PlatformType.web) return issues;

    if (widget.sourceCode.contains('Focus') &&
        !widget.sourceCode.contains('autofocus') &&
        !widget.sourceCode.contains('focusNode')) {
      issues.add(AccessibilityIssue(
        id: 'web-focus-navigation-${widget.line}',
        severity: 'medium',
        type: 'Missing Focus Management',
        message: 'Focus element without proper focus management for web',
        file: filePath,
        line: widget.line,
        column: widget.column,
        rule: 'Web-Focus',
        suggestion: 'Use focusNode or autofocus for proper keyboard navigation',
      ));
    }

    return issues;
  }
}
