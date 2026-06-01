import 'dart:convert';
import 'dart:io';

import 'optimized_ast_analyzer.dart';

class AstReportGenerator {
  Future<void> generateJsonReport(
      AnalysisResult result, String outputPath) async {
    final json = _generateJsonContent(result);
    await File(outputPath)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }

  Future<void> generateHtmlReport(
      AnalysisResult result, String outputPath) async {
    final htmlContent = _generateHtmlContent(result);
    await File(outputPath).writeAsString(htmlContent);
  }

  // ── JSON ───────────────────────────────────────────────────────────────────

  Map<String, dynamic> _generateJsonContent(AnalysisResult result) {
    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'analysisTool': 'static',
      'device': null,
      'summary': {
        'filesAnalysed': result.analyzedFiles.length,
        'linesScanned': result.linesScanned,
        'totalViolations': result.totalIssues,
        'bySeverity': {
          'critical': result.issuesBySeverity['critical'] ?? 0,
          'high': result.issuesBySeverity['high'] ?? 0,
          'medium': result.issuesBySeverity['medium'] ?? 0,
          'low': result.issuesBySeverity['low'] ?? 0,
        },
      },
      'violations': result.issues.map(_violationJson).toList(),
    };
  }

  Map<String, dynamic> _violationJson(AccessibilityIssue issue) => {
        'severity': issue.severity,
        'type': issue.type,
        'message': issue.message,
        'file': issue.file,
        'line': issue.line,
        'column': issue.column,
        'rule': issue.rule,
        'suggestion': issue.suggestion,
      };

  // ── HTML ───────────────────────────────────────────────────────────────────

  String _generateHtmlContent(AnalysisResult result) {
    final criticalIssues =
        result.issues.where((i) => i.severity == 'critical').toList();
    final highIssues =
        result.issues.where((i) => i.severity == 'high').toList();
    final mediumIssues =
        result.issues.where((i) => i.severity == 'medium').toList();
    final lowIssues = result.issues.where((i) => i.severity == 'low').toList();

    final totalAll = result.totalIssues;
    final totalCritical = criticalIssues.length;
    final uiuxWarnings = totalAll - totalCritical;

    final score = _healthScore(result);
    final scoreCls = score >= 80
        ? 'good'
        : score >= 60
            ? 'warn'
            : 'bad';

    final now = DateTime.now();
    final date =
        '${now.year}-${_pad(now.month)}-${_pad(now.day)} ${_pad(now.hour)}:${_pad(now.minute)}';

    // Group issues by file for per-file articles.
    final byFile = <String, List<AccessibilityIssue>>{};
    for (final issue in result.issues) {
      (byFile[issue.file] ??= []).add(issue);
    }

    final fileArticles = <String>[];
    var idx = 0;
    for (final entry in byFile.entries) {
      fileArticles.add(_generateFileSection(entry.key, entry.value, idx++));
    }

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Conalyz Accessibility Report</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@500&display=swap" rel="stylesheet">
  <style>${_css()}</style>
</head>
<body>
  <header>
    <div class="header-inner">
      <div class="header-brand">
        <svg class="brand-logo" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1080" aria-label="Conalyz logo">
          <g transform="matrix(2.71 0 0 2.71 541.48 572.05)"><path fill="#82C88F" transform="translate(-114.41,-130.06)" d="M63.14 170.76C88.38 215.27 145.74 218.71 183.17 187.15C186.09 184.69 190.16 178.25 193.98 179.32L228.52 211.9C229.12 213.94 228.77 214.99 227.75 216.74C226.57 218.75 216.73 227.03 214.17 229.15C152.3 280.54 61.36 266.49 19.28 198.1C-32.37 114.14 25.65 5.9 123.21.18C153.76-1.61 186.41 9.78 210.6 28.77C214.14 31.55 226.81 41.79 226.81 45.67C226.81 49.83 220.82 52.55 218.18 55.14C209.62 63.53 201.48 72.91 192.17 80.2C187.7 80.67 181.68 72.04 178.18 69.2C111.33 15.02 20.06 94.79 63.14 170.76Z"/></g>
          <g transform="matrix(2.71 0 0 2.71 583.86 571.76)"><path fill="#141414" transform="translate(-130.13,-130.04)" d="M184.72 130.04C184.72 160.19 160.28 184.63 130.13 184.63C99.98 184.63 75.54 160.19 75.54 130.04C75.54 99.89 99.98 75.45 130.13 75.45C160.28 75.45 184.72 99.89 184.72 130.04ZM144.28 138.76C151.69 131.04 158.57 122.71 165.94 114.93C168.91 109.37 164.06 103.59 158.29 104.19C152.52 104.79 133.34 128.99 131.21 129.01C124.81 125.98 118.6 114.64 111.95 113.38C103.03 111.68 96.44 123.49 101.25 131.15C103.22 134.29 121.61 151.86 124.68 152.78C131.38 154.79 139.96 143.29 144.29 138.78Z"/></g>
          <g transform="matrix(2.71 0 0 2.71 592.04 566.9)"><path fill="#F7F8F8" transform="translate(-133.22,-128.56)" d="M144.28 138.76C139.95 143.27 131.37 154.77 124.67 152.76C121.6 151.84 103.21 134.28 101.24 131.13C96.43 123.47 103.02 111.67 111.94 113.36C118.59 114.63 124.81 125.96 131.2 128.99C133.33 128.98 152.57 104.76 158.28 104.17C163.99 103.58 168.9 109.36 165.93 114.91C158.56 122.69 151.69 131.02 144.27 138.74Z"/></g>
        </svg>
        <div>
          <h1>Conalyz <span class="header-sep">|</span> Accessibility Report</h1>
          <p class="meta">Generated $date &nbsp;·&nbsp; ${result.analyzedFiles.length} file${result.analyzedFiles.length == 1 ? '' : 's'} analysed &nbsp;·&nbsp; Static</p>
        </div>
      </div>
      <div class="header-right">
        <div class="hs hs-$scoreCls">
          <span class="hs-label">Health Score</span>
          <span class="hs-value">$score</span>
        </div>
        <button id="sev-guide-btn" aria-haspopup="dialog">Severity Guide</button>
      </div>
    </div>
  </header>

  <section class="summary">
    ${_statCard(totalAll.toString(), 'Total Issues', totalAll > 0 ? 'bad' : 'good')}
    ${_statCard(totalCritical.toString(), 'Critical Issues', totalCritical > 0 ? 'bad' : 'good')}
    ${_statCard(uiuxWarnings.toString(), 'Other Issues', uiuxWarnings > 0 ? 'warn' : 'good')}
  </section>

  <div class="filters">
    <div class="filter-group">
      <span class="filter-label">Severity:</span>
      <label><input type="checkbox" class="filter-sev" data-severity="critical" checked><span>Critical (${criticalIssues.length})</span></label>
      <label><input type="checkbox" class="filter-sev" data-severity="high" checked><span>High (${highIssues.length})</span></label>
      <label><input type="checkbox" class="filter-sev" data-severity="medium" checked><span>Medium (${mediumIssues.length})</span></label>
      <label><input type="checkbox" class="filter-sev" data-severity="low" checked><span>Low (${lowIssues.length})</span></label>
    </div>
    <div class="filter-group">
      <span class="filter-label">Type:</span>
      <div class="dropdown">
        <div class="dropdown-btn" id="typeFilterBtn" tabindex="0" role="button" aria-haspopup="listbox">
          <span class="selected-items">All Types</span>
          <span class="dropdown-arrow">▾</span>
        </div>
        <div class="dropdown-content" id="typeFilterDropdown" role="listbox">
          <div class="dropdown-item">
            <input type="checkbox" id="selectAllTypes" checked>
            <label for="selectAllTypes">All Types</label>
          </div>
          ${_generateTypeFilters(result.issues)}
        </div>
      </div>
    </div>
  </div>

  <main>
    ${fileArticles.isEmpty ? '<p class="all-pass-global">✓ No accessibility issues found</p>' : fileArticles.join('\n')}
  </main>

  <footer class="methodology">
    <h3>Methodology notes</h3>
    <ul>
      <li><strong>Static AST analysis:</strong> Issues are detected from source code without running the app. Runtime measurements such as touch target sizes and actual contrast ratios are not available in static mode.</li>
      <li><strong>Severity levels:</strong> Critical blocks screen-reader users entirely (WCAG Level A, no workaround). High significantly degrades experience. Medium fails WCAG AA. Low is a best-practice improvement.</li>
    </ul>
  </footer>

  <div id="sev-modal" role="dialog" aria-modal="true" aria-label="Severity guide">
    <div id="sev-modal-inner">
      <button id="sev-modal-close" aria-label="Close">✕</button>
      <h2>Severity guide</h2>
      <p class="sev-modal-intro">Each violation is assigned one of four levels based on user impact and WCAG conformance.</p>
      <div class="sev-legend">
        <div class="sev-legend-row"><span class="sev sev-critical">critical</span><span>Element completely unreachable or unreadable. WCAG Level A failure with no workaround — must fix before release.</span></div>
        <div class="sev-legend-row"><span class="sev sev-high">high</span><span>Significant barrier. Level A failure where some fallback may exist, or severely degraded experience for assistive-technology users.</span></div>
        <div class="sev-legend-row"><span class="sev sev-medium">medium</span><span>Degrades comprehension. Level AA failure — users can still complete the task with effort.</span></div>
        <div class="sev-legend-row"><span class="sev sev-low">low</span><span>Minor improvement. Best-practice recommendation; low user impact.</span></div>
      </div>
      <h3>Per-check breakdown</h3>
      <table class="sev-table">
        <thead><tr><th>Check</th><th>Severity</th><th>Condition</th></tr></thead>
        <tbody>
          <tr><td>Missing semantic label</td><td><span class="sev sev-critical">critical</span></td><td>Button, link, or image with no accessible label</td></tr>
          <tr><td>Missing semantic label</td><td><span class="sev sev-high">high</span></td><td>Text field or checkbox with no label</td></tr>
          <tr><td>Missing tooltip</td><td><span class="sev sev-high">high</span></td><td>IconButton with no tooltip — purpose undiscoverable</td></tr>
          <tr><td>Keyboard inaccessible</td><td><span class="sev sev-critical">critical</span></td><td>GestureDetector with no Semantics — WCAG SC 2.1.1</td></tr>
          <tr><td>Vague label</td><td><span class="sev sev-medium">medium</span></td><td>"tap here", "read more" etc. — purpose unclear out of context</td></tr>
          <tr><td>Contrast (static)</td><td><span class="sev sev-medium">medium</span></td><td>Known-failing hardcoded colour pair — WCAG SC 1.4.3</td></tr>
          <tr><td>Low priority</td><td><span class="sev sev-low">low</span></td><td>Best-practice suggestion; no WCAG failure</td></tr>
        </tbody>
      </table>
    </div>
  </div>

  <script>${_js()}</script>
</body>
</html>''';
  }

  // ── Stat card ───────────────────────────────────────────────────────────────

  String _statCard(String value, String label, String cls) => '''
    <div class="stat-card $cls">
      <span class="stat-label">$label</span>
      <span class="stat-value">$value</span>
    </div>''';

  // ── Per-file section ────────────────────────────────────────────────────────

  String _generateFileSection(
      String filePath, List<AccessibilityIssue> issues, int idx) {
    final total = issues.length;
    final cls = total == 0 ? 'pass' : 'fail';
    final badge =
        total == 0 ? 'Passed' : '$total Issue${total == 1 ? '' : 's'}';

    final bySeverity = <String, List<AccessibilityIssue>>{
      'critical': [],
      'high': [],
      'medium': [],
      'low': [],
    };
    for (final issue in issues) {
      (bySeverity[issue.severity] ??= []).add(issue);
    }

    final groups = <String>[];
    for (final sev in ['critical', 'high', 'medium', 'low']) {
      final vs = bySeverity[sev]!;
      if (vs.isEmpty) continue;
      final cards = vs.map(_generateVCard).join('\n');
      groups.add(_vGroup(_sevTitle(sev), vs.length, cards));
    }

    final shortName =
        filePath.contains('/') ? filePath.split('/').last : filePath;

    return '''
<article id="file-$idx" class="screen $cls">
  <div class="screen-header">
    <h2 title="${_esc(filePath)}">${_esc(shortName)}</h2>
    <code class="file-path">${_esc(filePath)}</code>
    <span class="badge $cls">$badge</span>
  </div>
  <div class="screen-body">
    <div class="issue-feed">
      <div class="issue-feed-header">
        <p class="panel-title">Issue Details</p>
        ${total > 0 ? '<button class="expand-all-btn">Expand All</button>' : ''}
      </div>
      ${groups.join('\n')}
      ${total == 0 ? '<p class="all-pass">✓ All checks passed</p>' : ''}
    </div>
  </div>
</article>''';
  }

  // ── Violation card ──────────────────────────────────────────────────────────

  String _generateVCard(AccessibilityIssue issue) {
    final title = _typeToTitle(issue.type);
    final ref =
        '${_esc(issue.file)}:${issue.line}:${issue.column}';
    final noteHtml = '<p class="v-note">${_esc(issue.message)}</p>';
    final suggHtml = issue.suggestion.isNotEmpty
        ? '<div class="v-suggestion"><strong>Fix:</strong> ${_esc(issue.suggestion)}</div>'
        : '';
    return '''<div class="v-card vb-${issue.severity}" data-severity="${issue.severity}" data-type="${_esc(_typeToTitle(issue.type))}">
  <div class="v-card-head">
    <span class="sev sev-${issue.severity}">${issue.severity}</span>
    <div class="v-card-info">
      <span class="v-title">${_esc(title)}</span>
      <code class="v-ref">$ref</code>
    </div>
    <button class="v-toggle" aria-expanded="false" aria-label="Toggle details">▾</button>
  </div>
  <div class="v-body">$noteHtml$suggHtml</div>
</div>''';
  }

  String _vGroup(String title, int count, String cards) => '''
<div class="vgroup">
  <p class="vgroup-title">$title <span class="count">$count</span></p>
  $cards
</div>''';

  // ── Type filter dropdown items ───────────────────────────────────────────────

  String _generateTypeFilters(List<AccessibilityIssue> allIssues) {
    final typeCounts = <String, int>{};
    for (final issue in allIssues) {
      final title = _typeToTitle(issue.type);
      typeCounts[title] = (typeCounts[title] ?? 0) + 1;
    }
    final sorted = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((entry) {
      final safe = _esc(entry.key);
      final cssId = _toCssId(safe);
      return '''<div class="dropdown-item">
          <input type="checkbox" id="type_$cssId" value="$safe" checked>
          <label for="type_$cssId">${entry.key}</label>
          <span class="count">${entry.value}</span>
        </div>''';
    }).join('\n');
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _sevTitle(String sev) {
    switch (sev) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      default:
        return 'Low';
    }
  }

  String _typeToTitle(String type) => type
      .split('_')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  String _toCssId(String text) =>
      text.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  int _healthScore(AnalysisResult result) {
    if (result.analyzedFiles.isEmpty) return 100;
    final critical = result.issuesBySeverity['critical'] ?? 0;
    final high = result.issuesBySeverity['high'] ?? 0;
    final medium = result.issuesBySeverity['medium'] ?? 0;
    final low = result.issuesBySeverity['low'] ?? 0;
    final penalty = critical * 15 + high * 8 + medium * 3 + low * 1;
    return (100 - penalty).clamp(0, 100);
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String _pad(int n) => n.toString().padLeft(2, '0');

  // ── CSS ─────────────────────────────────────────────────────────────────────

  String _css() => '''
    *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
    body{font-family:'Inter',system-ui,sans-serif;background:#F8FAFC;color:#0b1c30;font-size:14px;-webkit-font-smoothing:antialiased}
    /* ── Header ── */
    header{background:#fff;border-bottom:1px solid #E2E8F0;padding:16px 32px}
    .header-inner{display:flex;align-items:center;justify-content:space-between;gap:16px}
    .header-brand{display:flex;align-items:center;gap:12px}
    .brand-logo{width:44px;height:44px;flex-shrink:0;display:block}
    h1{font-size:15px;font-weight:600;color:#0b1c30;letter-spacing:-0.01em}
    .header-sep{color:#CBD5E1;margin:0 6px;font-weight:400}
    .meta{margin-top:2px;color:#64748B;font-size:12px}
    .header-right{display:flex;align-items:center;gap:12px;flex-shrink:0}
    /* ── Health score ── */
    .hs{display:flex;align-items:center;gap:10px;background:#F8FAFC;border:1px solid #E2E8F0;border-radius:8px;padding:8px 16px}
    .hs-label{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.05em;color:#64748B}
    .hs-value{font-size:22px;font-weight:700;font-family:'JetBrains Mono','Courier New',monospace;letter-spacing:-0.02em}
    .hs.hs-good .hs-value{color:#16A34A}.hs.hs-warn .hs-value{color:#D97706}.hs.hs-bad .hs-value{color:#DC2626}
    /* ── Severity guide button ── */
    #sev-guide-btn{background:#00FF88;border:none;border-radius:4px;padding:8px 16px;font-size:12px;font-weight:600;color:#0A0A0A;cursor:pointer;white-space:nowrap;font-family:'Inter',sans-serif;transition:background .15s}
    #sev-guide-btn:hover{background:#00e479}
    /* ── Summary stat strip ── */
    .summary{display:flex;gap:1px;background:#E2E8F0;border-top:1px solid #E2E8F0;border-bottom:1px solid #E2E8F0}
    .stat-card{flex:1;background:#fff;padding:20px 24px;display:flex;flex-direction:column;gap:4px;min-width:120px}
    .stat-label{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.05em;color:#64748B}
    .stat-value{font-size:32px;font-weight:700;font-family:'JetBrains Mono','Courier New',monospace;letter-spacing:-0.02em;line-height:1}
    .stat-card.bad .stat-value{color:#EF4444}
    .stat-card.warn .stat-value{color:#D97706}
    .stat-card.good .stat-value{color:#16A34A}
    /* ── Filter bar ── */
    .filters{display:flex;flex-wrap:wrap;gap:20px;align-items:center;padding:14px 32px;background:#fff;border-bottom:1px solid #E2E8F0}
    .filter-group{display:flex;align-items:center;gap:10px;flex-wrap:wrap}
    .filter-label{font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.05em;color:#64748B;white-space:nowrap}
    .filter-group label{display:flex;align-items:center;gap:6px;padding:5px 12px;background:#F8FAFC;border:1px solid #E2E8F0;border-radius:4px;cursor:pointer;font-size:12px;font-weight:500;color:#475569;transition:background .15s}
    .filter-group label:hover{background:#F1F5F9}
    .filter-group input[type="checkbox"]{cursor:pointer;accent-color:#0b1c30;width:13px;height:13px}
    /* ── Type dropdown ── */
    .dropdown{position:relative;display:inline-block}
    .dropdown-btn{display:flex;align-items:center;gap:8px;padding:5px 12px;background:#F8FAFC;border:1px solid #E2E8F0;border-radius:4px;cursor:pointer;font-size:12px;font-weight:500;color:#475569;min-width:160px;user-select:none}
    .dropdown-btn:hover{background:#F1F5F9}
    .dropdown-arrow{font-size:10px;color:#94A3B8;transition:transform .2s;flex-shrink:0}
    .dropdown-btn.open .dropdown-arrow{transform:rotate(180deg)}
    .selected-items{flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .dropdown-content{display:none;position:absolute;top:calc(100% + 4px);left:0;min-width:100%;background:#fff;border:1px solid #E2E8F0;border-radius:6px;box-shadow:0 4px 16px rgba(0,0,0,0.08);z-index:200;max-height:280px;overflow-y:auto}
    .dropdown-content.open{display:block}
    .dropdown-item{display:flex;align-items:center;gap:10px;padding:8px 14px;cursor:pointer;border-bottom:1px solid #F8FAFC;font-size:12px}
    .dropdown-item:last-child{border-bottom:none}
    .dropdown-item:hover{background:#F8FAFC}
    .dropdown-item input[type="checkbox"]{cursor:pointer;accent-color:#0b1c30;width:13px;height:13px;flex-shrink:0}
    .dropdown-item label{flex:1;cursor:pointer;color:#475569;font-weight:500}
    .dropdown-item .count{margin-left:auto;background:#F1F5F9;border-radius:4px;padding:1px 7px;font-size:11px;color:#475569;font-family:'JetBrains Mono','Courier New',monospace;flex-shrink:0}
    /* ── File/screen sections ── */
    main{padding:24px 32px;display:flex;flex-direction:column;gap:16px}
    .screen{background:#fff;border-radius:8px;border:1px solid #E2E8F0;overflow:hidden}
    .screen.fail{border-top:3px solid #EF4444}.screen.pass{border-top:3px solid #22C55E}
    .screen-header{display:flex;align-items:center;gap:10px;padding:14px 20px;border-bottom:1px solid #F1F5F9;flex-wrap:wrap}
    .screen-header h2{font-size:14px;font-weight:600;color:#0b1c30;letter-spacing:-0.01em}
    .file-path{font-size:11px;color:#94A3B8;font-family:'JetBrains Mono','Courier New',monospace;flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .badge{font-size:10px;font-weight:700;padding:3px 10px;border-radius:4px;text-transform:uppercase;letter-spacing:.05em}
    .badge.fail{background:#FEF2F2;color:#DC2626}.badge.pass{background:#F0FDF4;color:#16A34A}
    .screen-body{display:flex;flex-wrap:wrap}
    /* ── Issue feed ── */
    .issue-feed{flex:1;min-width:280px;padding:16px 20px;display:flex;flex-direction:column;gap:12px}
    .issue-feed-header{display:flex;align-items:center;justify-content:space-between}
    .panel-title{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.05em;color:#64748B}
    .expand-all-btn{background:none;border:1px solid #E2E8F0;border-radius:4px;padding:3px 10px;font-size:11px;font-weight:600;color:#475569;cursor:pointer;font-family:'Inter',sans-serif}
    .expand-all-btn:hover{background:#F1F5F9}
    .vgroup{display:flex;flex-direction:column;gap:6px}
    .vgroup-title{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.05em;color:#64748B;display:flex;align-items:center;gap:6px;margin-bottom:2px}
    .count{background:#F1F5F9;border-radius:4px;padding:1px 7px;font-size:11px;color:#475569;font-family:'JetBrains Mono','Courier New',monospace}
    /* ── Violation cards ── */
    .v-card{border:1px solid #E2E8F0;border-radius:6px;overflow:hidden;cursor:pointer}
    .v-card:hover{border-color:#CBD5E1}
    .vb-critical{border-left:3px solid #EF4444}
    .vb-high{border-left:3px solid #F59E0B}
    .vb-medium{border-left:3px solid #00668a}
    .vb-low{border-left:3px solid #22C55E}
    .v-card-head{display:flex;align-items:center;gap:10px;padding:10px 14px;background:#fff}
    .v-card:hover .v-card-head{background:#FAFAFA}
    .v-card-info{flex:1;display:flex;flex-direction:column;gap:2px;min-width:0}
    .v-title{font-size:13px;font-weight:600;color:#0b1c30;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .v-ref{font-size:11px;color:#64748B;font-family:'JetBrains Mono','Courier New',monospace;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;display:block}
    .v-toggle{background:none;border:none;cursor:pointer;color:#94A3B8;font-size:14px;padding:2px 4px;flex-shrink:0;transition:transform .2s;line-height:1}
    .v-toggle[aria-expanded="true"]{transform:rotate(180deg)}
    .v-body{display:none;padding:12px 14px;border-top:1px solid #F1F5F9;background:#FAFAFA;flex-direction:column;gap:10px}
    .v-body.open{display:flex}
    .v-note{font-size:12px;color:#64748B;line-height:1.6}
    .v-suggestion{font-size:12px;color:#475569;line-height:1.6;background:#F0FDF4;border:1px solid #BBF7D0;border-radius:6px;padding:10px 12px}
    .v-suggestion strong{color:#15803D;font-weight:600;margin-right:4px}
    .all-pass{font-size:13px;font-weight:600;color:#16A34A;padding:8px 0}
    .all-pass-global{font-size:14px;font-weight:600;color:#16A34A;padding:32px 32px}
    /* ── Severity badges ── */
    .sev{display:inline-block;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;padding:2px 8px;border-radius:4px;white-space:nowrap;vertical-align:middle;font-family:'Inter',sans-serif;flex-shrink:0}
    .sev-critical{background:#EF4444;color:#fff}
    .sev-high{background:#F59E0B;color:#fff}
    .sev-medium{background:#00668a;color:#fff}
    .sev-low{background:#22C55E;color:#fff}
    /* ── Methodology footer ── */
    .methodology{background:#fff;border-top:1px solid #E2E8F0;padding:24px 32px}
    .methodology h3{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.05em;color:#64748B;margin-bottom:10px}
    .methodology ul{list-style:disc;padding-left:18px;display:flex;flex-direction:column;gap:6px}
    .methodology li{color:#475569;font-size:12px;line-height:1.6}
    /* ── Severity guide modal ── */
    #sev-modal{display:none;position:fixed;inset:0;background:rgba(11,28,48,0.6);z-index:1000;align-items:center;justify-content:center;padding:16px}
    #sev-modal.open{display:flex}
    #sev-modal-inner{background:#fff;border-radius:8px;padding:28px;max-width:min(680px,94vw);max-height:90vh;overflow-y:auto;position:relative;display:flex;flex-direction:column;gap:20px;box-shadow:0 4px 24px rgba(0,0,0,0.12)}
    #sev-modal-inner h2{font-size:18px;font-weight:700;color:#0b1c30;padding-right:32px;letter-spacing:-0.02em}
    #sev-modal-inner h3{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.05em;color:#64748B}
    #sev-modal-close{position:absolute;top:16px;right:18px;background:none;border:none;font-size:18px;cursor:pointer;color:#64748B;line-height:1;padding:2px 6px;border-radius:4px}
    #sev-modal-close:hover{background:#F1F5F9}
    .sev-modal-intro{font-size:13px;color:#64748B;line-height:1.6}
    .sev-legend{display:flex;flex-direction:column;gap:12px}
    .sev-legend-row{display:flex;align-items:flex-start;gap:14px;font-size:13px;color:#475569;line-height:1.5}
    .sev-legend-row .sev{margin-top:2px}
    .sev-table{width:100%;border-collapse:collapse}
    .sev-table th{text-align:left;padding:8px 12px;background:#F1F5F9;font-size:10px;font-weight:600;color:#64748B;text-transform:uppercase;letter-spacing:.05em}
    .sev-table td{padding:7px 12px;border-bottom:1px solid #F1F5F9;font-size:12px;vertical-align:middle}
    .sev-table td:first-child{color:#0b1c30;font-weight:600;white-space:nowrap}
    .sev-table td:last-child{color:#64748B}
  ''';

  // ── JS ──────────────────────────────────────────────────────────────────────

  String _js() => r'''
(function () {
  // ── Card expand / collapse ──────────────────────────────────────────────
  function expandCard(card) {
    var body = card.querySelector('.v-body');
    var btn  = card.querySelector('.v-toggle');
    if (body) body.classList.add('open');
    if (btn)  btn.setAttribute('aria-expanded', 'true');
  }
  function collapseCard(card) {
    var body = card.querySelector('.v-body');
    var btn  = card.querySelector('.v-toggle');
    if (body) body.classList.remove('open');
    if (btn)  btn.setAttribute('aria-expanded', 'false');
  }
  function toggleCard(card) {
    var body = card.querySelector('.v-body');
    if (body && body.classList.contains('open')) collapseCard(card);
    else expandCard(card);
  }

  // ── Filter logic ────────────────────────────────────────────────────────
  function applyFilters() {
    var sevBoxes = document.querySelectorAll('.filter-sev');
    var activeSev = Array.from(sevBoxes)
      .filter(function (cb) { return cb.checked; })
      .map(function (cb) { return cb.dataset.severity; });

    var showAllTypes = document.getElementById('selectAllTypes').checked;
    var activeTypes = [];
    if (!showAllTypes) {
      document.querySelectorAll('#typeFilterDropdown input[type="checkbox"]')
        .forEach(function (cb) {
          if (cb !== document.getElementById('selectAllTypes') && cb.checked) {
            activeTypes.push(cb.value);
          }
        });
    }

    // Show/hide individual v-cards.
    document.querySelectorAll('.v-card').forEach(function (card) {
      var sev  = card.dataset.severity;
      var type = card.dataset.type;
      var sevOk  = activeSev.includes(sev);
      var typeOk = showAllTypes || activeTypes.includes(type);
      card.style.display = (sevOk && typeOk) ? '' : 'none';
    });

    // Hide vgroups whose every card is hidden; hide file articles with no visible cards.
    document.querySelectorAll('.screen').forEach(function (article) {
      var hasVisible = false;
      article.querySelectorAll('.vgroup').forEach(function (grp) {
        var grpVisible = Array.from(grp.querySelectorAll('.v-card'))
          .some(function (c) { return c.style.display !== 'none'; });
        grp.style.display = grpVisible ? '' : 'none';
        if (grpVisible) hasVisible = true;
      });
      // Only hide articles that originally had violations.
      if (article.classList.contains('fail')) {
        article.style.display = hasVisible ? '' : 'none';
      }
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    // ── Card expand / collapse wiring ──────────────────────────────────────
    document.querySelectorAll('.v-card').forEach(function (card) {
      card.addEventListener('click', function (e) { toggleCard(card); });
    });

    document.querySelectorAll('.expand-all-btn').forEach(function (btn) {
      var expanded = false;
      btn.addEventListener('click', function () {
        expanded = !expanded;
        var feed = btn.closest('.issue-feed');
        feed.querySelectorAll('.v-card').forEach(function (c) {
          expanded ? expandCard(c) : collapseCard(c);
        });
        btn.textContent = expanded ? 'Collapse All' : 'Expand All';
      });
    });

    // ── Severity checkboxes ────────────────────────────────────────────────
    document.querySelectorAll('.filter-sev').forEach(function (cb) {
      cb.addEventListener('change', applyFilters);
    });

    // ── Type dropdown ──────────────────────────────────────────────────────
    var dropBtn     = document.getElementById('typeFilterBtn');
    var dropContent = document.getElementById('typeFilterDropdown');
    var selectAll   = document.getElementById('selectAllTypes');

    function toggleDropdown() {
      var open = dropContent.classList.toggle('open');
      dropBtn.classList.toggle('open', open);
    }
    dropBtn.addEventListener('click', function (e) { e.stopPropagation(); toggleDropdown(); });
    dropBtn.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleDropdown(); }
    });
    document.addEventListener('click', function (e) {
      if (!dropBtn.contains(e.target) && !dropContent.contains(e.target)) {
        dropContent.classList.remove('open');
        dropBtn.classList.remove('open');
      }
    });
    dropContent.addEventListener('click', function (e) { e.stopPropagation(); });

    function updateSelectedLabel() {
      var typeBoxes = Array.from(
        dropContent.querySelectorAll('input[type="checkbox"]')
      ).filter(function (cb) { return cb !== selectAll; });
      var checked = typeBoxes.filter(function (cb) { return cb.checked; });
      var span = dropBtn.querySelector('.selected-items');
      if (checked.length === 0 || checked.length === typeBoxes.length) {
        span.textContent = 'All Types';
      } else if (checked.length === 1) {
        span.textContent = checked[0].value;
      } else {
        span.textContent = checked.length + ' types selected';
      }
    }

    selectAll.addEventListener('change', function () {
      dropContent.querySelectorAll('input[type="checkbox"]').forEach(function (cb) {
        if (cb !== selectAll) cb.checked = selectAll.checked;
      });
      updateSelectedLabel();
      applyFilters();
    });

    dropContent.querySelectorAll('input[type="checkbox"]').forEach(function (cb) {
      if (cb === selectAll) return;
      cb.addEventListener('change', function () {
        var typeBoxes = Array.from(
          dropContent.querySelectorAll('input[type="checkbox"]')
        ).filter(function (x) { return x !== selectAll; });
        var allChecked = typeBoxes.every(function (x) { return x.checked; });
        selectAll.checked = allChecked;
        updateSelectedLabel();
        applyFilters();
      });
    });

    // ── Severity guide modal ───────────────────────────────────────────────
    var sevModal = document.getElementById('sev-modal');
    var sevClose = document.getElementById('sev-modal-close');
    var sevBtn   = document.getElementById('sev-guide-btn');
    sevBtn.addEventListener('click', function () { sevModal.classList.add('open'); sevClose.focus(); });
    sevClose.addEventListener('click', function () { sevModal.classList.remove('open'); sevBtn.focus(); });
    sevModal.addEventListener('click', function (e) {
      if (e.target === sevModal) { sevModal.classList.remove('open'); sevBtn.focus(); }
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && sevModal.classList.contains('open')) {
        sevModal.classList.remove('open'); sevBtn.focus();
      }
    });
  });
}());
''';
}
