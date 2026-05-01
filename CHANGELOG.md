## 0.1.3

* Fixed Issue #11: Bug: GestureDetector accessibility rule incorrectly flags widgets with excludeFromSemantics: true
* Fixed Issue #6: Added support for MergeSemantics as a valid accessibility container for Switch, Checkbox, and other interactive widgets.
Enhanced Accessibility Rule Logic: Improved the semantic wrapping check to handle grouped semantic nodes using the MergeSemantics pattern (a standard practice for combining controls like Switch with labels in a ListTile).
Expanded Test Coverage: Added permanent test cases to test/optimized_ast_analyzer_test.dart and improved the test helper for more accurate widget extraction and AST node mapping.
* Fixed Issue #7: Resolved false positive in TabBar accessibility analysis:* Suppressed missing semantic label warnings when all tabs contain readable text (text property or nested Text/RichText widgets).
* Added RichText to core Flutter widgets identified by the analyzer.

## 0.1.2

* Added an agent skill (`conalyz/SKILL.md`) for AI assistants (e.g., Claude Code, Cursor, Copilot).
* Added WCAG reference section and detailed step-by-step instructions to `SKILL.md`.
* Enhanced README with a comprehensive badge row.

## 0.1.1

* Fixed compatibility issues with analyzer package `v9.0.0+`.
* Updated `name2` to `name` property in AST traversal to match the latest analyzer API.
* Removed unused imports and improved code quality.
* Fixed potential null safety issues in widget analysis.
* Updated minimum Dart SDK version to `3.0.0`.
* Improved error handling in AST traversal.

## 0.1.0

* Initial release of Conalyz CLI.
* AST-based Flutter accessibility analyzer with comprehensive widget coverage.
* Support for both mobile and web platforms.
* Automatic usage tracking (lines scanned, analysis time).
* JSON and HTML report generation.
* Detailed usage statistics and productivity insights.
* Support for analyzing entire Flutter projects or individual Dart files.
* Comprehensive checks for Material and Cupertino widgets.
* WCAG compliance validation.
* Interactive HTML reports with filtering capabilities.
