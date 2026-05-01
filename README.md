# Conalyz

[![Agent Skill](https://img.shields.io/badge/Agent%20Skill-SKILL.md-blue)](./SKILL.md)
[![Pub Version](https://img.shields.io/pub/v/conalyz.svg)](https://pub.dev/packages/conalyz)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/conalyz/conalyz_cli)](https://github.com/conalyz/conalyz_cli/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/conalyz/conalyz_cli)](https://github.com/conalyz/conalyz_cli/network)
[![GitHub issues](https://img.shields.io/github/issues/conalyz/conalyz_cli)](https://github.com/conalyz/conalyz_cli/issues)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/conalyz/conalyz_cli/pulls)

A powerful command-line tool for analyzing Flutter applications for accessibility issues. Conalyz uses AST-based analysis to provide comprehensive accessibility checks for both Material and Cupertino widgets, helping developers ensure their Flutter applications are accessible to all users.

## Features

- **AST-based Analysis**: Fast and accurate analysis using Abstract Syntax Tree parsing
- **Comprehensive Widget Coverage**: Supports Material, Cupertino, and custom widgets
- **Multi-Platform Support**: Analyze for mobile and web platforms
- **Interactive Reports**: Generate HTML reports with filtering and detailed issue information
- **JSON Export**: Export results for CI/CD integration
- **Usage Tracking**: Track your analysis statistics and productivity insights
- **WCAG Compliance**: Validates against Web Content Accessibility Guidelines

## AI Agent Skill

Use conalyz directly inside Claude Code, Cursor, Copilot, Windsurf, and 35+ more AI agents:

```bash
npx skills add conalyz/conalyz_cli
```

Then just ask your AI: *"Check my Flutter app for accessibility issues"*

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
# Analyze a Flutter project
conalyz --path /path/to/your/flutter/project/lib

# Analyze a specific Dart file
conalyz --path lib/main.dart

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
- `--path, -p`: Path to Flutter project directory or Dart file (required)
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
- Missing semantic labels on interactive widgets
- Insufficient color contrast
- Missing tooltips on icon buttons
- Inaccessible gesture detectors
- Form field accessibility issues
- Image accessibility (alt text)
- Focus management issues
- And many more...

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Support

For issues and feature requests, please visit our [issue tracker](https://github.com/conalyz/conalyz_cli/issues).
