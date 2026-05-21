# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run all tests
dart test

# Run a single test file
dart test test/optimized_ast_analyzer_test.dart

# Run the CLI locally (without installing)
dart run bin/conalyz.dart --path ./example

# Format code
dart format lib/ bin/ test/

# Analyze code
dart analyze

# Activate globally for manual testing
dart pub global activate --source path .
```

## Architecture

This is a Dart CLI package (`bin/conalyz.dart` is the entry point) published to pub.dev as `conalyz`.

**Entry point → command dispatch** (`bin/conalyz.dart`): The `main()` function manually dispatches on the first argument to one of three handlers: analysis (default), `usage`, or `update`. There is no formal command framework — subcommands are parsed inline.

**Analysis pipeline** (`lib/src/optimized_ast_analyzer.dart`):
1. `OptimizedAstFlutterAccessibilityAnalyzer` is instantiated with a rule set loaded in `_initializeRules()`.
2. For each `.dart` file, the file is parsed into an AST using `package:analyzer`'s `parseString()`.
3. `OptimizedWidgetExtractionVisitor` walks the AST and builds a flat list of `WidgetInfo` objects, one per detected Flutter widget constructor or method invocation.
4. Each `WidgetInfo` is matched against rules via `_getRelevantRules(widget.type)` — each `AccessibilityRule` declares `targetWidgets`, an empty list meaning "match all".
5. Issues are collected as `AccessibilityIssue` objects and aggregated into an `AnalysisResult`.

**Adding a new rule**: Create a class extending `AccessibilityRule` in `lib/src/flutter_specific_rules.dart` (Flutter-specific) or `lib/src/optimized_ast_analyzer.dart` (core/web), then register it in `_initializeRules()`. Web-only rules should return early when `platform != PlatformType.web`.

**Report generation** (`lib/src/ast_report_generator.dart`): `AstReportGenerator` converts an `AnalysisResult` to JSON and/or HTML. HTML is self-contained with inline CSS/JS.

**Usage tracking** (`lib/src/usage_storage_service.dart`, `lib/src/usage_models.dart`): Usage records are stored as JSON in `~/.conalyz/usage.json`. Daily file-count limits are enforced before analysis runs (`checkDailyLimit`). The `UsageStorageService` constructor accepts a `testStoragePath` for test isolation.

**Telemetry** (`lib/src/telemetry.dart`): Anonymous, opt-out telemetry sent via HTTP POST to `https://conalyz.com/telemetry`. Two public entry points: `checkFirstRunNotice()` (top-level, called once at startup) and `Telemetry.trackAnalysis()` / `Telemetry.trackError()` (static, fire-and-forget). Both skip silently when `CONALYZ_NO_ANALYTICS=true`, `DO_NOT_TRACK=1`, or a `CI` environment variable is present. The last-run issue count is cached in `~/.config/conalyz/last_run.json` to compute fix-rate deltas between runs.

**Platform-conditional rules**: `PlatformType` is passed through to every `rule.check()` call. Mobile-only rules check `if (platform != PlatformType.mobile) return issues;` at the top.

## Version constant

The version string lives in **two** places — `pubspec.yaml` and `lib/src/constants.dart` (`conalyzVersion`). Both must be updated together when releasing. `bin/conalyz.dart` and `lib/src/telemetry.dart` import `conalyzVersion` from `constants.dart` and must not hardcode it.

## Test structure

Each concern has its own test file:
- `optimized_ast_analyzer_test.dart` — core rule engine and widget extraction
- `flutter_specific_rules_test.dart` — Flutter-specific rules (MergeSemantics, etc.)
- `web_rules_test.dart` — web-only rules
- `tab_accessibility_test.dart` — TabBar false-positive regression tests
- `usage_storage_service_test.dart` / `usage_models_test.dart` — usage tracking
- `update_command_test.dart` — update command
- `integration_test.dart` — end-to-end analysis on temp directories

## Linting notes

`avoid_print: false` is intentionally set — this is a CLI tool that uses `print()` for all user-facing output. Do not replace `print` calls with a logger.
