import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'usage_models.dart';

extension DateOnlyCompare on DateTime {
  bool isSameDate(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  DateTime get dateOnly => DateTime(year, month, day);
}

/// Custom exception for storage-related errors
class StorageException implements Exception {
  final String message;
  final String? filePath;
  final Exception? cause;

  const StorageException(this.message, {this.filePath, this.cause});

  @override
  String toString() {
    final buffer = StringBuffer('StorageException: $message');
    if (filePath != null) buffer.write(' (file: $filePath)');
    if (cause != null) buffer.write(' (cause: $cause)');
    return buffer.toString();
  }
}

/// Custom exception for storage corruption
class StorageCorruptionException extends StorageException {
  const StorageCorruptionException(super.message,
      {super.filePath, super.cause});
}

/// Custom exception for permission issues
class StoragePermissionException extends StorageException {
  const StoragePermissionException(super.message,
      {super.filePath, super.cause});
}

/// Service for managing local storage of usage statistics
class UsageStorageService {
  static const String _storageFileName = 'usage.json';
  static const String _appDirectoryName = '.conalyz';
  static const String _fallbackDirectoryName =
      '.conalyz_usage.json';
  static const int _maxRetryAttempts = 3;
  static const int _retryDelayMs = 100;

  String? _cachedStorageFilePath;
  final List<String> _attemptedPaths = [];

  /// Constructor that allows overriding storage path for testing
  UsageStorageService({String? testStoragePath}) {
    _cachedStorageFilePath = testStoragePath;
  }

  /// Checks if the daily file limit has been reached
  /// Returns null if the limit hasn't been reached, otherwise returns an error message
  /// NOTE: Daily limit is currently disabled (unlimited)
  Future<String?> checkDailyLimit(int filesToAnalyze) async {
    // Daily limit disabled for now - unlimited analysis
    return null;

    /* Commented out for unlimited analysis
    try {
      final storageData = await _loadStorageData();
      final today = DateTime.now().dateOnly;
      
      // Calculate total files analyzed today
      int filesAnalyzedToday = storageData.records
          .where((record) => record.analysisDate.isSameDate(today))
          .fold(0, (sum, record) => sum + record.filesAnalyzed);
      
      if (filesAnalyzedToday + filesToAnalyze > dailyFileLimit) {
        return 'Daily file analysis limit of $dailyFileLimit files reached. Please try again tomorrow.';
      }
      
      return null;
    } catch (e) {
      // If there's an error checking the limit, allow the analysis to proceed
      _logWarning('Error checking daily limit: $e');
      return null;
    }
    */
  }

