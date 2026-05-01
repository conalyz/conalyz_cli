// Maximum number of files that can be analyzed per day
// const int dailyFileLimit = 100; // Unlimited for now

/// Represents a single usage record for an analysis session
class UsageRecord {
  final DateTime timestamp;
  final int linesScanned;
  final String projectPath;
  final String platform;
  final int analysisTimeMs;
  final int filesAnalyzed;
  final DateTime analysisDate; // Date part only, for daily tracking

  const UsageRecord({
    required this.timestamp,
    required this.linesScanned,
    required this.projectPath,
    required this.platform,
    required this.analysisTimeMs,
    required this.filesAnalyzed,
    required this.analysisDate,
  });

  /// Creates a UsageRecord from a JSON map
  factory UsageRecord.fromJson(Map<String, dynamic> json) {
    return UsageRecord(
      timestamp: DateTime.parse(json['timestamp'] as String),
      linesScanned: json['linesScanned'] as int,
      projectPath: json['projectPath'] as String,
      platform: json['platform'] as String,
      analysisTimeMs: json['analysisTimeMs'] as int,
      filesAnalyzed: json['filesAnalyzed'] as int,
      analysisDate: DateTime.parse(json['analysisDate'] as String),
    );
  }

  /// Converts the UsageRecord to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'linesScanned': linesScanned,
      'projectPath': projectPath,
      'platform': platform,
      'analysisTimeMs': analysisTimeMs,
      'filesAnalyzed': filesAnalyzed,
      'analysisDate': analysisDate.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UsageRecord &&
        other.timestamp == timestamp &&
        other.linesScanned == linesScanned &&
        other.projectPath == projectPath &&
        other.platform == platform &&
        other.analysisTimeMs == analysisTimeMs &&
        other.filesAnalyzed == filesAnalyzed &&
        other.analysisDate == analysisDate;
  }

  @override
  int get hashCode {
    return Object.hash(
      timestamp,
      linesScanned,
      projectPath,
      platform,
      analysisTimeMs,
      filesAnalyzed,
      analysisDate,
    );
  }

  @override
  String toString() {
    return 'UsageRecord(timestamp: $timestamp, linesScanned: $linesScanned, '
        'projectPath: $projectPath, platform: $platform, '
        'analysisTimeMs: $analysisTimeMs, filesAnalyzed: $filesAnalyzed, analysisDate: $analysisDate)';
  }
}

/// Represents aggregated usage statistics
class UsageStatistics {
  final int totalLinesScanned;
  final int totalSessions;
  final DateTime? firstUsage;
  final DateTime? lastUsage;
  final double averageLinesPerSession;
  final List<UsageRecord> recentSessions;

  const UsageStatistics({
    required this.totalLinesScanned,
    required this.totalSessions,
    this.firstUsage,
    this.lastUsage,
    required this.averageLinesPerSession,
    required this.recentSessions,
  });

  /// Creates UsageStatistics from a list of usage records
  factory UsageStatistics.fromRecords(List<UsageRecord> records) {
    if (records.isEmpty) {
      return const UsageStatistics(
        totalLinesScanned: 0,
        totalSessions: 0,
        firstUsage: null,
        lastUsage: null,
        averageLinesPerSession: 0.0,
        recentSessions: [],
      );
    }

    // Sort records by timestamp
    final sortedRecords = List<UsageRecord>.from(records)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final totalLines =
        records.fold<int>(0, (sum, record) => sum + record.linesScanned);
    final totalSessions = records.length;
    final averageLines = totalSessions > 0 ? totalLines / totalSessions : 0.0;

    // Get recent sessions (last 10)
    final recentSessions = sortedRecords.reversed.take(10).toList();

    return UsageStatistics(
      totalLinesScanned: totalLines,
      totalSessions: totalSessions,
      firstUsage: sortedRecords.first.timestamp,
      lastUsage: sortedRecords.last.timestamp,
      averageLinesPerSession: averageLines,
      recentSessions: recentSessions,
    );
  }

  /// Creates a UsageStatistics from a JSON map
  factory UsageStatistics.fromJson(Map<String, dynamic> json) {
    final recentSessionsJson = json['recentSessions'] as List<dynamic>? ?? [];
    final recentSessions = recentSessionsJson
        .map((sessionJson) =>
            UsageRecord.fromJson(sessionJson as Map<String, dynamic>))
        .toList();

    return UsageStatistics(
      totalLinesScanned: json['totalLinesScanned'] as int,
      totalSessions: json['totalSessions'] as int,
      firstUsage: json['firstUsage'] != null
          ? DateTime.parse(json['firstUsage'] as String)
          : null,
      lastUsage: json['lastUsage'] != null
          ? DateTime.parse(json['lastUsage'] as String)
          : null,
      averageLinesPerSession:
          (json['averageLinesPerSession'] as num).toDouble(),
      recentSessions: recentSessions,
    );
  }

