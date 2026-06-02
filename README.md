# Conalyz

[![Agent Skill](https://img.shields.io/badge/Agent%20Skill-SKILL.md-blue)](./SKILL.md)
[![Pub Version](https://img.shields.io/pub/v/conalyz.svg)](https://pub.dev/packages/conalyz)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Docs](https://img.shields.io/badge/Docs-docs.conalyz.com-82C88F)](https://docs.conalyz.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/conalyz/conalyz_cli)](https://github.com/conalyz/conalyz_cli/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/conalyz/conalyz_cli)](https://github.com/conalyz/conalyz_cli/network)
[![GitHub issues](https://img.shields.io/github/issues/conalyz/conalyz_cli)](https://github.com/conalyz/conalyz_cli/issues)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/conalyz/conalyz_cli/pulls)

A command-line tool for analyzing Flutter applications for accessibility issues. Conalyz uses AST-based static analysis to provide comprehensive accessibility checks for both Material and Cupertino widgets, helping developers catch issues early — before the app runs.

## Features

- **AST-based Analysis**: Fast analysis using Abstract Syntax Tree parsing — no device or emulator needed
- **Comprehensive Widget Coverage**: Supports Material, Cupertino, and custom widgets
- **Multi-Platform Support**: Analyze for mobile and web platforms
- **Interactive Reports**: HTML reports with per-file issue cards, severity filtering, and type filtering
- **JSON Export**: Structured output for CI/CD integration
- **Usage Tracking**: Track your analysis statistics and productivity insights
- **WCAG Compliance**: Validates against Web Content Accessibility Guidelines

> **Static analysis covers:** missing semantic labels, missing tooltips, inaccessible gesture detectors, form field labels, image alt text, vague labels, and known colour contrast issues detected from source code.
>
> **Not available in static mode:** actual touch target sizes, runtime contrast ratios, focus traversal order, and slider values — these require the app to be running. See [Runtime Analysis](#runtime-analysis) below.

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

Navigate to your Flutter project root and run:

```bash
conalyz --dir .
```

Open the generated HTML report:

```bash
open accessibility_report/accessibility_report.html
```

## Usage

### Basic Commands

```bash
# Analyze the current Flutter project
conalyz --dir .

# Analyze a specific project directory
conalyz --dir /path/to/your/flutter/project

# Analyze for web platform
conalyz --dir . --platform web

# Custom output directory
conalyz --dir . --output ./reports

# View usage statistics
conalyz usage

# View detailed usage analytics
conalyz usage --detailed

# Update conalyz to the latest version
conalyz update
```

### Command Line Options

**Analysis Options:**
- `--dir, -d`: Flutter project root; analysis runs on `<dir>/lib` (default: current directory)
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
- Health score and summary dashboard with issue counts by severity
- Per-file issue cards with expandable violation details and fix suggestions
- Interactive filtering by severity and issue type
- WCAG compliance references per check

### JSON Report

The JSON report includes:
- `generatedAt`, `summary` (total violations, severity breakdown, files analysed)
- Flat `violations` array with `severity`, `type`, `message`, `file`, `line`, `column`, and `suggestion` per entry

## Examples

```bash
# Analyse current project
conalyz --dir .

# Analyse a specific project for web
conalyz --dir ./my_app --platform web --output ./web-reports

# Analyse with debug output
conalyz --dir . --debug

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

- **Documentation:** [docs.conalyz.com](https://docs.conalyz.com)
- **Issues & feature requests:** [GitHub issue tracker](https://github.com/conalyz/conalyz_cli/issues)

## Runtime Analysis

Static analysis catches issues in source code, but some accessibility problems only surface when the app is actually running — touch targets that render too small, real contrast ratios after theme application, focus traversal order, and slider state.

**Conalyz runtime analysis** connects to a running Flutter app, reads the live Semantics and Focus trees, and captures screenshots to measure these properties against WCAG criteria. It requires no code changes to your app and works on Android and iOS.

### Install via Homebrew

```bash
brew tap conalyz/conalyz
brew install conalyz/conalyz/conalyz
```

Once installed, the `conalyz` command supersedes the pub.dev version and includes both static and runtime modes:

```bash
# Static analysis (same as pub.dev version)
conalyz --dir .

# Runtime analysis — connects to your running Flutter app
conalyz manual --dir .   # prompt for screen names as you navigate
conalyz auto   --dir .   # drive the app automatically using conalyz.yaml
conalyz capture --dir .  # record a session and replay it
```

### Generate conalyz.yaml with AI

The `conalyz-init` skill generates `conalyz.yaml` automatically from your router config and screen files. It works with Claude Code, Cursor, Copilot, Windsurf, and 35+ other AI agents that support the skills protocol.

Install the skill from your Flutter project root:

```bash
mkdir -p .claude/commands && curl -o .claude/commands/conalyz-init.md \
  https://raw.githubusercontent.com/conalyz/conalyz_cli/master/conalyz/SKILL_INIT.md
```

Then invoke `/conalyz-init` in your AI agent. It reads your router, extracts widget labels, shows a preview of the navigation flow, and writes `conalyz.yaml` after your approval.

---

## Anonymized Telemetry

To prioritize feature development, conalyz collects lightweight anonymous telemetry.

### What is collected
- Which accessibility issue types were found (counts only, e.g. `missing_tooltip: 3`)
- Command flags used (e.g. `--platform`, `--output`)
- OS platform and tool version
- Whether run in CI or on a Flutter project
- Scan duration and file count (as size bucket: small/medium/large)

### What is NOT collected
- No filenames, file paths, or source code
- No personal data, emails, hostnames, or IP addresses
- No data when running in CI (skipped automatically)

### Opt out
```bash
export CONALYZ_NO_ANALYTICS=true
# or
export DO_NOT_TRACK=1
```

When you opt out, a single one-time event is sent to record the opt-out (country and version only). After that, nothing is ever sent again.
