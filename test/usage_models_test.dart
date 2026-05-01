import 'package:test/test.dart';
import 'package:conalyz/src/usage_models.dart';

void main() {
  group('UsageRecord Tests', () {
    test('should create UsageRecord with all required fields', () {
      final timestamp = DateTime.now();
      final analysisDate = DateTime.now();

      final record = UsageRecord(
        timestamp: timestamp,
        linesScanned: 1000,
        projectPath: '/test/project',
        platform: 'mobile',
        analysisTimeMs: 2500,
        filesAnalyzed: 10,
        analysisDate: analysisDate,
      );

      expect(record.timestamp, equals(timestamp));
      expect(record.linesScanned, equals(1000));
      expect(record.projectPath, equals('/test/project'));
      expect(record.platform, equals('mobile'));
      expect(record.analysisTimeMs, equals(2500));
      expect(record.filesAnalyzed, equals(10));
      expect(record.analysisDate, equals(analysisDate));
    });

    test('should serialize to JSON correctly', () {
      final timestamp = DateTime.parse('2024-01-15T10:30:00.000Z');
      final analysisDate = DateTime.parse('2024-01-15T10:30:00.000Z');

      final record = UsageRecord(
        timestamp: timestamp,
        linesScanned: 1000,
        projectPath: '/test/project',
        platform: 'mobile',
        analysisTimeMs: 2500,
        filesAnalyzed: 10,
        analysisDate: analysisDate,
      );

      final json = record.toJson();

      expect(json['timestamp'], equals('2024-01-15T10:30:00.000Z'));
      expect(json['linesScanned'], equals(1000));
      expect(json['projectPath'], equals('/test/project'));
      expect(json['platform'], equals('mobile'));
      expect(json['analysisTimeMs'], equals(2500));
      expect(json['filesAnalyzed'], equals(10));
      expect(json['analysisDate'], equals('2024-01-15T10:30:00.000Z'));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'timestamp': '2024-01-15T10:30:00.000Z',
        'linesScanned': 1000,
        'projectPath': '/test/project',
        'platform': 'mobile',
        'analysisTimeMs': 2500,
        'filesAnalyzed': 10,
        'analysisDate': '2024-01-15T10:30:00.000Z',
      };

      final record = UsageRecord.fromJson(json);

      expect(
          record.timestamp, equals(DateTime.parse('2024-01-15T10:30:00.000Z')));
      expect(record.linesScanned, equals(1000));
      expect(record.projectPath, equals('/test/project'));
      expect(record.platform, equals('mobile'));
      expect(record.analysisTimeMs, equals(2500));
      expect(record.filesAnalyzed, equals(10));
      expect(record.analysisDate,
          equals(DateTime.parse('2024-01-15T10:30:00.000Z')));
    });
  });

  group('UsageStorageData Tests', () {
    test('should create empty storage data', () {
      final data = UsageStorageData.empty();

      expect(data.version, equals('1.0'));
      expect(data.records, isEmpty);
      expect(data.created, isA<DateTime>());
      expect(data.lastUpdated, isA<DateTime>());
    });

    test('should add record to storage data', () {
      final data = UsageStorageData.empty();
      final record = UsageRecord(
        timestamp: DateTime.now(),
        linesScanned: 100,
        projectPath: '/test',
        platform: 'mobile',
        analysisTimeMs: 1000,
        filesAnalyzed: 5,
        analysisDate: DateTime.now(),
      );

      final updatedData = data.addRecord(record);

      expect(updatedData.records, hasLength(1));
      expect(updatedData.records.first, equals(record));
      expect(updatedData.lastUpdated.isAfter(data.lastUpdated), isTrue);
    });

    test('should serialize to JSON correctly', () {
      final created = DateTime.parse('2024-01-15T10:00:00.000Z');
      final lastUpdated = DateTime.parse('2024-01-15T10:30:00.000Z');

      final record = UsageRecord(
        timestamp: DateTime.parse('2024-01-15T10:30:00.000Z'),
        linesScanned: 100,
        projectPath: '/test',
        platform: 'mobile',
        analysisTimeMs: 1000,
        filesAnalyzed: 5,
        analysisDate: DateTime.parse('2024-01-15T10:30:00.000Z'),
      );

      final data = UsageStorageData(
        version: '1.0',
        records: [record],
        created: created,
        lastUpdated: lastUpdated,
      );

      final json = data.toJson();

      expect(json['version'], equals('1.0'));
      expect(json['records'], hasLength(1));
      expect(json['metadata']['created'], equals('2024-01-15T10:00:00.000Z'));
      expect(
          json['metadata']['lastUpdated'], equals('2024-01-15T10:30:00.000Z'));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'version': '1.0',
        'records': [
          {
            'timestamp': '2024-01-15T10:30:00.000Z',
            'linesScanned': 100,
            'projectPath': '/test',
            'platform': 'mobile',
            'analysisTimeMs': 1000,
            'filesAnalyzed': 5,
            'analysisDate': '2024-01-15T10:30:00.000Z',
          }
        ],
        'metadata': {
          'created': '2024-01-15T10:00:00.000Z',
          'lastUpdated': '2024-01-15T10:30:00.000Z',
        },
      };

      final data = UsageStorageData.fromJson(json);

      expect(data.version, equals('1.0'));
      expect(data.records, hasLength(1));
      expect(data.created, equals(DateTime.parse('2024-01-15T10:00:00.000Z')));
      expect(
          data.lastUpdated, equals(DateTime.parse('2024-01-15T10:30:00.000Z')));
    });
  });

  group('UsageStatistics Tests', () {
    test('should create statistics from empty records', () {
      final statistics = UsageStatistics.fromRecords([]);

      expect(statistics.totalSessions, equals(0));
      expect(statistics.totalLinesScanned, equals(0));
      expect(statistics.totalFilesAnalyzed, equals(0));
      expect(statistics.averageLinesPerSession, equals(0.0));
      expect(statistics.averageAnalysisTimeMs, equals(0.0));
      expect(statistics.firstUsage, isNull);
      expect(statistics.lastUsage, isNull);
      expect(statistics.recentSessions, isEmpty);
      expect(statistics.usageByPlatform, isEmpty);
      expect(statistics.largestSession, isNull);
      expect(statistics.mostProductiveDay, isNull);
    });

    test('should create statistics from single record', () {
      final timestamp = DateTime.parse('2024-01-15T10:30:00.000Z');
      final record = UsageRecord(
        timestamp: timestamp,
        linesScanned: 1000,
        projectPath: '/test/project',
        platform: 'mobile',
        analysisTimeMs: 2500,
        filesAnalyzed: 10,
        analysisDate: timestamp,
      );

      final statistics = UsageStatistics.fromRecords([record]);

      expect(statistics.totalSessions, equals(1));
      expect(statistics.totalLinesScanned, equals(1000));
      expect(statistics.totalFilesAnalyzed, equals(10));
      expect(statistics.averageLinesPerSession, equals(1000.0));
      expect(statistics.averageAnalysisTimeMs, equals(2500.0));
      expect(statistics.firstUsage, equals(timestamp));
      expect(statistics.lastUsage, equals(timestamp));
      expect(statistics.recentSessions, hasLength(1));
      expect(statistics.usageByPlatform['mobile'], equals(1000));
      expect(statistics.largestSession, equals(record));
      expect(statistics.mostProductiveDay,
          equals(DateTime(timestamp.year, timestamp.month, timestamp.day)));
    });

    test('should create statistics from multiple records', () {
      final timestamp1 = DateTime.parse('2024-01-15T10:30:00.000Z');
      final timestamp2 = DateTime.parse('2024-01-16T14:45:00.000Z');

      final record1 = UsageRecord(
        timestamp: timestamp1,
        linesScanned: 1000,
        projectPath: '/test/project1',
        platform: 'mobile',
        analysisTimeMs: 2500,
        filesAnalyzed: 10,
        analysisDate: timestamp1,
      );

      final record2 = UsageRecord(
        timestamp: timestamp2,
        linesScanned: 1500,
        projectPath: '/test/project2',
        platform: 'web',
        analysisTimeMs: 3500,
        filesAnalyzed: 15,
        analysisDate: timestamp2,
      );

      final statistics = UsageStatistics.fromRecords([record1, record2]);

      expect(statistics.totalSessions, equals(2));
      expect(statistics.totalLinesScanned, equals(2500));
      expect(statistics.totalFilesAnalyzed, equals(25));
      expect(statistics.averageLinesPerSession, equals(1250.0));
      expect(statistics.averageAnalysisTimeMs, equals(3000.0));
      expect(statistics.firstUsage, equals(timestamp1));
      expect(statistics.lastUsage, equals(timestamp2));
      expect(statistics.recentSessions, hasLength(2));
      expect(statistics.usageByPlatform['mobile'], equals(1000));
      expect(statistics.usageByPlatform['web'], equals(1500));
      expect(statistics.largestSession, equals(record2)); // Larger session
    });

    test('should limit recent sessions', () {
      final records = <UsageRecord>[];

      // Create 15 records
      for (int i = 0; i < 15; i++) {
        records.add(UsageRecord(
          timestamp: DateTime.now().subtract(Duration(hours: i)),
          linesScanned: 100 + i,
          projectPath: '/test/project$i',
          platform: 'mobile',
          analysisTimeMs: 1000 + i * 100,
          filesAnalyzed: 5 + i,
          analysisDate: DateTime.now().subtract(Duration(hours: i)),
        ));
      }

      final statistics = UsageStatistics.fromRecords(records);

      expect(statistics.totalSessions, equals(15));
      expect(statistics.recentSessions.length,
          lessThanOrEqualTo(10)); // Should be limited
    });

    test('should calculate most productive day correctly', () {
      final day1 = DateTime.parse('2024-01-15T10:00:00.000Z');
      final day2 = DateTime.parse('2024-01-16T10:00:00.000Z');

      final records = [
        // Day 1: 2 sessions, 1500 lines total
        UsageRecord(
          timestamp: day1,
          linesScanned: 1000,
          projectPath: '/test1',
          platform: 'mobile',
          analysisTimeMs: 2000,
          filesAnalyzed: 10,
          analysisDate: day1,
        ),
        UsageRecord(
          timestamp: day1.add(const Duration(hours: 2)),
          linesScanned: 500,
          projectPath: '/test2',
          platform: 'mobile',
          analysisTimeMs: 1000,
          filesAnalyzed: 5,
          analysisDate: day1,
        ),
        // Day 2: 1 session, 800 lines
        UsageRecord(
          timestamp: day2,
          linesScanned: 800,
          projectPath: '/test3',
          platform: 'web',
          analysisTimeMs: 1500,
          filesAnalyzed: 8,
          analysisDate: day2,
        ),
      ];

      final statistics = UsageStatistics.fromRecords(records);

      expect(
          statistics.mostProductiveDay,
          equals(DateTime(
              day1.year, day1.month, day1.day))); // Day 1 had more lines
    });
  });

  group('Daily File Limit Tests', () {
    test('daily file limit is currently disabled (unlimited)', () {
      // Daily limit is commented out for unlimited analysis
      // expect(dailyFileLimit, greaterThan(0));
      // expect(dailyFileLimit, lessThanOrEqualTo(1000));
      expect(true, isTrue); // Placeholder test
    });
  });
}