  /// Converts the UsageStatistics to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'totalLinesScanned': totalLinesScanned,
      'totalSessions': totalSessions,
      'firstUsage': firstUsage?.toIso8601String(),
      'lastUsage': lastUsage?.toIso8601String(),
      'averageLinesPerSession': averageLinesPerSession,
      'recentSessions':
          recentSessions.map((session) => session.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UsageStatistics &&
        other.totalLinesScanned == totalLinesScanned &&
        other.totalSessions == totalSessions &&
        other.firstUsage == firstUsage &&
        other.lastUsage == lastUsage &&
        other.averageLinesPerSession == averageLinesPerSession &&
        _listEquals(other.recentSessions, recentSessions);
  }

  @override
  int get hashCode {
    return Object.hash(
      totalLinesScanned,
      totalSessions,
      firstUsage,
      lastUsage,
      averageLinesPerSession,
      Object.hashAll(recentSessions),
    );
  }

  @override
  String toString() {
    return 'UsageStatistics(totalLinesScanned: $totalLinesScanned, '
        'totalSessions: $totalSessions, firstUsage: $firstUsage, '
        'lastUsage: $lastUsage, averageLinesPerSession: $averageLinesPerSession, '
        'recentSessions: ${recentSessions.length} sessions)';
  }

  /// Gets the total number of files analyzed across all sessions
  int get totalFilesAnalyzed {
    return recentSessions.fold<int>(
        0, (sum, record) => sum + record.filesAnalyzed);
  }

  /// Gets the total analysis time in milliseconds across all sessions
  int get totalAnalysisTimeMs {
    return recentSessions.fold<int>(
        0, (sum, record) => sum + record.analysisTimeMs);
  }

  /// Gets the average analysis time per session in milliseconds
  double get averageAnalysisTimeMs {
    if (totalSessions == 0) return 0.0;
    return totalAnalysisTimeMs / totalSessions;
  }

  /// Gets the average files analyzed per session
  double get averageFilesPerSession {
    if (totalSessions == 0) return 0.0;
    return totalFilesAnalyzed / totalSessions;
  }

  /// Gets usage statistics grouped by platform
  Map<String, int> get usageByPlatform {
    final platformStats = <String, int>{};
    for (final record in recentSessions) {
      platformStats[record.platform] =
          (platformStats[record.platform] ?? 0) + record.linesScanned;
    }
    return platformStats;
  }

  /// Gets the most productive day (day with most lines scanned)
  DateTime? get mostProductiveDay {
    if (recentSessions.isEmpty) return null;

    final dailyStats = <String, int>{};
    for (final record in recentSessions) {
      final dayKey =
          '${record.timestamp.year}-${record.timestamp.month.toString().padLeft(2, '0')}-${record.timestamp.day.toString().padLeft(2, '0')}';
      dailyStats[dayKey] = (dailyStats[dayKey] ?? 0) + record.linesScanned;
    }

    if (dailyStats.isEmpty) return null;

    final mostProductiveDayKey =
        dailyStats.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    final parts = mostProductiveDayKey.split('-');
    return DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  /// Gets the largest single analysis session (by lines scanned)
  UsageRecord? get largestSession {
    if (recentSessions.isEmpty) return null;
    return recentSessions
        .reduce((a, b) => a.linesScanned > b.linesScanned ? a : b);
  }

  /// Gets usage statistics for the last N days
  UsageStatistics getRecentUsage(int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final recentRecords = recentSessions
        .where((record) => record.timestamp.isAfter(cutoffDate))
        .toList();

    return UsageStatistics.fromRecords(recentRecords);
  }

  /// Helper method to compare lists
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Storage file format for usage data
class UsageStorageData {
  final String version;
  final List<UsageRecord> records;
  final DateTime created;
  final DateTime lastUpdated;

  const UsageStorageData({
    required this.version,
    required this.records,
    required this.created,
    required this.lastUpdated,
  });

  /// Creates UsageStorageData from a JSON map
  factory UsageStorageData.fromJson(Map<String, dynamic> json) {
    final recordsJson = json['records'] as List<dynamic>? ?? [];
    final records = recordsJson
        .map((recordJson) =>
            UsageRecord.fromJson(recordJson as Map<String, dynamic>))
        .toList();

    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};

    return UsageStorageData(
      version: json['version'] as String? ?? '1.0',
      records: records,
      created: metadata['created'] != null
          ? DateTime.parse(metadata['created'] as String)
          : DateTime.now(),
      lastUpdated: metadata['lastUpdated'] != null
          ? DateTime.parse(metadata['lastUpdated'] as String)
          : DateTime.now(),
    );
  }

  /// Converts the UsageStorageData to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'records': records.map((record) => record.toJson()).toList(),
      'metadata': {
        'created': created.toIso8601String(),
        'lastUpdated': lastUpdated.toIso8601String(),
      },
    };
  }

  /// Creates a new UsageStorageData with an added record
  UsageStorageData addRecord(UsageRecord record) {
    return UsageStorageData(
      version: version,
      records: [...records, record],
      created: created,
      lastUpdated: DateTime.now(),
    );
  }

  /// Creates a new empty UsageStorageData
  factory UsageStorageData.empty() {
    final now = DateTime.now();
    return UsageStorageData(
      version: '1.0',
      records: [],
      created: now,
      lastUpdated: now,
    );
  }
}
