import 'dart:io';

class FolderPickerService {
  /// Opens a native Windows FolderBrowserDialog to let user select any folder on any drive.
  static Future<String?> pickFolder({
    String title = 'انتخاب پوشه مورد نظر',
  }) async {
    try {
      final safeTitle = title.replaceAll("'", "''");
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-STA',
        '-Command',
        '''
        Add-Type -AssemblyName System.Windows.Forms
        \$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        \$dialog.Description = '$safeTitle'
        \$dialog.ShowNewFolderButton = \$true
        if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            Write-Output \$dialog.SelectedPath
        }
        ''',
      ]);

      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty && Directory(path).existsSync()) {
          return path;
        }
      }
    } catch (_) {}
    return null;
  }
}
