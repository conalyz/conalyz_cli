import 'dart:io';

/// Command to update the Conalyz CLI to the latest version
class UpdateCommand {
  /// Executes the update process using 'dart pub global activate'
  Future<void> update() async {
    print('🔄 Updating Conalyz CLI to the latest version...');
    print('');

    try {
      final process = await Process.start(
        'dart',
        ['pub', 'global', 'activate', 'conalyz'],
        mode: ProcessStartMode.inheritStdio,
      );

      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        print('\n✅ Conalyz successfully updated to the latest version!');
      } else {
        print('\n❌ Failed to update Conalyz. Exit code: $exitCode');
        exit(exitCode);
      }
    } catch (e) {
      print('\n❌ Error updating Conalyz: $e');
      print('Please try running manually: dart pub global activate conalyz');
      exit(1);
    }
  }
}
