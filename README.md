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
- **Custom Semantics Wrappers**: Discover wrappers in your app and local packages, review each type, and reuse approved mappings during static analysis
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

Navigate to your Flutter project root, resolve its dependencies, and run:

```bash
flutter pub get
conalyz --dir .
```

On the first interactive run, review any supported custom semantics wrappers.
Conalyz saves the approved mappings in `conalyz.static.yaml` and continues analysis.
On later runs, you can skip review and use the saved mappings.

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

### Custom semantics wrapper discovery

If your company wraps Flutter's `Semantics` in its own reusable widgets, Conalyz
can learn which parameters provide a label and which parameter contains the child.
This reduces missing-label findings caused by unrecognized design-system wrappers.
No separate setup command or handwritten mapping is needed.

#### 1. Run normal analysis

```bash
flutter pub get
conalyz --dir .
```

On the first interactive run, Conalyz searches the project's `lib/` directory and
recursively referenced local `path:` packages. For example, wrappers in this local
design-system package are included:

```yaml
dependencies:
  company_design_system:
    path: ../company_design_system
```

Hosted pub.dev packages, Git dependencies, and unrelated directories are not scanned.
The configuration belongs to the app being analyzed, including approvals for wrappers
found in local packages.

#### 2. Review each detected wrapper type

A supported wrapper forwards named parameters directly into Flutter `Semantics`.
For example, in `lib/widgets/company_semantics.dart`:

```dart
import 'package:flutter/widgets.dart';

class CompanySemantics extends StatelessWidget {
  final String? accessibilityLabel;
  final Widget child;

  const CompanySemantics({
    super.key,
    this.accessibilityLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        label: accessibilityLabel,
        child: child,
      );
}
```

The app can then use it around a control:

```dart
CompanySemantics(
  accessibilityLabel: 'Add item',
  child: IconButton(
    icon: const Icon(Icons.add),
    onPressed: () {},
  ),
)
```

Conalyz shows numbered candidates, definition locations, and detected mappings:

```text
  1. CompanySemantics
     Source: lib/widgets/company_semantics.dart:3
     Library: package:my_app/widgets/company_semantics.dart
     Parameters:
       • accessibilityLabel → Semantics.label
       • child → Semantics.child

     Include this wrapper in static analysis? [y/N]
```

- Approve or skip each **wrapper type**, not every usage. A wrapper used 200 times
  requires one decision in that review.
- Different wrapper types are reviewed separately. Only the approved types are saved.
- New or changed mappings default to **No**; enter `y` to include them.
- Unsupported candidates show their source and an explanation, without an approval prompt.

The first version supports stateless widget classes with an unconditional, direct
`Semantics` return, final label/child fields, and one unnamed constructor forwarding
those fields through named parameters. Conditional semantics, transformed labels,
wrapper chains, function wrappers, and inference of roles/hints/values are outside
this first version.

#### 3. Reuse the saved approvals

After all decisions, Conalyz saves the approved mappings together in
`<project>/conalyz.static.yaml` and uses them in the **same analysis**. A generated
file for an app named `my_app` looks like this:

```yaml
semanticWrappers:
  package:my_app/widgets/company_semantics.dart#CompanySemantics:
    widget: CompanySemantics
    library: package:my_app/widgets/company_semantics.dart
    label: accessibilityLabel
    child: child
wrapper_review:
  last_reviewed_at: '2026-11-17T05:00:00.000Z'
```

The library identity distinguishes unrelated classes with the same name. The review
timestamp records when review finished, including a review with no approved wrappers.
Commit this file so teammates and CI use the same mappings; Git provides the change
history. You do not need to create this YAML manually.

Registration is not blanket approval of a widget. A missing, literal null, empty,
or whitespace-only forwarded label still produces missing-label findings, and the
mapping applies only inside its configured child argument. Other accessibility
checks remain active. JSON and HTML reports include the loaded wrapper configuration
and review timestamp when a config file is used.

