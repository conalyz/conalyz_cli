import 'dart:convert';
import 'dart:io';
import 'optimized_ast_analyzer.dart';

class AstReportGenerator {
  Future<void> generateJsonReport(AnalysisResult result, String outputPath) async {
    final jsonContent = const JsonEncoder.withIndent('  ').convert(result.toJson());
    await File(outputPath).writeAsString(jsonContent);
  }

  Future<void> generateHtmlReport(AnalysisResult result, String outputPath) async {
    final htmlContent = _generateHtmlContent(result);
    await File(outputPath).writeAsString(htmlContent);
  }

  String _generateHtmlContent(AnalysisResult result) {
    final criticalIssues = result.issues.where((i) => i.severity == 'critical').toList();
    final highIssues = result.issues.where((i) => i.severity == 'high').toList();
    final mediumIssues = result.issues.where((i) => i.severity == 'medium').toList();
    final lowIssues = result.issues.where((i) => i.severity == 'low').toList();

    final hasKotlin = result.analyzedFiles.any((f) => f.endsWith('.kt'));
    final hasDart = result.analyzedFiles.any((f) => f.endsWith('.dart'));
    
    final projectTitle = hasKotlin && hasDart 
        ? 'Flutter & Jetpack Compose' 
        : (hasKotlin ? 'Jetpack Compose' : 'Flutter');
        
    final analysisLabel = hasKotlin && hasDart 
        ? 'AST & Oregex-based Analysis' 
        : (hasKotlin ? 'Oregex-based Analysis' : 'AST-based Analysis');
        
    final badgeLabel = hasKotlin && hasDart 
        ? 'Hybrid-powered' 
        : (hasKotlin ? 'Oregex-powered' : 'AST-powered');
        
    final badgeEmoji = hasKotlin && hasDart 
        ? '🚀⚡' 
        : (hasKotlin ? '🚀' : '⚡');

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$projectTitle Accessibility Analysis Report</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary-gradient: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            --secondary-gradient: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            --accent-gradient: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            --success-gradient: linear-gradient(135deg, #81FBB8 0%, #28C76F 100%);
            --warning-gradient: linear-gradient(135deg, #FFD93D 0%, #FF8008 100%);
            --danger-gradient: linear-gradient(135deg, #FF512F 0%, #F09819 100%);
            --critical-gradient: linear-gradient(135deg, #FF416C 0%, #FF4B2B 100%);
            
            --bg-primary: #ffffff;
            --bg-secondary: #f8fafc;
            --bg-tertiary: #f1f5f9;
            --text-primary: #1e293b;
            --text-secondary: #64748b;
            --text-muted: #94a3b8;
            --border-light: #e2e8f0;
            --border-medium: #cbd5e1;
            
            --shadow-sm: 0 1px 3px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.06);
            --shadow-md: 0 4px 6px rgba(0,0,0,0.07), 0 2px 4px rgba(0,0,0,0.06);
            --shadow-lg: 0 10px 15px rgba(0,0,0,0.08), 0 4px 6px rgba(0,0,0,0.05);
            --shadow-xl: 0 20px 25px rgba(0,0,0,0.1), 0 10px 10px rgba(0,0,0,0.04);
            
            --radius-sm: 6px;
            --radius-md: 8px;
            --radius-lg: 12px;
            --radius-xl: 16px;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            color: var(--text-primary);
            line-height: 1.6;
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: var(--bg-primary);
            border-radius: var(--radius-xl);
            box-shadow: var(--shadow-xl);
            overflow: hidden;
            backdrop-filter: blur(20px);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }

        /* Header Styles */
        .header {
            background: var(--primary-gradient);
            color: white;
            padding: 40px;
            position: relative;
            overflow: hidden;
        }

        .header::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><pattern id="grain" width="100" height="100" patternUnits="userSpaceOnUse"><circle cx="50" cy="50" r="1" fill="white" opacity="0.1"/></pattern></defs><rect width="100" height="100" fill="url(%23grain)"/></svg>');
            opacity: 0.1;
        }

        .header-content {
            position: relative;
            z-index: 1;
        }

        .header h1 {
            font-size: 3rem;
            font-weight: 700;
            margin-bottom: 8px;
            letter-spacing: -0.02em;
            text-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        .header .subtitle {
            font-size: 1.1rem;
            opacity: 0.9;
            font-weight: 400;
            display: flex;
            align-items: center;
            gap: 12px;
            flex-wrap: wrap;
        }

        .badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            background: rgba(255, 255, 255, 0.2);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.3);
        }

        .badge.ast::before {
            content: '$badgeEmoji';
            font-size: 0.9rem;
        }

        /* Summary Section */
        .summary {
            padding: 40px;
            background: var(--bg-secondary);
            border-bottom: 1px solid var(--border-light);
        }

        .summary h2 {
            font-size: 2rem;
            font-weight: 600;
            margin-bottom: 8px;
            color: var(--text-primary);
        }

        .summary-info {
            color: var(--text-secondary);
            font-size: 1.1rem;
            margin-bottom: 30px;
        }

        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 20px;
        }

