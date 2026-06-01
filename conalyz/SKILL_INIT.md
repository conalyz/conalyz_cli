---
name: conalyz-init
description: Generate conalyz.yaml for the Conalyz runtime accessibility tool by reading the Flutter project's router config and screen files. Use this skill when the user asks to set up Conalyz, generate a conalyz.yaml, configure the runtime tool, or create a navigation config for Conalyz. Triggers on phrases like "generate conalyz.yaml", "set up conalyz", "init conalyz", "create conalyz config", or any mention of conalyz-init.
---

# conalyz-init — Generate conalyz.yaml

This skill reads the Flutter project's router configuration and screen files, reasons about the navigation graph, shows a preview for approval, and writes `conalyz.yaml` for the Conalyz runtime accessibility tool.

---

## What conalyz.yaml is

`conalyz.yaml` drives the Conalyz runtime tool in `--auto` mode. It describes which screens to analyse and the navigation steps required to reach each one. Each entry in the `flow:` list is a screen; each screen has a `steps:` list of inline actions:

| Step | What it does |
|------|--------------|
| `analyse` | Capture and analyse this screen |
| `analyse "Label"` | Same, but names the screen in the report |
| `tap "Label"` | Tap the widget with this accessible label |
| `type "value" into "Label"` | Type into the named text field |
| `back` | Navigate back |
| `swipe left` / `swipe right` | Swipe gesture |
| `wait_for "Label"` | Wait until a widget with this label appears |
| `wait_for "Label" timeout 10s` | Same with explicit timeout |
| `delay 2s` | Fixed pause |
| `scroll_to "Label"` | Scroll until the named widget is visible |

---

## Step 1: Discover the router

Read `pubspec.yaml` to understand the project name and dependencies, then locate the router config:

- **GoRouter** — search for `GoRouter(` or `go_router` in `lib/`. The routes list is usually in `lib/router/`, `lib/app_router.dart`, `lib/routes.dart`, or `lib/main.dart`.
- **MaterialApp routes** — look for `routes: {` in `MaterialApp(` or `MaterialApp.router(`.
- **Imperative Navigator** — look for `Navigator.pushNamed(` or `Navigator.push(` calls; map them by context.

Read the router file in full. Extract every named route or screen widget class referenced.

---

## Step 2: Extract labels from each screen

For each screen widget found, read the corresponding file. Extract interactive widget labels that will appear in the Semantics tree at runtime:

| Widget | Label source |
|--------|-------------|
| `ElevatedButton`, `TextButton`, `OutlinedButton` | `child: Text('...')` |
| `IconButton` | `tooltip: '...'` |
| `TextField`, `TextFormField` | `decoration: InputDecoration(labelText: '...')` or `hintText` |
| `AppBar` | `title: Text('...')` |
| `BottomNavigationBar` item | `label: '...'` |
| `NavigationRail` destination | `label: Text('...')` |
| `FloatingActionButton` | `tooltip: '...'` |
| `Semantics` wrapper | `label: '...'` |
| `ListTile` | `title: Text('...')` |

Flag with ⚠️ any label that:
- Comes from a variable (`Text(buttonLabel)`) rather than a string literal
- Is inside a conditional or builder function
- Belongs to a custom widget whose internals weren't read

---

## Step 3: Reason about the navigation graph

Map which tap/action on each screen leads to which screen next. Build a depth-first traversal from the initial route (usually `/` or `home`). Each screen is visited once; back-navigation returns to the previous screen.

For tab bars and bottom navigation: treat each tab as a sub-screen reached via `tap "Tab Label"` from the parent screen, then `back` to return.

For auth-gated flows: start at the login/splash screen.

---

## Step 4: Show the flow preview

**Do not write any files yet.** Present the proposed flow for approval:

```
Proposed navigation flow for conalyz.yaml:

  1. Login                        [initial route]
     → analyse "Login"
     → type "test@example.com" into "Email"    ⚠️ verify label
     → type "password123" into "Password"       ⚠️ verify label
     → tap "Sign In"

  2. Home                         [from Login → tap "Sign In"]
     → analyse "Home"
     → tap "Settings"

  3. Settings                     [from Home → tap "Settings"]
     → analyse "Settings"
     → back

⚠️  Labels marked ⚠️ are uncertain — verify these match what Conalyz
    reports on first run. All others are high-confidence matches.

Approve this flow, or tell me what to change:
  • Skip a screen: "skip the About screen"
  • Rename: "rename screen 2 to Dashboard"
  • Fix credentials: "use admin@test.com and secret123"
  • Add a screen: "add a Profile screen after Settings"
  • Reorder: "move Home before Login"
```

Wait for the user to approve or give adjustments. Update the preview conversationally before writing.

---

## Step 5: Write conalyz.yaml

Only after explicit user approval, write `conalyz.yaml` in the project root. Use placeholder credentials with inline comments where test values are unknown:

```yaml
flow:
  - screen: Login
    steps:
      - analyse "Login"
      - type "test@example.com" into "Email"   # replace with your test credentials
      - type "password123" into "Password"      # replace with your test credentials
      - tap "Sign In"

  - screen: Home
    steps:
      - analyse "Home"
      - tap "Settings"

  - screen: Settings
    steps:
      - analyse "Settings"
      - back
```

---

## Accuracy and limitations

**~80% label match on first run.** The main sources of mismatch:

- `Semantics(label:)` overrides that differ from the visible text
- Merged nodes (`MergeSemantics`) that combine child labels
- Multi-line labels normalised with `│` in the Semantics tree
- Labels from variables, computed strings, or l10n keys

**What the runtime tool reports on mismatch:** `label not found: "Sign In"` — fix by replacing the label in `conalyz.yaml` with the exact string shown in the report, then re-run.

**Cannot determine:** test credentials (always placeholder), screens reachable only via deep link, dynamic navigation based on server state.

**Works best with:** GoRouter named routes. Less reliable with fully imperative `Navigator.push` patterns where screen classes aren't referenced from a central router.

---

## After writing conalyz.yaml

Tell the user how to run the runtime tool:

```bash
# From the Flutter project root:
dart run bin/conalyz.dart auto --dir .
# or, if the Homebrew binary is installed:
conalyz auto --dir .
```

Remind them that any `label not found` errors on first run should be fixed by updating the label string in `conalyz.yaml` to match what the tool reports.
