import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:truck_account_book/data/database/app_database.dart';

/// Backup/Restore for the whole SQLite database file. This is a
/// deliberately low-tech approach (copy the .sqlite file) so a truck
/// owner can back up to their phone's storage or share it via WhatsApp,
/// email, etc. without any cloud account.
class BackupService {
  BackupService._();

  /// Copies the live database to a location the user picks, and also
  /// offers the OS share sheet so it can be sent to WhatsApp/email/etc.
  static Future<String?> backup() async {
    final dbFile = await getDatabaseFile();
    if (!await dbFile.exists()) {
      throw Exception('No database found to back up yet.');
    }
    final backupName = 'truck_account_book_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite';

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save backup',
      fileName: backupName,
      bytes: await dbFile.readAsBytes(),
    );

    if (savePath == null) {
      // User cancelled the save dialog - fall back to sharing directly.
      await Share.shareXFiles([XFile(dbFile.path)], text: 'Truck Account Book backup');
      return null;
    }
    return savePath;
  }

  /// Restores the database from a .sqlite file the user picks. Caller is
  /// responsible for prompting the user to restart the app afterwards,
  /// since the live Drift connection needs to be reopened against the
  /// replaced file.
  static Future<bool> restore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sqlite', 'db'],
    );
    if (result == null || result.files.single.path == null) return false;

    final pickedFile = File(result.files.single.path!);
    final dbFile = await getDatabaseFile();
    await pickedFile.copy(dbFile.path);
    return true;
  }
}