#### 4. Review again when wrappers change

On later interactive runs, Conalyz asks:

```text
Review custom semantics wrappers again? [y/N]
```

- **No** (the default): analyze with saved mappings, without discovery or rewriting
  the YAML or its timestamp.
- **Yes**: discover again and review each supported type. An unchanged approval
  defaults to Yes; new or changed mappings require approval. Previously skipped
  wrappers can be offered again.

During an explicit review, declined registrations and definitions that are missing
or unsupported are removed, with a message explaining the removal. Other settings
and comments are preserved. Configuration is saved after the review completes;
cancelling before completion does not save partial decisions. Without a review,
Conalyz continues using the saved contract rather than rechecking wrapper definitions.

#### Optional: choose a different configuration file

Most projects should simply use `conalyz --dir .`. That automatically reads and saves
`conalyz.static.yaml` in the selected project.

Use `--config` only when you want the approved wrapper mappings stored in a different
file, such as a file your team has chosen to keep under another name:

```bash
# Read approved mappings from team-static.yaml instead of conalyz.static.yaml.
# If you choose to review wrappers, save the decisions to team-static.yaml too.
conalyz --dir . --config ./team-static.yaml
```

`team-static.yaml` is an example filename you choose, not a built-in preset. It uses
the same generated YAML format shown above. The selected file **replaces** the default
for that run; Conalyz does not copy or merge `conalyz.static.yaml` into it. If it does
not exist, an interactive run can create it after reviewing the discovered wrappers.

`--dir` selects the project to analyze. `--config` selects the mapping file to read
and save. Relative `--config` paths start from your current working directory, not
from the directory passed to `--dir`. Neither option changes where reports are saved;
use `--output` for that.

#### CI and non-interactive runs

CI and non-interactive runs never discover wrappers, prompt, or create configuration.
They read the saved mappings when available and perform standard analysis when the
default config is absent. An explicitly selected `--config` file must exist in CI;
a missing file or invalid configuration fails the command.

`conalyz.static.yaml` contains source-analysis wrapper mappings. It is separate from
`conalyz.yaml`, which describes navigation for runtime analysis.

### Supplying a Dart SDK when embedding the analyzer

Library callers can pass an optional `sdkPath` to `prepareStaticAnalysis` and
`OptimizedAstFlutterAccessibilityAnalyzer`. Pass the same installed Dart SDK root
(the directory containing `bin`, `lib`, and `version`) to both:

```dart
final configuration = await prepareStaticAnalysis(
  projectRoot: projectRoot,
  sdkPath: sdkPath,
);
final analyzer = OptimizedAstFlutterAccessibilityAnalyzer(
  configuration: configuration,
  sdkPath: sdkPath,
);
```

`WrapperDiscovery` and `WrapperReview` also accept `sdkPath` when used directly.
SDK selection belongs to the caller; omitting this option preserves the analyzer's
default behavior. SDK paths are local to the process and are not saved in wrapper
configuration. A supplied custom discovery implementation manages its own resolver.

### Command Line Options

**Analysis Options:**
- `--dir, -d`: Flutter project root; analysis runs on `<dir>/lib` (default: current directory)
- `--platform, -t`: Target platform: `mobile` or `web` (default: `mobile`)
- `--config <file>`: Read approved wrapper mappings from this YAML file and save any completed wrapper review back to it. Optional; defaults to `<project>/conalyz.static.yaml`. Replaces the default file for the run; see [the explanation above](#optional-choose-a-different-configuration-file).
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
- Loaded custom-wrapper configuration and review timestamp, when a config is used

### JSON Report

The JSON report includes:
- `generatedAt`, `summary` (total violations, severity breakdown, files analysed)
- Flat `violations` array with `severity`, `type`, `message`, `file`, `line`, `column`, and `suggestion` per entry
- `configuration` metadata with the config path, wrapper mappings, and review timestamp when a config is used

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
