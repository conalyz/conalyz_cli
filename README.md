# Flutter Accessibility Advisor CLI (Beta)

> ⚠️ **Beta Notice**: This is a beta version of the Flutter Accessibility Advisor CLI. 
> Please report any issues or feedback to our team.

A powerful command-line tool for analyzing Flutter applications for accessibility issues. This tool helps developers ensure their Flutter applications are accessible to all users by checking against WCAG (Web Content Accessibility Guidelines) standards.

## 🚀 Getting Started (Beta Users)

### Prerequisites
- macOS (Intel or Apple Silicon)
- Flutter SDK (if analyzing Flutter projects)

### Installation

1. Download the latest binary from the beta release
2. Make it executable:
   ```bash
   chmod +x conalyz
   ```
3. Move to a directory in your PATH:
   ```bash
   # Create ~/bin if it doesn't exist
   mkdir -p ~/bin
   
   # Move the binary
   mv conalyz ~/bin/
   
   # Add to PATH (if not already added)
   echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```
4. Verify installation by running:
   ```bash
   conalyz --help
   ```

## ⚡ Quick Start

1. Navigate to your Flutter project:
   ```bash
   cd /path/to/your/flutter/project
   ```
2. Run the analyzer:
   ```bash
   conalyz -p ./lib
   ```
3. Open the HTML report:
   ```bash
   open accessibility_report/accessibility_report.html
   ```

## 🔍 Key Features

- **Lightning-fast** analysis using AST parsing
- **Interactive HTML reports** with filtering
- **JSON output** for CI/CD integration
- **Comprehensive checks** for both Material and Cupertino widgets
- **Detailed suggestions** for fixing issues

## 🛠 Usage Guide

### Basic Commands

```bash
# Analyze a Flutter project
conalyz -p /path/to/your/flutter/project/lib

# Specify custom output directory
conalyz -p ./lib -o ./reports

# Analyze specific files only
conalyz -f lib/main.dart lib/screens/home_screen.dart

# Set minimum severity level (critical, high, medium, low)
conalyz -p ./lib --min-severity high
```

### Command Line Options

| Option | Alias | Description |
|--------|-------|-------------|
| `--path` | `-p` | Path to Flutter project's lib directory |
| `--file` | `-f` | Analyze specific files (can specify multiple) |
| `--output` | `-o` | Output directory (default: `accessibility_report`) |
| `--format` | `-f` | Output format: `html`, `json`, or `all` |
| `--min-severity` | `-s` | Minimum severity level to report |
| `--exclude` | `-e` | Exclude files/directories (comma-separated) |
| `--help` | `-h` | Show help message |

### Common Examples

```bash
# Basic analysis with default settings
conalyz -p ./lib

# Generate JSON report for CI/CD
conalyz -p ./lib --format json

# Only check for critical/high issues
conalyz -p ./lib --min-severity high

# Exclude generated files
conalyz -p ./lib --exclude "**/*.g.dart,**/generated/**"
```

## 📊 Understanding the Reports

### HTML Report

After running the analysis, open `accessibility_report/accessibility_report.html` in your browser to view an interactive report that includes:

- **Summary Dashboard**: Quick overview of issues by severity
- **Filtering**: Narrow down issues by type and severity
- **Detailed Issue View**: 
  - Exact file locations with clickable links
  - Code snippets showing the issue
  - WCAG compliance information
  - Step-by-step fixes

### JSON Report

For programmatic use, check `accessibility_report/accessibility_report.json`:

```json
{
  "summary": {
    "total_issues": 8,
    "critical": 2,
    "high": 3,
    "medium": 2,
    "low": 1,
    "files_analyzed": 12,
    "analysis_time_seconds": 1.23
  },
  "issues": [
    {
      "type": "MissingSemanticsLabel",
      "severity": "high",
      "file": "lib/screens/home_screen.dart",
      "line": 42,
      "message": "Icon is missing a semantic label",
      "suggestion": "Add a semantic label for screen readers"
    }
  ]
}
```

## 🔧 Troubleshooting

### Common Issues

1. **Command not found**
   - Make sure the binary is in your PATH
   - Try using `./conalyz` if in the same directory

2. **Permission denied**
   ```bash
   chmod +x conalyz
   ```

3. **No issues found**
   - Verify you're analyzing the correct directory
   - Check file permissions
   - Run with `--verbose` for more details

## 📝 Feedback

This is a beta release. Please report any issues or suggestions to:
- Email: your-email@example.com
- GitHub: [Issues](https://github.com/yourusername/flutter-access-advisor/issues)

## 📜 License

© 2025 Flutter Accessibility Team. All rights reserved.

---

Thank you for helping us improve Flutter accessibility! 🎉


