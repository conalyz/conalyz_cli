import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('Update Command CLI Integration', () {
    late String binPath;

    setUpAll(() {
      // Ensure we are calling the bin/conalyz.dart from the project root
      final currentDir = Directory.current.path;
      binPath = path.join(currentDir, 'bin', 'conalyz.dart');
    });

    test('conalyz update --help displays help message', () async {
      final result = await Process.run('dart', [binPath, 'update', '--help']);

      final stdout = result.stdout.toString();
      expect(stdout, contains('Conalyz CLI - Update'));
      expect(stdout, contains('Usage: conalyz update'));
      expect(
          stdout,
          contains(
              'Updates the conalyz CLI to the latest version available on pub.dev.'));
      expect(result.exitCode, 0);
    });

    test('conalyz update -h displays help message', () async {
      final result = await Process.run('dart', [binPath, 'update', '-h']);

      final stdout = result.stdout.toString();
      expect(stdout, contains('Conalyz CLI - Update'));
      expect(result.exitCode, 0);
    });

    test('conalyz update executes successfully', () async {
      // This test actually executes 'dart pub global activate conalyz', which can take a moment depending on the network.
      final result = await Process.run('dart', [binPath, 'update']);

      final stdout = result.stdout.toString();
      expect(
          stdout, contains('🔄 Updating Conalyz CLI to the latest version...'));
      expect(stdout,
          contains('✅ Conalyz successfully updated to the latest version!'));
      expect(result.exitCode, 0);
    },
        timeout: const Timeout(
            Duration(minutes: 2))); // Increased timeout for pub dev fetch
  });
}