  /// Records a new usage session
  Future<void> recordUsage(UsageRecord record) async {
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        final storageData = await _loadStorageData();
        final updatedData = storageData.addRecord(record);
        await _saveStorageDataWithRetry(updatedData);
        return; // Success, exit retry loop
      } on StoragePermissionException catch (e) {
        _logWarning(
            'Permission error recording usage data (attempt $attempt/$_maxRetryAttempts): $e');
        if (attempt == _maxRetryAttempts) {
          await _tryFallbackStorageLocation();
          // Try one more time with fallback location
          try {
            final storageData = await _loadStorageData();
            final updatedData = storageData.addRecord(record);
            await _saveStorageDataWithRetry(updatedData);
            return;
          } catch (_) {
            _logWarning(
                'Failed to record usage data even with fallback location');
            return; // Give up gracefully
          }
        }
        await _delayRetry(attempt);
      } on StorageCorruptionException catch (e) {
        _logWarning(
            'Storage corruption detected (attempt $attempt/$_maxRetryAttempts): $e');
        await _handleStorageCorruption();
        if (attempt == _maxRetryAttempts) {
          _logWarning(
              'Failed to recover from storage corruption after $attempt attempts');
          return; // Give up gracefully
        }
        await _delayRetry(attempt);
      } catch (e) {
        _logWarning(
            'Unexpected error recording usage data (attempt $attempt/$_maxRetryAttempts): $e');
        if (attempt == _maxRetryAttempts) {
          _logWarning('Failed to record usage data after $attempt attempts');
          return; // Give up gracefully - analysis should continue
        }
        await _delayRetry(attempt);
      }
    }
  }

  /// Retrieves aggregated usage statistics
  Future<UsageStatistics> getUsageStatistics() async {
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        final storageData = await _loadStorageDataWithRecovery();
        return UsageStatistics.fromRecords(storageData.records);
      } on StorageCorruptionException catch (e) {
        _logWarning(
            'Storage corruption detected while loading statistics (attempt $attempt/$_maxRetryAttempts): $e');
        await _handleStorageCorruption();
        if (attempt == _maxRetryAttempts) {
          _logWarning(
              'Failed to recover statistics after $attempt attempts, returning empty statistics');
          break;
        }
        await _delayRetry(attempt);
      } on StoragePermissionException catch (e) {
        _logWarning(
            'Permission error loading statistics (attempt $attempt/$_maxRetryAttempts): $e');
        if (attempt == _maxRetryAttempts) {
          await _tryFallbackStorageLocation();
          // Try one more time with fallback
          try {
            final storageData = await _loadStorageDataWithRecovery();
            return UsageStatistics.fromRecords(storageData.records);
          } catch (_) {
            _logWarning(
                'Failed to load statistics even with fallback location');
            break;
          }
        }
        await _delayRetry(attempt);
      } catch (e) {
        _logWarning(
            'Unexpected error loading statistics (attempt $attempt/$_maxRetryAttempts): $e');
        if (attempt == _maxRetryAttempts) {
          _logWarning('Failed to load statistics after $attempt attempts');
          break;
        }
        await _delayRetry(attempt);
      }
    }

    // Return empty statistics if all attempts failed
    return const UsageStatistics(
      totalLinesScanned: 0,
      totalSessions: 0,
      firstUsage: null,
      lastUsage: null,
      averageLinesPerSession: 0.0,
      recentSessions: [],
    );
  }

  /// Gets the path to the storage file with comprehensive fallback strategy
  Future<String> getStorageFilePath() async {
    if (_cachedStorageFilePath != null) {
      // Verify cached path is still accessible
      if (await _canUseStorageLocation(path.dirname(_cachedStorageFilePath!))) {
        return _cachedStorageFilePath!;
      } else {
        // Cached path is no longer accessible, clear it and find new one
        _cachedStorageFilePath = null;
        _attemptedPaths.clear();
      }
    }

    final fallbackLocations = await _getFallbackStorageLocations();

    for (final location in fallbackLocations) {
      if (_attemptedPaths.contains(location)) {
        continue; // Skip already attempted paths
      }

      _attemptedPaths.add(location);

      try {
        if (await _canUseStorageLocationWithRecovery(path.dirname(location))) {
          _cachedStorageFilePath = location;
          return location;
        }
      } catch (e) {
        _logWarning(
            'Storage location unavailable: ${e.toString().split(':').first}');
        continue;
      }
    }

    // If all fallback locations fail, use emergency temp location
    final emergencyPath = path.join(Directory.systemTemp.path,
        'conalyz_usage_emergency.json');
    _cachedStorageFilePath = emergencyPath;
    _logWarning('Using fallback storage location');
    return emergencyPath;
  }

  /// Gets ordered list of fallback storage locations
  Future<List<String>> _getFallbackStorageLocations() async {
    final locations = <String>[];

    // Primary location: ~/.conalyz/usage.json
    final homeDir = _getHomeDirectory();
    if (homeDir != null) {
      locations.add(path.join(homeDir, _appDirectoryName, _storageFileName));
    }

    // Secondary location: current directory/.conalyz_usage.json
    final currentDir = Directory.current.path;
    locations.add(path.join(currentDir, _fallbackDirectoryName));

    // Tertiary location: user's documents directory (if available)
    if (homeDir != null) {
      final documentsPath =
          path.join(homeDir, 'Documents', 'conalyz_usage.json');
      locations.add(documentsPath);
    }

    // Quaternary location: system temp directory
    final tempDir = Directory.systemTemp.path;
    locations.add(path.join(tempDir, 'conalyz_usage.json'));

    return locations;
  }

  /// Initializes storage by creating necessary directories and files
  Future<void> initializeStorage() async {
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        final filePath = await getStorageFilePath();

        // Create directory if it doesn't exist
        final directory = Directory(path.dirname(filePath));
        if (!directory.existsSync()) {
          try {
            directory.createSync(recursive: true);
          } on FileSystemException catch (e) {
            throw StoragePermissionException(
              'Cannot create storage directory',
              filePath: directory.path,
              cause: e,
            );
          }
        }

        // Create empty storage file if it doesn't exist
        if (!File(filePath).existsSync()) {
          final emptyData = UsageStorageData.empty();
          await _saveStorageDataWithRetry(emptyData);
        } else {
          // Verify existing file is valid
          await _validateStorageFile(File(filePath));
        }

        _logInfo('Storage initialized successfully at: $filePath');
        return; // Success
      } on StoragePermissionException catch (e) {
        _logWarning(
            'Permission error initializing storage (attempt $attempt/$_maxRetryAttempts): $e');
        if (attempt == _maxRetryAttempts) {
          await _tryFallbackStorageLocation();
          // Try one more time with fallback
          try {
            await initializeStorage();
            return;
          } catch (_) {
            _logWarning('Failed to initialize storage even with fallback');
            throw const StorageException(
                'Cannot initialize storage after trying all fallback locations');
          }
        }
        await _delayRetry(attempt);
      } on StorageCorruptionException catch (e) {
        _logWarning(
            'Storage corruption during initialization (attempt $attempt/$_maxRetryAttempts): $e');
        await _handleStorageCorruption();
        if (attempt == _maxRetryAttempts) {
          throw const StorageException(
              'Cannot recover from storage corruption during initialization');
        }
        await _delayRetry(attempt);
      } catch (e) {
        _logWarning(
            'Unexpected error initializing storage (attempt $attempt/$_maxRetryAttempts): $e');
        if (attempt == _maxRetryAttempts) {
          throw StorageException(
              'Failed to initialize storage after $attempt attempts',
              cause: e is Exception ? e : Exception(e.toString()));
        }
        await _delayRetry(attempt);
      }
    }
  }

  /// Loads storage data from file
  Future<UsageStorageData> _loadStorageData() async {
    final filePath = await getStorageFilePath();
    final file = File(filePath);

    if (!file.existsSync()) {
      await initializeStorage();
      return UsageStorageData.empty();
    }

    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return UsageStorageData.empty();
      }

      final jsonData = json.decode(content) as Map<String, dynamic>;
      return UsageStorageData.fromJson(jsonData);
    } on FileSystemException catch (e) {
      throw StoragePermissionException(
        'Cannot read storage file',
        filePath: filePath,
        cause: e,
      );
    } on FormatException catch (e) {
      throw StorageCorruptionException(
        'Storage file contains invalid JSON',
        filePath: filePath,
        cause: e,
      );
    } catch (e) {
      throw StorageCorruptionException(
        'Storage file is corrupted or unreadable',
        filePath: filePath,
        cause: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Loads storage data with automatic corruption recovery
  Future<UsageStorageData> _loadStorageDataWithRecovery() async {
    try {
      return await _loadStorageData();
    } on StorageCorruptionException catch (e) {
      _logWarning('Storage corruption detected, attempting recovery: $e');
      await _handleStorageCorruption();
      // After recovery, try loading again
      return await _loadStorageData();
    }
  }

  /// Saves storage data to file
  Future<void> _saveStorageData(UsageStorageData data) async {
    final filePath = await getStorageFilePath();

    // Ensure directory exists
    final directory = Directory(path.dirname(filePath));
    if (!directory.existsSync()) {
      try {
        directory.createSync(recursive: true);
      } on FileSystemException catch (e) {
        throw StoragePermissionException(
          'Cannot create storage directory',
          filePath: directory.path,
          cause: e,
        );
      }
    }

    try {
      final jsonString = json.encode(data.toJson());

      // Write to temporary file first, then rename for atomic operation
      final tempFile = File('${filePath}_tmp');
      await tempFile.writeAsString(jsonString);

      // Verify the written data is valid
      final verifyContent = await tempFile.readAsString();
      json.decode(verifyContent); // This will throw if JSON is invalid

      // Atomic rename
      await tempFile.rename(filePath);
    } on FileSystemException catch (e) {
      throw StoragePermissionException(
        'Cannot write to storage file',
        filePath: filePath,
        cause: e,
      );
    } catch (e) {
      throw StorageException(
        'Failed to save storage data',
        filePath: filePath,
        cause: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Saves storage data with retry logic
  Future<void> _saveStorageDataWithRetry(UsageStorageData data) async {
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        await _saveStorageData(data);
        return; // Success
      } on StoragePermissionException catch (e) {
        if (attempt == _maxRetryAttempts) {
          rethrow;
        }
        _logWarning(
            'Permission error saving data (attempt $attempt/$_maxRetryAttempts): $e');
        await _delayRetry(attempt);
      } catch (e) {
        if (attempt == _maxRetryAttempts) {
          rethrow;
        }
        _logWarning(
            'Error saving data (attempt $attempt/$_maxRetryAttempts): $e');
        await _delayRetry(attempt);
      }
    }
  }

  /// Checks if we can use a storage location
  Future<bool> _canUseStorageLocation(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);

      // Try to create directory if it doesn't exist
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      // Test write permissions by creating a temporary file
      final testFile = File(path.join(directoryPath, '.test_write_permission'));
      await testFile.writeAsString('test');
      await testFile.delete();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Enhanced version with recovery attempts
  Future<bool> _canUseStorageLocationWithRecovery(String directoryPath) async {
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final directory = Directory(directoryPath);

        // Try to create directory if it doesn't exist
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }

        // Test write permissions by creating a temporary file
        final testFile = File(path.join(directoryPath,
            '.test_write_permission_${DateTime.now().millisecondsSinceEpoch}'));
        await testFile.writeAsString('test');

        // Verify we can read it back
        final content = await testFile.readAsString();
        if (content != 'test') {
          throw Exception('Write verification failed');
        }

        await testFile.delete();
        return true;
      } catch (e) {
        _logWarning(
            'Storage location unavailable (attempt $attempt/2): ${e.toString().split(':').first}');
        if (attempt == 1) {
          // Try to fix common issues on first failure
          await _attemptDirectoryRecovery(directoryPath);
        }
      }
    }
    return false;
  }

  /// Attempts to recover directory access issues
  Future<void> _attemptDirectoryRecovery(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);

      // If directory exists but we can't write, try to fix permissions
      if (directory.existsSync()) {
        // On Unix-like systems, try to fix permissions
        if (!Platform.isWindows) {
          try {
            final result = await Process.run('chmod', ['755', directoryPath]);
            if (result.exitCode == 0) {
              _logInfo('Fixed directory permissions for: $directoryPath');
            }
          } catch (e) {
            // Ignore chmod errors - we'll try other fallbacks
          }
        }
      }
    } catch (e) {
      // Ignore recovery errors
    }
  }

  /// Gets the home directory path
  String? _getHomeDirectory() {
    final homeEnv =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    return homeEnv;
  }

  /// Handles storage corruption with comprehensive recovery
  Future<void> _handleStorageCorruption() async {
    try {
      final filePath = await getStorageFilePath();
      final corruptedFile = File(filePath);

      if (!corruptedFile.existsSync()) {
        _logInfo('Corrupted file no longer exists, creating new storage');
        await initializeStorage();
        return;
      }

      // Create backup with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = '$filePath.corrupted_backup_$timestamp';

      try {
        await corruptedFile.copy(backupPath);
        _logWarning('Corrupted storage file backed up to: $backupPath');
      } catch (e) {
        _logWarning('Failed to backup corrupted file: $e');
      }

      // Try to recover partial data if possible
      UsageStorageData? recoveredData;
      try {
        recoveredData = await _attemptDataRecovery(corruptedFile);
      } catch (e) {
        _logWarning('Data recovery failed: $e');
      }

      // Delete corrupted file
      try {
        await corruptedFile.delete();
      } catch (e) {
        _logWarning('Failed to delete corrupted file: $e');
      }

      // Create new storage with recovered data or empty
      final newData = recoveredData ?? UsageStorageData.empty();
      await _saveStorageDataWithRetry(newData);

      if (recoveredData != null) {
        _logInfo(
            'Storage corruption recovered with ${recoveredData.records.length} records preserved');
      } else {
        _logInfo('Storage corruption recovered with new empty storage');
      }
    } catch (e) {
      _logWarning('Storage corruption recovery failed: $e');
      throw StorageCorruptionException('Cannot recover from storage corruption',
          cause: e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Attempts to recover data from corrupted storage file
  Future<UsageStorageData?> _attemptDataRecovery(File corruptedFile) async {
    try {
      final content = await corruptedFile.readAsString();

      // Try to find valid JSON objects in the content
      final lines = content.split('\n');
      final recoveredRecords = <UsageRecord>[];

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        try {
          // Try to parse individual lines as JSON
          final jsonData = json.decode(line.trim());
          if (jsonData is Map<String, dynamic> &&
              jsonData.containsKey('timestamp')) {
            final record = UsageRecord.fromJson(jsonData);
            recoveredRecords.add(record);
          }
        } catch (e) {
          // Skip invalid lines
          continue;
        }
      }

      if (recoveredRecords.isNotEmpty) {
        return UsageStorageData(
          version: '1.0',
          records: recoveredRecords,
          created: DateTime.now(),
          lastUpdated: DateTime.now(),
        );
      }

      // Try alternative recovery methods
      return await _attemptAlternativeRecovery(content);
    } catch (e) {
      _logWarning('Data recovery attempt failed: $e');
      return null;
    }
  }

  /// Alternative data recovery methods
  Future<UsageStorageData?> _attemptAlternativeRecovery(String content) async {
    try {
      // Try to extract JSON fragments using regex
      final jsonPattern = RegExp(r'\{[^{}]*"timestamp"[^{}]*\}');
      final matches = jsonPattern.allMatches(content);
      final recoveredRecords = <UsageRecord>[];

      for (final match in matches) {
        try {
          final jsonStr = match.group(0);
          if (jsonStr != null) {
            final jsonData = json.decode(jsonStr) as Map<String, dynamic>;
            final record = UsageRecord.fromJson(jsonData);
            recoveredRecords.add(record);
          }
        } catch (e) {
          continue;
        }
      }

      if (recoveredRecords.isNotEmpty) {
        return UsageStorageData(
          version: '1.0',
          records: recoveredRecords,
          created: DateTime.now(),
          lastUpdated: DateTime.now(),
        );
      }
    } catch (e) {
      _logWarning('Alternative recovery failed: $e');
    }

    return null;
  }

  /// Validates storage file integrity
  Future<void> _validateStorageFile(File file) async {
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return; // Empty file is valid
      }

      final jsonData = json.decode(content) as Map<String, dynamic>;
      UsageStorageData.fromJson(jsonData); // This will throw if invalid
    } on FileSystemException catch (e) {
      throw StoragePermissionException(
        'Cannot read storage file for validation',
        filePath: file.path,
        cause: e,
      );
    } on FormatException catch (e) {
      throw StorageCorruptionException(
        'Storage file validation failed - invalid JSON',
        filePath: file.path,
        cause: e,
      );
    } catch (e) {
      throw StorageCorruptionException(
        'Storage file validation failed',
        filePath: file.path,
        cause: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Tries to switch to a fallback storage location
  Future<void> _tryFallbackStorageLocation() async {
    _logWarning('Attempting to switch storage location');
    _cachedStorageFilePath = null; // Clear cached path to force re-evaluation
    _attemptedPaths.clear(); // Clear attempted paths to try alternatives

    // Force re-evaluation of storage path
    await getStorageFilePath();
  }

  /// Delays retry with exponential backoff
  Future<void> _delayRetry(int attempt) async {
    final delayMs = _retryDelayMs * (1 << (attempt - 1)); // Exponential backoff
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  /// Logs warning messages (replace with proper logging framework in production)
  void _logWarning(String message) {
    // TODO: Replace with proper logging framework
  }

  /// Logs info messages (replace with proper logging framework in production)
  void _logInfo(String message) {
    // TODO: Replace with proper logging framework
  }
}
