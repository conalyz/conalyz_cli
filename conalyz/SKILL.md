---
name: conalyz
description: Analyze Flutter and Dart projects for accessibility issues using conalyz. Use this skill when the user asks to check accessibility, audit widgets, find WCAG issues, or improve accessibility in their Flutter app. Triggers on phrases like "check accessibility", "audit my Flutter app", "find accessibility issues", "WCAG compliance", or any mention of conalyz.
---

# Conalyz — Flutter Accessibility Analyzer

## Overview

Conalyz is an AST-based CLI tool that scans Flutter/Dart code for accessibility issues and generates detailed JSON + HTML reports. This skill runs conalyz, interprets results, prioritizes fixes, and generates corrected Dart code.

---

## Step 1: Verify conalyz is installed

Before running analysis, confirm conalyz is available:

```bash
conalyz --version
```

If not installed, tell the user to run:

```bash
dart pub global activate conalyz
# Then add to PATH if needed:
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

---

## Step 2: Determine the target path

Ask the user for the path if not already provided. Common defaults:
- `./lib` — entire project
- `./lib/screens` — just screens
- `lib/main.dart` — single file

Also check if they want a specific platform:
- `--platform mobile` (default)
- `--platform web`

---

## Step 3: Run conalyz with JSON output

Always run with `--json` so results are machine-readable:

```bash
conalyz --path <PATH> --platform <PLATFORM> --output ./conalyz_report --json
```

Then read the JSON report:

```bash
cat ./conalyz_report/accessibility_report.json
```

---

## Step 4: Parse and prioritize issues

The JSON report contains:
- `summary` — total issues, severity breakdown, files analyzed
- `issues[]` — list of issues, each with:
  - `severity` — `critical`, `high`, `medium`, `low`
  - `type` — e.g. `missing_semantic_label`, `insufficient_contrast`, `missing_tooltip`
  - `file` — file path
  - `line` — line number
  - `widget` — widget name
  - `message` — description
  - `suggestion` — recommended fix

**Prioritization order:**
1. `critical` — blocks screen reader users entirely
2. `high` — significantly degrades accessibility
3. `medium` — WCAG AA violations
4. `low` — best practice improvements

---

## Step 5: Present results to the user

Give a clear summary first:

```
Found X accessibility issues across Y files:
- Z critical  (must fix)
- Z high      (should fix)
- Z medium    (recommended)
- Z low       (optional)
```

Then group issues by file so the user sees the full picture per file rather than a scattered list.

---

## Step 6: Generate fixes

For each critical and high issue, read the affected file and generate corrected Dart code.

### Common fix patterns:

**Missing semantic label on IconButton:**
```dart
// Before
IconButton(icon: Icon(Icons.search), onPressed: _search)

// After
IconButton(
  icon: Icon(Icons.search),
  tooltip: 'Search',
  onPressed: _search,
)
```

**Missing Semantics on GestureDetector:**
```dart
// Before
GestureDetector(onTap: _handleTap, child: Container(...))

// After
Semantics(
  label: 'Describe the action',
  button: true,
  child: GestureDetector(onTap: _handleTap, child: Container(...)),
)
```

**Missing label on Image:**
```dart
// Before
Image.asset('assets/banner.png')

// After
Image.asset(
  'assets/banner.png',
  semanticLabel: 'Description of what the image shows',
)
```

**Missing label on TextField:**
```dart
// Before
TextField(hintText: 'Enter email')

// After
TextField(
  decoration: InputDecoration(
    hintText: 'Enter email',
    labelText: 'Email address',
  ),
)
```

---

## Step 7: Apply fixes (with user confirmation)

Before editing files, always show the user the planned changes and ask for confirmation. Then apply fixes using str_replace on the actual files.

After applying, re-run conalyz to verify the issue count dropped:

```bash
conalyz --path <PATH> --json --output ./conalyz_report_after
```

---

## Tips

- For large projects, tackle one file at a time
- Always re-run after fixes to catch any regressions
- For `insufficient_contrast` issues, suggest specific color values that meet WCAG AA (4.5:1 ratio for normal text, 3:1 for large text)
- For custom widgets, wrap with `Semantics()` rather than modifying internal widget code
- Suggest the user open `./conalyz_report/accessibility_report.html` for the full interactive report