        .stat {
            background: var(--bg-primary);
            padding: 24px;
            border-radius: var(--radius-lg);
            text-align: center;
            box-shadow: var(--shadow-sm);
            border: 1px solid var(--border-light);
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }

        .stat:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-md);
        }

        .stat::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: var(--accent-gradient);
            transform: scaleX(0);
            transition: transform 0.3s ease;
        }

        .stat:hover::before {
            transform: scaleX(1);
        }

        .stat .number {
            font-size: 2.8rem;
            font-weight: 700;
            margin-bottom: 8px;
            line-height: 1;
        }

        .stat .label {
            color: var(--text-secondary);
            text-transform: uppercase;
            font-size: 0.85rem;
            font-weight: 600;
            letter-spacing: 1px;
        }

        .stat.critical .number { 
            background: var(--critical-gradient);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .stat.high .number { 
            background: var(--danger-gradient);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .stat.medium .number { 
            background: var(--warning-gradient);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .stat.low .number { 
            background: var(--success-gradient);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .stat.total .number { 
            background: var(--primary-gradient);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        /* Filters Section */
        .filters {
            padding: 24px 40px;
            background: var(--bg-tertiary);
            border-bottom: 1px solid var(--border-light);
            display: flex;
            flex-wrap: wrap;
            gap: 24px;
            align-items: center;
        }

        .filter-group {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .filter-label {
            font-weight: 600;
            color: var(--text-primary);
            font-size: 0.95rem;
        }

        .filter-group label {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 16px;
            background: var(--bg-primary);
            border-radius: var(--radius-md);
            cursor: pointer;
            transition: all 0.3s ease;
            border: 1px solid var(--border-light);
            font-size: 0.9rem;
            font-weight: 500;
        }

        .filter-group label:hover {
            background: var(--bg-secondary);
            box-shadow: var(--shadow-sm);
        }

        .filter-checkbox {
            width: 18px;
            height: 18px;
            cursor: pointer;
            accent-color: #667eea;
        }

        .filter-checkbox:checked + span {
            font-weight: 600;
        }

        /* Dropdown Styles */
        .dropdown {
            position: relative;
            display: inline-block;
            width: 280px;
        }

        .dropdown-btn {
            padding: 12px 16px;
            background: var(--bg-primary);
            border: 1px solid var(--border-medium);
            border-radius: var(--radius-md);
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 0.95rem;
            font-weight: 500;
            transition: all 0.3s ease;
            width: 100%;
            box-sizing: border-box;
        }

        .dropdown-btn:hover {
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }

        .dropdown-btn::after {
            content: '▼';
            font-size: 0.7rem;
            color: var(--text-muted);
            transition: transform 0.3s ease;
            flex-shrink: 0;
            margin-left: 8px;
        }

        .dropdown-btn.active::after {
            transform: rotate(180deg);
        }

        .dropdown-content {
            display: none;
            position: absolute;
            background: var(--bg-primary);
            width: 100%;
            max-height: 320px;
            overflow-y: auto;
            border: 1px solid var(--border-medium);
            border-radius: var(--radius-md);
            box-shadow: var(--shadow-lg);
            z-index: 1000;
            margin-top: 4px;
            box-sizing: border-box;
        }

        .dropdown-content.show {
            display: block;
        }

        .dropdown-item {
            padding: 12px 16px;
            cursor: pointer;
            border-bottom: 1px solid var(--border-light);
            display: flex;
            align-items: center;
            transition: background-color 0.2s ease;
        }

        .dropdown-item:last-child {
            border-bottom: none;
        }

        .dropdown-item:hover {
            background: var(--bg-secondary);
        }

        .dropdown-item input[type="checkbox"] {
            margin-right: 12px;
            width: 16px;
            height: 16px;
            accent-color: #667eea;
        }

        .dropdown-item label {
            flex-grow: 1;
            cursor: pointer;
            font-weight: 500;
        }

        .dropdown-item .count {
            margin-left: auto;
            color: var(--text-muted);
            font-size: 0.85rem;
            background: var(--bg-tertiary);
            padding: 2px 8px;
            border-radius: 12px;
            font-weight: 600;
        }

        .selected-items {
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            flex-grow: 1;
        }

        /* Issues Section */
        .issues {
            padding: 40px;
        }

        .severity-section {
            margin-bottom: 48px;
        }

        .severity-title {
            font-size: 1.8rem;
            font-weight: 600;
            margin-bottom: 24px;
            padding: 16px 0;
            border-bottom: 3px solid;
            display: flex;
            align-items: center;
            gap: 12px;
            position: relative;
        }

        .severity-title::before {
            font-size: 1.5rem;
        }

        .severity-title.critical { 
            background: var(--critical-gradient);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            border-color: #dc3545;
        }
        .severity-title.critical::before { content: '🔴'; }

        .severity-title.high { 
            background: var(--danger-gradient);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            border-color: #fd7e14;
        }
        .severity-title.high::before { content: '🟠'; }

        .severity-title.medium { 
            background: var(--warning-gradient);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            border-color: #ffc107;
        }
        .severity-title.medium::before { content: '🟡'; }

        .severity-title.low { 
            background: var(--success-gradient);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            border-color: #28a745;
        }
        .severity-title.low::before { content: '🟢'; }

        .issue {
            background: var(--bg-primary);
            border-left: 5px solid;
            padding: 24px;
            margin-bottom: 20px;
            border-radius: 0 var(--radius-lg) var(--radius-lg) 0;
            box-shadow: var(--shadow-sm);
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }

        .issue::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 5px;
            height: 100%;
            background: linear-gradient(to bottom, transparent, rgba(255,255,255,0.2), transparent);
            animation: shimmer 2s infinite;
        }

        @keyframes shimmer {
            0%, 100% { transform: translateY(-100%); }
            50% { transform: translateY(100%); }
        }

        .issue:hover {
            transform: translateX(4px);
            box-shadow: var(--shadow-md);
        }

        .issue.critical { border-color: #dc3545; }
        .issue.high { border-color: #fd7e14; }
        .issue.medium { border-color: #ffc107; }
        .issue.low { border-color: #28a745; }

        .issue-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 16px;
            flex-wrap: wrap;
            gap: 12px;
        }

        .issue-type {
            font-weight: 700;
            color: var(--text-primary);
            font-size: 1.1rem;
        }

        .issue-rule {
            background: var(--accent-gradient);
            color: white;
            padding: 4px 12px;
            border-radius: 16px;
            font-size: 0.8rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .issue-location {
            color: var(--text-muted);
            font-size: 0.9rem;
            margin-bottom: 12px;
            display: flex;
            align-items: center;
            gap: 8px;
            font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
        }

        .issue-location::before {
            content: '📁';
        }

        .issue-message {
            margin: 16px 0;
            line-height: 1.6;
            color: var(--text-secondary);
            font-size: 1rem;
        }

        .issue-suggestion {
            background: linear-gradient(135deg, #e8f4fd 0%, #f0f4ff 100%);
            border: 1px solid #c8e1ff;
            padding: 16px 16px 16px 48px;
            border-radius: var(--radius-md);
            margin-top: 16px;
            position: relative;
            color: var(--text-primary);
            line-height: 1.5;
        }

        .issue-suggestion::before {
            content: '💡';
            position: absolute;
            top: 16px;
            left: 16px;
            font-size: 1.2rem;
        }

        .issue-suggestion strong {
            color: #1e40af;
            font-weight: 600;
            display: inline-block;
            margin-bottom: 4px;
        }

        .issue-suggestion .suggestion-text {
            color: var(--text-primary);
            font-weight: 500;
        }

        .no-issues {
            text-align: center;
            color: var(--text-muted);
            font-style: italic;
            padding: 60px 20px;
            background: var(--bg-secondary);
            border-radius: var(--radius-lg);
            border: 2px dashed var(--border-medium);
        }

        .no-issues::before {
            content: '🎉';
            display: block;
            font-size: 3rem;
            margin-bottom: 16px;
        }

        /* Footer */
        .footer {
            padding: 32px 40px;
            background: var(--bg-tertiary);
            border-radius: 0 0 var(--radius-xl) var(--radius-xl);
            color: var(--text-muted);
            text-align: center;
            border-top: 1px solid var(--border-light);
        }

        .footer a {
            color: #667eea;
            text-decoration: none;
            font-weight: 600;
            transition: color 0.3s ease;
        }

        .footer a:hover {
            color: #764ba2;
        }

        /* Responsive Design */
        @media (max-width: 768px) {
            body { padding: 10px; }
            .header { padding: 24px; }
            .header h1 { font-size: 2rem; }
            .summary, .issues, .filters { padding: 24px; }
            .stats { grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 16px; }
            .filters { flex-direction: column; align-items: stretch; gap: 16px; }
            .filter-group { flex-wrap: wrap; }
            .dropdown { width: 240px; }
        }

        /* Dark mode support */
        @media (prefers-color-scheme: dark) {
            :root {
                --bg-primary: #1e293b;
                --bg-secondary: #334155;
                --bg-tertiary: #475569;
                --text-primary: #f1f5f9;
                --text-secondary: #cbd5e1;
                --text-muted: #94a3b8;
                --border-light: #475569;
                --border-medium: #64748b;
            }

            body {
                background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
            }

            .container {
                border: 1px solid rgba(255, 255, 255, 0.1);
            }

            .issue-suggestion {
                background: linear-gradient(135deg, #1e3a8a 0%, #3730a3 100%);
                border: 1px solid #3b82f6;
                color: #e0e7ff;
            }

            .issue-suggestion strong {
                color: #93c5fd;
            }

            .issue-suggestion .suggestion-text {
                color: #e0e7ff;
            }
        }

        /* Smooth scrolling */
        html {
            scroll-behavior: smooth;
        }

        /* Custom scrollbar */
        .dropdown-content::-webkit-scrollbar {
            width: 6px;
        }

        .dropdown-content::-webkit-scrollbar-track {
            background: var(--bg-secondary);
        }

        .dropdown-content::-webkit-scrollbar-thumb {
            background: var(--border-medium);
            border-radius: 3px;
        }

        .dropdown-content::-webkit-scrollbar-thumb:hover {
            background: var(--text-muted);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="header-content">
                <h1>🔍 $projectTitle Accessibility Report</h1>
                <div class="subtitle">
                    $analysisLabel • Generated on ${DateTime.now().toString().split('.')[0]} • Platform: ${result.platform.toString().split('.').last}
                    <span class="badge ast">$badgeLabel</span>
                </div>
            </div>
        </div>

        <div class="summary">
            <h2>📊 Analysis Summary</h2>
            <div class="summary-info">
                <strong>Files Analyzed:</strong> ${result.analyzedFiles.length}
            </div>
            
            <div class="stats">
                <div class="stat total">
                    <div class="number">${result.totalIssues}</div>
                    <div class="label">Total Issues</div>
                </div>
                <div class="stat critical">
                    <div class="number">${result.issuesBySeverity['critical']}</div>
                    <div class="label">Critical</div>
                </div>
                <div class="stat high">
                    <div class="number">${result.issuesBySeverity['high']}</div>
                    <div class="label">High</div>
                </div>
                <div class="stat medium">
                    <div class="number">${result.issuesBySeverity['medium']}</div>
                    <div class="label">Medium</div>
                </div>
                <div class="stat low">
                    <div class="number">${result.issuesBySeverity['low']}</div>
                    <div class="label">Low</div>
                </div>
            </div>
        </div>

        <div class="filters">
            <div class="filter-group">
                <span class="filter-label">Filter by Severity:</span>
                <label>
                    <input type="checkbox" class="filter-checkbox critical" data-severity="critical" checked>
                    <span>Critical (${criticalIssues.length})</span>
                </label>
                <label>
                    <input type="checkbox" class="filter-checkbox high" data-severity="high" checked>
                    <span>High (${highIssues.length})</span>
                </label>
                <label>
                    <input type="checkbox" class="filter-checkbox medium" data-severity="medium" checked>
                    <span>Medium (${mediumIssues.length})</span>
                </label>
                <label>
                    <input type="checkbox" class="filter-checkbox low" data-severity="low" checked>
                    <span>Low (${lowIssues.length})</span>
                </label>
            </div>
            <div class="filter-group">
                <span class="filter-label">Filter by Type:</span>
                <div class="dropdown">
                    <div class="dropdown-btn" id="typeFilterBtn">
                        <span class="selected-items">All Types</span>
                    </div>
                    <div class="dropdown-content" id="typeFilterDropdown">
                        <div class="dropdown-item">
                            <input type="checkbox" id="selectAllTypes" checked>
                            <label for="selectAllTypes">All Types</label>
                        </div>
                        ${_generateTypeFilters(result.issues)}
                    </div>
                </div>
            </div>
        </div>

        <div class="issues">
            ${_generateSeveritySection('Critical Issues', criticalIssues, 'critical')}
            ${_generateSeveritySection('High Priority Issues', highIssues, 'high')}
            ${_generateSeveritySection('Medium Priority Issues', mediumIssues, 'medium')}
            ${_generateSeveritySection('Low Priority Issues', lowIssues, 'low')}
        </div>

        <script>
            document.addEventListener('DOMContentLoaded', function() {
                const severityCheckboxes = document.querySelectorAll('.filter-checkbox[data-severity]');
                const dropdownBtn = document.getElementById('typeFilterBtn');
                const dropdownContent = document.getElementById('typeFilterDropdown');
                const selectAllCheckbox = document.getElementById('selectAllTypes');
                let typeCheckboxes = [];
                
                // Toggle dropdown
                dropdownBtn.addEventListener('click', function(e) {
                    e.stopPropagation();
                    dropdownContent.classList.toggle('show');
                    dropdownBtn.classList.toggle('active');
                });
                
                // Close dropdown when clicking outside
                document.addEventListener('click', function(e) {
                    if (!dropdownBtn.contains(e.target) && !dropdownContent.contains(e.target)) {
                        dropdownContent.classList.remove('show');
                        dropdownBtn.classList.remove('active');
                    }
                });
                
                // Initialize type checkboxes after DOM is loaded
                function initializeTypeFilters() {
                    typeCheckboxes = Array.from(dropdownContent.querySelectorAll('input[type="checkbox"]'));
                    const typeItems = Array.from(dropdownContent.querySelectorAll('.dropdown-item'));
                    
                    // Set initial state
                    updateSelectedTypes();
                    
                    // Add event listeners
                    typeCheckboxes.forEach(checkbox => {
                        checkbox.addEventListener('change', function() {
                            if (this === selectAllCheckbox) {
                                // Toggle all checkboxes when "All Types" is clicked
                                const isChecked = this.checked;
                                typeCheckboxes.forEach(cb => {
                                    if (cb !== selectAllCheckbox) {
                                        cb.checked = isChecked;
                                    }
                                });
                            } else {
                                // Uncheck "All Types" if any other checkbox is unchecked
                                if (!this.checked && selectAllCheckbox.checked) {
                                    selectAllCheckbox.checked = false;
                                }
                                // Check if all other checkboxes are checked
                                const allChecked = typeCheckboxes
                                    .filter(cb => cb !== selectAllCheckbox)
                                    .every(cb => cb.checked);
                                if (allChecked) {
                                    selectAllCheckbox.checked = true;
                                }
                            }
                            updateSelectedTypes();
                            updateFilters();
                        });
                    });
                    
                    // Prevent dropdown from closing when clicking inside
                    dropdownContent.addEventListener('click', function(e) {
                        e.stopPropagation();
                    });
                }
                
                function updateSelectedTypes() {
                    const selectedTypes = [];
                    typeCheckboxes.forEach(checkbox => {
                        if (checkbox.checked && checkbox !== selectAllCheckbox) {
                            selectedTypes.push(checkbox.nextElementSibling.textContent.trim());
                        }
                    });
                    
                    const selectedItems = document.querySelector('.selected-items');
                    if (selectedTypes.length === 0 || selectAllCheckbox.checked) {
                        selectedItems.textContent = 'All Types';
                    } else if (selectedTypes.length === 1) {
                        selectedItems.textContent = selectedTypes[0];
                    } else if (selectedTypes.length <= 3) {
                        selectedItems.textContent = selectedTypes.join(', ');
                    } else {
                        selectedItems.textContent = selectedTypes.length + ' types selected';
                    }
                }
                
                function updateFilters() {
                    // Get selected severities
                    const selectedSeverities = Array.from(severityCheckboxes)
                        .filter(checkbox => checkbox.checked)
                        .map(checkbox => checkbox.dataset.severity);
                    
                    // Get selected types
                    const selectedTypes = [];
                    const showAllTypes = selectAllCheckbox.checked;
                    
                    if (!showAllTypes) {
                        typeCheckboxes.forEach(checkbox => {
                            if (checkbox.checked && checkbox !== selectAllCheckbox) {
                                selectedTypes.push(checkbox.nextElementSibling.textContent.trim());
                            }
                        });
                    }
                    
                    // Show/hide sections based on severity
                    document.querySelectorAll('.severity-section').forEach(section => {
                        const severity = section.querySelector('.severity-title').classList[1];
                        if (selectedSeverities.includes(severity)) {
                            section.style.display = 'block';
                        } else {
                            section.style.display = 'none';
                        }
                    });
                    
                    // Show/hide issues based on type
                    document.querySelectorAll('.issue').forEach(issue => {
                        const issueType = issue.querySelector('.issue-type').textContent;
                        const severity = issue.classList[1];
                        const typeMatch = showAllTypes || selectedTypes.includes(issueType);
                        const severityMatch = selectedSeverities.includes(severity);
                        
                        if (typeMatch && severityMatch) {
                            issue.style.display = 'block';
                        } else {
                            issue.style.display = 'none';
                        }
                    });
                    
                    // Update "No issues" messages
                    document.querySelectorAll('.severity-section').forEach(section => {
                        const severity = section.querySelector('.severity-title').classList[1];
                        const issues = section.querySelectorAll('.issue');
                        const visibleIssues = Array.from(issues).filter(issue => 
                            issue.style.display !== 'none' && 
                            issue.style.display !== ''
                        );
                        
                        const noIssuesDiv = section.querySelector('.no-issues');
                        if (noIssuesDiv) {
                            if (selectedSeverities.includes(severity)) {
                                noIssuesDiv.style.display = visibleIssues.length === 0 ? 'block' : 'none';
                            } else {
                                noIssuesDiv.style.display = 'none';
                            }
                        }
                    });
                }
                
                // Add event listeners for severity checkboxes
                severityCheckboxes.forEach(checkbox => {
                    checkbox.addEventListener('change', updateFilters);
                });
                
                // Initialize the type filters
                initializeTypeFilters();
                
                // Initial filter
                updateFilters();

                // Add smooth scroll behavior for better UX
                document.querySelectorAll('a[href^="#"]').forEach(anchor => {
                    anchor.addEventListener('click', function (e) {
                        e.preventDefault();
                        const target = document.querySelector(this.getAttribute('href'));
                        if (target) {
                            target.scrollIntoView({
                                behavior: 'smooth',
                                block: 'start'
                            });
                        }
                    });
                });

                // Add keyboard navigation for dropdowns
                dropdownBtn.addEventListener('keydown', function(e) {
                    if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        dropdownContent.classList.toggle('show');
                        dropdownBtn.classList.toggle('active');
                    }
                });

                // Add focus management for accessibility
                dropdownContent.addEventListener('keydown', function(e) {
                    if (e.key === 'Escape') {
                        dropdownContent.classList.remove('show');
                        dropdownBtn.classList.remove('active');
                        dropdownBtn.focus();
                    }
                });
            });
        </script>

        <div class="footer">
            <p>Generated by Conalyz CLI ($analysisLabel) •
            <a href="https://github.com/yourusername/flutter-access-advisor" target="_blank">GitHub</a></p>
        </div>
    </div>
</body>
</html>
''';
  }

  String _generateTypeFilters(List<AccessibilityIssue> allIssues) {
    final typeCounts = <String, int>{};
    
    // Count occurrences of each issue type
    for (final issue in allIssues) {
      typeCounts.update(
        issue.type, 
        (count) => count + 1, 
        ifAbsent: () => 1
      );
    }
    
    // Sort types by count (descending)
    final sortedTypes = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Generate dropdown items
    return sortedTypes.map((entry) {
      final type = entry.key;
      final count = entry.value;
      final safeType = _escapeHtml(type);
      return '''
        <div class="dropdown-item">
          <input type="checkbox" id="type_${_toCssId(safeType)}" value="$safeType" checked>
          <label for="type_${_toCssId(safeType)}">$type</label>
          <span class="count">$count</span>
        </div>''';
    }).join('\n');
  }
  
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll('\'', '&#39;');
  }
  
  String _toCssId(String text) {
    return text.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  String _generateSeveritySection(String title, List<AccessibilityIssue> issues, String severity) {
    if (issues.isEmpty) {
      return '''
        <div class="severity-section">
            <h3 class="severity-title $severity">$title (0)</h3>
            <div class="no-issues">No $severity issues found!</div>
        </div>
      ''';
    }

    final issuesHtml = issues.map((issue) => '''
      <div class="issue $severity">
          <div class="issue-header">
              <span class="issue-type">${issue.type}</span>
              <span class="issue-rule">${issue.rule}</span>
          </div>
          <div class="issue-location">${issue.file}:${issue.line}:${issue.column}</div>
          <div class="issue-message">${issue.message}</div>
          <div class="issue-suggestion">
              <strong>Suggestion:</strong>
              <span class="suggestion-text">${issue.suggestion}</span>
          </div>
      </div>
    ''').join('');

    return '''
      <div class="severity-section">
          <h3 class="severity-title $severity">$title (${issues.length})</h3>
          $issuesHtml
      </div>
    ''';
  }
}