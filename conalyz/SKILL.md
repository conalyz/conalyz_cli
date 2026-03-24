---
name: conalyz
description: Flutter accessibility analyzer that checks your apps for WCAG compliance, semantic labels, color contrast, and more accessibility issues.
---

# Conalyz — Flutter Accessibility Analyzer

A comprehensive Flutter accessibility analyzer that helps you create inclusive applications by identifying and fixing accessibility issues.

## What it does

- **Accessibility Analysis**: Scans Flutter projects for accessibility violations
- **WCAG Compliance**: Validates against Web Content Accessibility Guidelines
- **Widget Coverage**: Analyzes Material, Cupertino, and custom widgets
- **Detailed Reports**: Generates HTML and JSON reports with fix suggestions
- **Multi-Platform**: Supports both mobile and web platforms

## How to use

Simply ask me to analyze your Flutter app for accessibility issues:

```
"Check my Flutter app for accessibility issues"
"Audit lib/screens/ for WCAG compliance"
"Find missing semantic labels in my widgets"
"Fix accessibility issues in home_screen.dart"
"Analyze accessibility for web platform"
```

## What I need

- Path to your Flutter project or specific Dart files
- Target platform (mobile or web) - defaults to mobile
- Optional output directory for reports

## Example commands

```bash
# Basic analysis
conalyz --path ./lib

# Analyze specific file
conalyz --path lib/screens/home_screen.dart

# Web platform analysis
conalyz --path ./lib --platform web

# Custom output directory
conalyz --path ./lib --output ./accessibility-reports
```

## What I check

- Missing semantic labels on interactive widgets
- Insufficient color contrast ratios
- Missing tooltips on icon buttons
- Inaccessible gesture detectors
- Form field accessibility issues
- Image accessibility (alt text)
- Focus management problems
- And many more accessibility violations

## Reports

I generate comprehensive reports including:
- **HTML Report**: Interactive dashboard with filtering and detailed issue views
- **JSON Report**: Machine-readable format for CI/CD integration
- **Fix Suggestions**: Step-by-step guidance for each issue
- **Severity Levels**: Critical, high, medium, and low priority issues

## Installation

The conalyz CLI tool should be installed as a global Dart package:

```bash
dart pub global activate conalyz
```

Make sure your PATH includes the pub cache bin directory:

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```