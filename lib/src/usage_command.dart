import 'dart:io';
import 'package:intl/intl.dart';
import 'package:conalyz/src/usage_storage_service.dart';

/// Command handler for usage-related operations
class UsageCommand {
  final UsageStorageService _storageService;

  UsageCommand({UsageStorageService? storageService})
      : _storageService = storageService ?? UsageStorageService();

  /// Shows basic usage statistics
  Future<void> showBasicUsage() async {
    try {
      final statistics = await _storageService.getUsageStatistics();
      
      if (statistics.totalSessions == 0) {
        print('📊 Flutter Access Advisor - Usage Statistics');
        print('');
        print('No analysis sessions recorded yet.');
        print('Run an analysis to start tracking your usage.');
        print('');
        print('💡 Tip: Use "conalyz --path <project>" to analyze a Flutter project.');
        return;
      }

      print('📊 Flutter Access Advisor - Usage Statistics');
      print('');
      print('📈 Total lines scanned: ${_formatNumber(statistics.totalLinesScanned)}');
      print('🔄 Analysis sessions: ${statistics.totalSessions}');
      print('📅 Date range: ${_formatDateRange(statistics.firstUsage, statistics.lastUsage)}');
      print('📊 Average lines per session: ${_formatNumber(statistics.averageLinesPerSession.round())}');
      print('📁 Total files analyzed: ${_formatNumber(statistics.totalFilesAnalyzed)}');
      print('⏱️  Average analysis time: ${_formatDuration(statistics.averageAnalysisTimeMs.round())}');
      print('');
      print('💡 Tip: Use "conalyz usage --detailed" for more insights.');
      
    } catch (e) {
      print('❌ Error retrieving usage statistics: $e');
      exit(1);
    }
  }

  /// Shows detailed usage statistics with recent sessions
  Future<void> showDetailedUsage() async {
    try {
      final statistics = await _storageService.getUsageStatistics();
      
      if (statistics.totalSessions == 0) {
        print('📊 Flutter Access Advisor - Detailed Usage Statistics');
        print('');
        print('No analysis sessions recorded yet.');
        print('Run an analysis to start tracking your usage.');
        print('');
        print('💡 Tip: Use "conalyz --path <project>" to analyze a Flutter project.');
        return;
      }

      // Show basic statistics first (but modify the title for detailed view)
      print('📊 Flutter Access Advisor - Detailed Usage Statistics');
      print('');
      print('📈 Total lines scanned: ${_formatNumber(statistics.totalLinesScanned)}');
      print('🔄 Analysis sessions: ${statistics.totalSessions}');
      print('📅 Date range: ${_formatDateRange(statistics.firstUsage, statistics.lastUsage)}');
      print('📊 Average lines per session: ${_formatNumber(statistics.averageLinesPerSession.round())}');
      print('📁 Total files analyzed: ${_formatNumber(statistics.totalFilesAnalyzed)}');
      print('⏱️  Average analysis time: ${_formatDuration(statistics.averageAnalysisTimeMs.round())}');
      
      // Show platform breakdown
      final platformStats = statistics.usageByPlatform;
      if (platformStats.isNotEmpty) {
        print('');
        print('🎯 Usage by Platform:');
        for (final entry in platformStats.entries) {
          final percentage = (entry.value / statistics.totalLinesScanned * 100).round();
          final progressBar = _createProgressBar(percentage, 20);
          print('   ${entry.key.padRight(8)}: ${_formatNumber(entry.value).padLeft(8)} lines (${percentage.toString().padLeft(2)}%) $progressBar');
        }
      }

      // Show productivity insights
      final largestSession = statistics.largestSession;
      if (largestSession != null) {
        print('');
        print('🏆 Largest Analysis Session:');
        print('   ${_formatNumber(largestSession.linesScanned)} lines on ${_formatDateTime(largestSession.timestamp)}');
      }

      final mostProductiveDay = statistics.mostProductiveDay;
      if (mostProductiveDay != null) {
        print('');
        print('⭐ Most Productive Day:');
        print('   ${_formatDate(mostProductiveDay)}');
      }

      // Show recent sessions
      print('');
      print('📋 Recent Analysis Sessions:');
      print('');
      
      if (statistics.recentSessions.isEmpty) {
        print('No recent sessions available.');
        return;
      }

      for (int i = 0; i < statistics.recentSessions.length; i++) {
        final session = statistics.recentSessions[i];
        final sessionNumber = i + 1;
        
        print('${sessionNumber.toString().padLeft(2)}. ${_formatDateTime(session.timestamp)}');
        print('    📁 Project: ${_truncatePath(session.projectPath)}');
        print('    🎯 Platform: ${session.platform}');
        print('    📄 Files: ${session.filesAnalyzed}');
        print('    📏 Lines: ${_formatNumber(session.linesScanned)}');
        print('    ⏱️  Time: ${_formatDuration(session.analysisTimeMs)}');
        
        if (i < statistics.recentSessions.length - 1) {
          print('');
        }
      }
      
    } catch (e) {
      print('❌ Error retrieving detailed usage statistics: $e');
      exit(1);
    }
  }


  /// Formats a number with thousand separators
  String _formatNumber(int number) {
    final formatter = NumberFormat('#,###');
    return formatter.format(number);
  }

  /// Formats a date range for display
  String _formatDateRange(DateTime? first, DateTime? last) {
    if (first == null || last == null) {
      return 'Unknown';
    }

    final dateFormat = DateFormat('MMM d, yyyy');
    
    if (_isSameDay(first, last)) {
      return dateFormat.format(first);
    }
    
    return '${dateFormat.format(first)} - ${dateFormat.format(last)}';
  }

  /// Formats a DateTime for detailed display
  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('MMM d, yyyy HH:mm');
    return formatter.format(dateTime);
  }

  /// Formats a DateTime for date-only display
  String _formatDate(DateTime dateTime) {
    final formatter = DateFormat('MMM d, yyyy');
    return formatter.format(dateTime);
  }

  /// Formats analysis duration in milliseconds to human-readable format
  String _formatDuration(int milliseconds) {
    if (milliseconds < 1000) {
      return '${milliseconds}ms';
    }
    
    final seconds = milliseconds / 1000;
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(1)}s';
    }
    
    final minutes = seconds / 60;
    return '${minutes.toStringAsFixed(1)}m';
  }

  /// Truncates long file paths for display
  String _truncatePath(String path) {
    const maxLength = 50;
    
    if (path.length <= maxLength) {
      return path;
    }
    
    // Try to keep the filename and some parent directories
    final parts = path.split('/');
    if (parts.length <= 2) {
      return '...${path.substring(path.length - maxLength + 3)}';
    }
    
    // Keep the last few parts of the path
    final fileName = parts.last;
    final parentDir = parts[parts.length - 2];
    final truncated = '.../$parentDir/$fileName';
    
    if (truncated.length <= maxLength) {
      return truncated;
    }
    
    return '...${path.substring(path.length - maxLength + 3)}';
  }

  /// Checks if two DateTime objects represent the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Creates a visual progress bar for percentages
  String _createProgressBar(int percentage, int width) {
    final filled = (percentage / 100 * width).round();
    final empty = width - filled;
    return '[${'█' * filled}${' ' * empty}]';
  }
}