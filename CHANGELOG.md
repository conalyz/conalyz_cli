## 1.0.0

* **Unified Mobile Platform**: Flutter and Jetpack Compose analysis are now unified under the `--platform mobile` flag.
* **Automatic Detection**: The analyzer now automatically detects `.dart` and `.kt` files within a project and runs the appropriate analysis engine.
* **Hybrid Analysis**: Support for mixed projects containing both Flutter and Kotlin code, with results merged into a single report.
* Removed the explicit `androidNative` platform flag to simplify the user interface.
* Enhanced HTML reports with dynamic labeling based on detected file types.

## 0.2.0

* Native Android Development Support! Added full Oregex-based support for Kotlin files and Jetpack Compose.
* Introduced rules for Jetpack Compose (Content Descriptions, Hardcoded text, Touch Targets, Semantic Keys, Reduced Motion).
* Added `androidNative` platform flag to the CLI (`--platform androidNative`).
* Overall pipeline enhancements to support `.kt` alongside `.dart` files robustly.

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
