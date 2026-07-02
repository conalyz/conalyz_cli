## Unreleased

## 1.1.0

* Added support for Flutter's new sliver semantics widgets: `SliverSemantics` (the sliver-level equivalent of `Semantics`) and `SliverEnsureSemantics`. `SliverSemantics` is now recognised as a valid semantics wrapper and checked for meaningful properties, while `SliverEnsureSemantics` and `IndexedSemantics` are recognised as structural widgets.
* Fixed a false positive where `Semantics`/`SliverSemantics` widgets annotated only with newer accessibility properties (`role`, `headingLevel`, `textField`, scroll actions, attributed labels/values/hints, and others) were incorrectly flagged as "Incomplete Semantics".

## 1.0.0

**Breaking change:** JSON report schema restructured — if you consume `conalyz_report.json` in CI/CD pipelines, update your parsing logic. New top-level shape: `generatedAt`, `summary` (`totalViolations`, `bySeverity`, `filesAnalysed`), and a flat `violations` array with standardised field names across all violation types.

* Added `--dir` flag (short: `-d`) that accepts a Flutter project root and derives `<dir>/lib` as the analysis path. `--path`/`-p` still works but now prints a deprecation warning. Running `conalyz` with no path flags defaults to the current project (`./lib`).
* Upgrade hint printed at the bottom of every run; suppressed automatically when already on the latest distribution channel.
* HTML report redesigned: cleaner layout, consistent typography, health score widget, per-file issue organisation with expandable cards and severity badges.
* JSON report restructured: consistent top-level schema (`generatedAt`, `summary`, `violations`) with standardised field names across all violation types.
* Added `conalyz-init` skill (`conalyz/SKILL_INIT.md`) for AI agents (Claude Code, Cursor, Copilot, Windsurf, and others). Install with `curl` and invoke `/conalyz-init` to generate `conalyz.yaml` from your router and screen files.

## 0.2.3

* Improved accessibility rule suggestions to be context-aware and actionable — suggestions now include the actual icon name, detected fontSize value, input type, gesture type, slider min/max, and other details extracted from the source code instead of generic advice.
* Added one-time anonymous opt-out event so regional opt-out rates can be understood without collecting ongoing data from opted-out users.
* README: disclosed the one-time opt-out event in the telemetry section.

## 0.2.2

* Fix telemetry events not being delivered by awaiting the HTTP request before process exit.

## 0.2.1

* Fix telemetry endpoint URL to point directly to Cloudflare Worker.

## 0.2.0

* Correct placeholder repository link in generated reports
* Added support for the latest analyzer package (v13.0.0) and updated AST traversal logic to accommodate API changes.
* Added a new `update` command to the CLI for easy updating of the conalyz package to the latest version.
* Updated test suite to include tests for the new `update` command and to ensure compatibility with
* Added privacy-first anonymous telemetry (opt-out via `CONALYZ_NO_ANALYTICS=true` or `DO_NOT_TRACK=1`). Collects aggregate issue counts, OS, and command flags only — no code, filenames, or personal data. Skipped automatically in CI environments.

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
