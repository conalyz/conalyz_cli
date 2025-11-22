import 'package:test/test.dart';
import 'package:conalyz/src/usage_storage_service.dart';
import 'package:conalyz/src/usage_models.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  group('UsageStorageService Tests', () {
    late Directory tempDir;
    late String testStoragePath;
    late UsageStorageService service;

    setUp(() async {
      // Create a temporary directory for testing
      tempDir = await Directory.systemTemp.createTemp('usage_storage_test_');
      testStoragePath = '${tempDir.path}/test_usage.json';
      service = UsageStorageService(testStoragePath: testStoragePath);
    });

    tearDown(() async {
      // Clean up temporary directory
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Storage Initialization', () {
      test('should initialize storage successfully', () async {
        await service.initializeStorage();
        
        final file = File(testStoragePath);
        expect(file.existsSync(), isTrue);
        
        final content = await file.readAsString();
        final data = json.decode(content);
        expect(data['version'], equals('1.0'));
        expect(data['records'], isEmpty);
      });

      test('should handle existing valid storage file', () async {
        // Create a valid storage file first
        final initialData = UsageStorageData.empty();
        final file = File(testStoragePath);
        await file.parent.create(recursive: true);
        await file.writeAsString(json.encode(initialData.toJson()));
        
        // Initialize should not overwrite existing valid file
        await service.initializeStorage();
        
        final content = await file.readAsString();
        final data = json.decode(content);
        expect(data['version'], equals('1.0'));
      });
    });

    group('Usage Recording', () {
      test('should record usage successfully', () async {
        await service.initializeStorage();
        
        final record = UsageRecord(
          timestamp: DateTime.now(),
          linesScanned: 100,
          projectPath: '/test/project',
          platform: 'mobile',
          analysisTimeMs: 1500,
          filesAnalyzed: 5,
          analysisDate: DateTime.now(),
        );
        
        await service.recordUsage(record);
        
        final statistics = await service.getUsageStatistics();
        expect(statistics.totalSessions, equals(1));
        expect(statistics.totalLinesScanned, equals(100));
        expect(statistics.totalFilesAnalyzed, equals(5));
      });

      test('should record multiple usage sessions', () async {
        await service.initializeStorage();
        
        final record1 = UsageRecord(
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          linesScanned: 100,
          projectPath: '/test/project1',
          platform: 'mobile',
          analysisTimeMs: 1500,
          filesAnalyzed: 5,
          analysisDate: DateTime.now().subtract(const Duration(days: 1)),
        );
        
        final record2 = UsageRecord(
          timestamp: DateTime.now(),
          linesScanned: 200,
          projectPath: '/test/project2',
          platform: 'web',
          analysisTimeMs: 2500,
          filesAnalyzed: 10,
          analysisDate: DateTime.now(),
        );
        
        await service.recordUsage(record1);
        await service.recordUsage(record2);
        
        final statistics = await service.getUsageStatistics();
        expect(statistics.totalSessions, equals(2));
        expect(statistics.totalLinesScanned, equals(300));
        expect(statistics.totalFilesAnalyzed, equals(15));
        expect(statistics.averageLinesPerSession, equals(150.0));
      });
    });

    group('Usage Statistics', () {
      test('should return empty statistics for no usage', () async {
        await service.initializeStorage();
        
        final statistics = await service.getUsageStatistics();
        expect(statistics.totalSessions, equals(0));
        expect(statistics.totalLinesScanned, equals(0));
        expect(statistics.firstUsage, isNull);
        expect(statistics.lastUsage, isNull);
        expect(statistics.recentSessions, isEmpty);
      });

      test('should calculate statistics correctly', () async {
        await service.initializeStorage();
        
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        
        final record1 = UsageRecord(
          timestamp: yesterday,
          linesScanned: 100,
          projectPath: '/test/project1',
          platform: 'mobile',
          analysisTimeMs: 1000,
          filesAnalyzed: 5,
          analysisDate: yesterday,
        );
        
        final record2 = UsageRecord(
          timestamp: now,
          linesScanned: 300,
          projectPath: '/test/project2',
          platform: 'web',
          analysisTimeMs: 3000,
          filesAnalyzed: 15,
          analysisDate: now,
        );
        
        await service.recordUsage(record1);
        await service.recordUsage(record2);
        
        final statistics = await service.getUsageStatistics();
        expect(statistics.totalSessions, equals(2));
        expect(statistics.totalLinesScanned, equals(400));
        expect(statistics.totalFilesAnalyzed, equals(20));
        expect(statistics.averageLinesPerSession, equals(200.0));
        expect(statistics.averageAnalysisTimeMs, equals(2000.0));
        expect(statistics.firstUsage, equals(yesterday));
        expect(statistics.lastUsage, equals(now));
        expect(statistics.recentSessions, hasLength(2));
        
        // Check platform breakdown
        expect(statistics.usageByPlatform['mobile'], equals(100));
        expect(statistics.usageByPlatform['web'], equals(300));
      });

      test('should limit recent sessions to maximum count', () async {
        await service.initializeStorage();
        
        // Add more than the maximum recent sessions
        for (int i = 0; i < 12; i++) {
          final record = UsageRecord(
            timestamp: DateTime.now().subtract(Duration(hours: i)),
            linesScanned: 100 + i,
            projectPath: '/test/project$i',
            platform: 'mobile',
            analysisTimeMs: 1000 + i * 100,
            filesAnalyzed: 5 + i,
            analysisDate: DateTime.now().subtract(Duration(hours: i)),
          );
          await service.recordUsage(record);
        }
        
        final statistics = await service.getUsageStatistics();
        expect(statistics.totalSessions, equals(12));
        expect(statistics.recentSessions.length, lessThanOrEqualTo(10)); // Should be limited
      });
    });

    group('Daily Limit Checking', () {
      test('should allow unlimited analysis (daily limit disabled)', () async {
        await service.initializeStorage();
        
        final result = await service.checkDailyLimit(50);
        expect(result, isNull); // Should always allow analysis (unlimited)
      });

      test('should allow analysis even with many files (unlimited)', () async {
        await service.initializeStorage();
        
        // Add many records
        final today = DateTime.now();
        for (int i = 0; i < 10; i++) {
          final record = UsageRecord(
            timestamp: today.subtract(Duration(hours: i)),
            linesScanned: 1000,
            projectPath: '/test/project$i',
            platform: 'mobile',
            analysisTimeMs: 2000,
            filesAnalyzed: 100, // Many files
            analysisDate: today,
          );
          await service.recordUsage(record);
        }
        
        // Should still allow analysis (unlimited)
        final result = await service.checkDailyLimit(1000);
        expect(result, isNull); // Should allow unlimited analysis
      });

      test('should allow analysis on any day (unlimited)', () async {
        await service.initializeStorage();
        
        // Add records from yesterday
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        for (int i = 0; i < 5; i++) {
          final record = UsageRecord(
            timestamp: yesterday.subtract(Duration(hours: i)),
            linesScanned: 1000,
            projectPath: '/test/project$i',
            platform: 'mobile',
            analysisTimeMs: 2000,
            filesAnalyzed: 50,
            analysisDate: yesterday,
          );
          await service.recordUsage(record);
        }
        
        // Should allow analysis (unlimited)
        final result = await service.checkDailyLimit(50);
        expect(result, isNull); // Should allow unlimited analysis
      });
    });

    group('Error Handling', () {
      test('should handle corrupted storage file gracefully', () async {
        // Create a corrupted file
        final file = File(testStoragePath);
        await file.parent.create(recursive: true);
        await file.writeAsString('invalid json content');
        
        // Should recover and return empty statistics
        final statistics = await service.getUsageStatistics();
        expect(statistics.totalSessions, equals(0));
      });

      test('should handle missing storage file gracefully', () async {
        // Don't initialize storage, try to get statistics
        final statistics = await service.getUsageStatistics();
        expect(statistics.totalSessions, equals(0));
      });

      test('should continue working after storage errors', () async {
        await service.initializeStorage();
        
        // Record some usage
        final record = UsageRecord(
          timestamp: DateTime.now(),
          linesScanned: 100,
          projectPath: '/test/project',
          platform: 'mobile',
          analysisTimeMs: 1500,
          filesAnalyzed: 5,
          analysisDate: DateTime.now(),
        );
        
        await service.recordUsage(record);
        
        // Corrupt the file
        final file = File(testStoragePath);
        await file.writeAsString('corrupted content');
        
        // Should still handle new records gracefully
        await service.recordUsage(record);
        
        // Should recover and work
        final statistics = await service.getUsageStatistics();
        expect(statistics.totalSessions, greaterThanOrEqualTo(0));
      });
    });

    group('Storage Path Management', () {
      test('should return consistent storage file path', () async {
        final path1 = await service.getStorageFilePath();
        final path2 = await service.getStorageFilePath();
        
        expect(path1, equals(path2));
        expect(path1, equals(testStoragePath));
      });

      test('should create storage directory if it does not exist', () async {
        final deepPath = '${tempDir.path}/deep/nested/path/usage.json';
        final deepService = UsageStorageService(testStoragePath: deepPath);
        
        await deepService.initializeStorage();
        
        final file = File(deepPath);
        expect(file.existsSync(), isTrue);
        expect(file.parent.existsSync(), isTrue);
      });
    });
  });
}