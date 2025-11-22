import 'dart:io';
import 'dart:async';

/// Custom exception for line counting errors
class LineCountingException implements Exception {
  final String message;
  final String? filePath;
  final Exception? cause;

  const LineCountingException(this.message, {this.filePath, this.cause});

  @override
  String toString() {
    final buffer = StringBuffer('LineCountingException: $message');
    if (filePath != null) buffer.write(' (file: $filePath)');
    if (cause != null) buffer.write(' (cause: $cause)');
    return buffer.toString();
  }
}

/// Service for counting lines in Dart files within a project directory.
/// 
/// This service traverses project directories to find .dart files and counts
/// the total number of lines, including empty lines and comments. It handles
/// file read errors gracefully by skipping problematic files and continuing
/// with the analysis.
class LineCounterService {
  static const int _maxRetryAttempts = 3;
  static const int _retryDelayMs = 50;
  /// Counts the total number of lines in all .dart files within the specified project path.
  /// 
  /// [projectPath] The root directory path to search for .dart files
  /// Returns the total number of lines across all .dart files found
  /// 
  /// Throws [ArgumentError] if projectPath is null or empty
  /// Throws [DirectoryNotFoundException] if the project directory doesn't exist
  /// Throws [LineCountingException] if directory traversal fails completely
  Future<int> countLinesInDartFiles(String projectPath) async {
    if (projectPath.isEmpty) {
      throw ArgumentError('Project path cannot be empty');
    }

    final projectDir = Directory(projectPath);
    if (!await projectDir.exists()) {
      throw DirectoryNotFoundException('Project directory not found: $projectPath');
    }

    int totalLines = 0;
    int filesProcessed = 0;
    int filesSkipped = 0;
    
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        totalLines = 0;
        filesProcessed = 0;
        filesSkipped = 0;
        
        await for (final entity in projectDir.list(recursive: true, followLinks: false)) {
          if (entity is File && isDartFile(entity.path)) {
            try {
              final lineCount = await _countLinesInFileWithRetry(entity.path);
              totalLines += lineCount;
              filesProcessed++;
            } catch (e) {
              // Skip files that cannot be read and continue with analysis
              // This handles permission errors, encoding issues, etc.
              _logWarning('Could not read file ${entity.path}: $e');
              filesSkipped++;
              continue;
            }
          }
        }
        
        _logInfo('Line counting completed: $filesProcessed files processed, $filesSkipped files skipped, $totalLines total lines');
        return totalLines;
        
      } on FileSystemException catch (e) {
        _logWarning('Directory traversal error (attempt $attempt/$_maxRetryAttempts): $e');
        if (attempt == _maxRetryAttempts) {
          throw LineCountingException(
            'Failed to traverse project directory after $attempt attempts',
            filePath: projectPath,
            cause: e,
          );
        }
        await _delayRetry(attempt);
      } catch (e) {
        _logWarning('Unexpected error during line counting (attempt $attempt/$_maxRetryAttempts): $e');
        if (attempt == _maxRetryAttempts) {
          throw LineCountingException(
            'Line counting failed after $attempt attempts',
            filePath: projectPath,
            cause: e is Exception ? e : Exception(e.toString()),
          );
        }
        await _delayRetry(attempt);
      }
    }
    
    return totalLines; // Should never reach here due to throws above
  }

  /// Counts the number of lines in a specific file.
  /// 
  /// [filePath] The path to the file to count lines in
  /// Returns the number of lines in the file (including empty lines and comments)
  /// 
  /// Throws [FileSystemException] if the file cannot be read
  Future<int> countLinesInFile(String filePath) async {
    final file = File(filePath);
    
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    try {
      final contents = await file.readAsString();
      return _countLinesInContent(contents);
    } on FileSystemException catch (e) {
      throw FileSystemException('Could not read file: ${e.message}', filePath);
    } catch (e) {
      throw FileSystemException('Could not read file: $e', filePath);
    }
  }

  /// Counts lines in file with retry logic for transient errors
  Future<int> _countLinesInFileWithRetry(String filePath) async {
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        return await countLinesInFile(filePath);
      } on FileSystemException catch (e) {
        // Check if this is a transient error worth retrying
        if (_isTransientError(e) && attempt < _maxRetryAttempts) {
          _logWarning('Transient error reading file $filePath (attempt $attempt/$_maxRetryAttempts): ${e.message}');
          await _delayRetry(attempt);
          continue;
        }
        rethrow; // Non-transient error or max attempts reached
      } catch (e) {
        if (attempt == _maxRetryAttempts) {
          rethrow;
        }
        _logWarning('Error reading file $filePath (attempt $attempt/$_maxRetryAttempts): $e');
        await _delayRetry(attempt);
      }
    }
    
    throw FileSystemException('Failed to read file after $_maxRetryAttempts attempts', filePath);
  }

  /// Counts lines in content string
  int _countLinesInContent(String contents) {
    if (contents.isEmpty) {
      return 0;
    }
    
    // Split by line endings and count all lines (including empty ones)
    final lines = contents.split(RegExp(r'\r\n|\r|\n'));
    
    // If the file ends with a newline, split will create an empty string at the end
    // We should not count this as an additional line
    if (lines.isNotEmpty && lines.last.isEmpty) {
      return lines.length - 1;
    }
    
    return lines.length;
  }

  /// Checks if an error is transient and worth retrying
  bool _isTransientError(FileSystemException e) {
    final message = e.message.toLowerCase();
    
    // Common transient errors that might resolve on retry
    return message.contains('temporarily unavailable') ||
           message.contains('resource temporarily unavailable') ||
           message.contains('device or resource busy') ||
           message.contains('sharing violation') ||
           message.contains('lock') ||
           message.contains('in use');
  }

  /// Delays retry with exponential backoff
  Future<void> _delayRetry(int attempt) async {
    final delayMs = _retryDelayMs * (1 << (attempt - 1)); // Exponential backoff
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  /// Logs warning messages (replace with proper logging framework in production)
  void _logWarning(String message) {
    // TODO: Replace with proper logging framework
    print('WARNING [LineCounterService]: $message');
  }

  /// Logs info messages (replace with proper logging framework in production)
  void _logInfo(String message) {
    // TODO: Replace with proper logging framework
    print('INFO [LineCounterService]: $message');
  }

  /// Determines if a file is a Dart file based on its extension.
  /// 
  /// [filePath] The path to the file to check
  /// Returns true if the file has a .dart extension, false otherwise
  bool isDartFile(String filePath) {
    return filePath.toLowerCase().endsWith('.dart');
  }
}

/// Exception thrown when a directory is not found.
class DirectoryNotFoundException implements Exception {
  final String message;
  
  const DirectoryNotFoundException(this.message);
  
  @override
  String toString() => 'DirectoryNotFoundException: $message';
}