# Conalyz — Flutter & Jetpack Compose Accessibility Analyzer

[![Agent Skill](https://img.shields.io/badge/Agent%20Skill-SKILL.md-blue)](./SKILL.md)
[![Pub Version](https://img.shields.io/badge/version-0.2.0-blue)](https://pub.dev/packages/conalyz)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/conalyz/conalyz_cli)](https://github.com/conalyz/conalyz_cli/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/conalyz/conalyz_cli)](https://github.com/conalyz/conalyz_cli/network)
[![GitHub issues](https://img.shields.io/github/issues/conalyz/conalyz_cli)](https://github.com/conalyz/conalyz_cli/issues)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/conalyz/conalyz_cli/pulls)

A powerful command-line tool for analyzing Flutter and Native Android (Jetpack Compose) applications for accessibility issues. Conalyz uses AST-based analysis for Flutter/Dart and Oregex-based analysis for Native Android/Kotlin to provide comprehensive accessibility checks for Material, Cupertino, and Compose widgets, helping developers ensure their applications are accessible to all users.

## Features

- **AST & Oregex Analysis**: Fast and accurate analysis using AST parsing (Flutter) and Oregex (Native Android). This hybrid approach provides deep insights for Flutter widgets while maintaining high performance for Kotlin/Compose files.
- **Comprehensive Widget Coverage**: Supports Material, Cupertino, custom Flutter widgets, and Jetpack Compose UI components.
- **Jetpack Compose Support**: Dedicated rules for content descriptions, touch targets, hardcoded text, semantic keys, reduced motion, and redundant semantics.
- **Multi-Platform Support**: Analyze for mobile and web platforms.
- **Interactive Reports**: Generate HTML reports with filtering and detailed issue information
- **JSON Export**: Export results for CI/CD integration
- **Usage Tracking**: Track your analysis statistics and productivity insights
- **WCAG Compliance**: Validates against Web Content Accessibility Guidelines

## Jetpack Compose Support

Conalyz provides dedicated accessibility checks for Native Android (Kotlin) and Jetpack Compose, including:

- **Missing Content Descriptions**: Ensuring `Image`, `Icon`, and `IconButton` have appropriate screen reader labels.
- **Small Touch Targets**: Validating that interactive components meet the 48dp minimum size requirement (Material Design + WCAG).
- **Hardcoded Text**: Flagging text literals that should use string resources (`R.string.key`) for i18n/a11y support.
- **Missing Semantic Keys**: Identifying `LazyColumn` and `LazyRow` items that lack stable keys for TalkBack traversal.
- **Reduced Motion Support**: Checking that animations respect system-level reduced-motion settings (`LocalReduceMotion`).
- **Form Field Accessibility**: Ensuring `TextField` and `OutlinedTextField` have labels or placeholders.
- **Semantic Roles**: Validating that custom clickable containers define a semantic role (e.g., `Role.Button`).
- **Redundant Semantics**: Detecting unnecessary `mergeDescendants` or `isTraversalGroup` configurations that match defaults.

## How it Works

Conalyz uses a hybrid analysis engine for maximum accuracy and performance:

- **AST (Abstract Syntax Tree)**: Used for Flutter and Dart files to perform deep semantic analysis of widget hierarchies and property values.
- **Oregex (Optimized Regex)**: Used for Native Android (Kotlin) and Jetpack Compose to perform fast, robust analysis of composable structures and modifier patterns without the overhead of full Kotlin parsing.

### Under the Hood (Oregex)

Oregex was chosen for Kotlin and Jetpack Compose to provide high performance and easy maintenance for a wide range of accessibility patterns. The analyzer uses:

- **Brace Balancing**: A custom character-by-character algorithm to accurately extract composable context, including trailing lambdas (e.g. `items { }` blocks).
- **Comment-Aware Processing**: Logic that intelligently ignores matches inside line comments while respecting string and character literals.
- **Optimized Lookups**: Uses binary search ($O(\log N)$) for efficient line and column mapping across large source files.
- **Regex Heuristics**: Fine-tuned regular expressions to validate properties like touch targets (48dp+) and hardcoded text lengths (2+ characters) with minimal false positives.

## AI Agent Skill

Use conalyz directly inside Claude Code, Cursor, Copilot, Windsurf, and 35+ more AI agents:

```bash
npx skills add conalyz/conalyz_cli
```

Then just ask your AI: *"Check my Flutter/Android app for accessibility issues"*

## Installation

Add Conalyz as a global package:

```bash
dart pub global activate conalyz
```

Make sure your PATH includes the pub cache bin directory. Add this to your shell profile if needed:

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

## Quick Start

Navigate to your Flutter project and run:

```bash
conalyz --path ./lib
```

Open the generated HTML report:

```bash
open accessibility_report/accessibility_report.html
```

## Usage

### Basic Commands

```bash
# Analyze a Mobile (Flutter or Jetpack Compose) project
conalyz --path /path/to/your/project/lib --platform mobile

# Analyze a specific Dart or Kotlin file
conalyz --path lib/main.dart --platform mobile

# Analyze for web platform
conalyz --path ./lib --platform web

# Custom output directory
conalyz --path ./lib --output ./reports

# View usage statistics
conalyz usage

# View detailed usage analytics
conalyz usage --detailed
```

### Command Line Options

**Analysis Options:**
- `--path, -p`: Path to Flutter/Android project directory or Dart/Kotlin file (required)
- `--platform, -t`: Target platform: `mobile` or `web` (default: `mobile`)
- `--output, -o`: Output directory for reports (default: `accessibility_report`)
- `--json`: Generate JSON report (default: `true`)
- `--html`: Generate HTML report (default: `true`)
- `--debug`: Enable debug output for troubleshooting
- `--version, -v`: Show version information
- `--help, -h`: Show help message

**Usage Command:**
```bash
conalyz usage [--detailed]
```

## Reports

### HTML Report

The HTML report provides:
- Summary dashboard with issue counts by severity
- Interactive filtering by type and severity
- Detailed issue view with file locations and code snippets
- WCAG compliance information
- Step-by-step fix suggestions

### JSON Report

The JSON report includes:
- Summary statistics (total issues, severity breakdown, files analyzed)
- Detailed issue list with file locations, line numbers, and suggestions
- Analysis metadata (time, platform, lines scanned)

## Examples

```bash
# Basic analysis
conalyz --path ./lib

# Analyze for web with custom output
conalyz --path ./lib --platform web --output ./web-reports

# Analyze single file with debug output
conalyz --path lib/screens/home_screen.dart --debug

# Check your usage statistics
conalyz usage --detailed
```

## Accessibility Checks

Conalyz checks for:
- Missing semantic labels on interactive widgets (Flutter & Compose)
- Insufficient color contrast
- Accurate minimum touch target sizing (e.g. 48dp metrics)
- Missing tooltips on icon buttons
- Inaccessible gesture detectors
- Form field accessibility issues
- Image accessibility (alt text / content descriptors)
- Focus management issues
- Proper LazyList semantic keys and LocalReduceMotion checks (Jetpack Compose)
- And many more...

## Code Structure & Best Practices

- All Jetpack Compose and Kotlin Oregex analysis code is now under `lib/src/compose/`.
- Compose rules, redundant semantics, and analyzer logic are separated for clarity and maintainability.
- Some Compose accessibility thresholds (for example, 48dp touch-target checks) are currently expressed inline in rule strings/regex, so related values should be kept consistent when rules are updated.
- All classes and public methods are documented with Dart doc comments.
- The codebase adheres to OOP, SOLID, and clean architecture principles:
  - Each rule is a class implementing a clear interface.
  - No business logic in UI or analyzer entrypoints.
  - Repeated values should be extracted into constants or enums where practical, but some Compose rule thresholds are currently inlined.
  - Each file has a single responsibility.

## Android Native & Compose Packages

- Jetpack Compose and Kotlin-specific rules are in `lib/src/compose/`.
- If you add new Android native (non-Compose) rules, create a `lib/src/kotlin/` package and follow the same structure.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Support

For issues and feature requests, please visit our [issue tracker](https://github.com/yourusername/conalyz/issues).
