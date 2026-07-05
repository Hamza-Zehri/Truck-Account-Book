import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truck_account_book/core/constants/app_constants.dart';
import 'package:truck_account_book/data/database/app_database.dart';

/// Backup/Restore for the whole SQLite database file. This is a
/// deliberately low-tech approach (copy the .sqlite file) so a truck
/// owner can back up to their phone's storage or share it via WhatsApp,
/// email, etc. without any cloud account.
class BackupService {
  BackupService._();

  /// Directory where daily auto-backups are saved.
  static Future<Directory> getBackupRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'Mohsin Material Supplier backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Returns today's backup file name, e.g. `backup_2026-07-05.sqlite`.
  static String _todayFileName() {
    final now = DateTime.now();
    final ds = '${now.year}-${_two(now.month)}-${_two(now.day)}';
    return 'backup_$ds.sqlite';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Checks if a daily backup has already been created. Uses both
  /// SharedPreferences and file existence to be safe.
  static Future<bool> isTodayBackedUp() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(PrefsKeys.lastBackupDate);
    final today = _todayFileName();
    if (lastDate != today) return false;
    final dir = await getBackupRoot();
    return File(p.join(dir.path, today)).exists();
  }

  /// Called on app start. Creates a daily backup if one hasn't been made
  /// yet today.
  static Future<void> dailyAutoBackup() async {
    try {
      if (await isTodayBackedUp()) return;
      final dbFile = await getDatabaseFile();
      if (!await dbFile.exists()) return;
      final dir = await getBackupRoot();
      final dest = File(p.join(dir.path, _todayFileName()));
      await dbFile.copy(dest.path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.lastBackupDate, _todayFileName());
    } catch (_) {
      // Silently fail — daily backup is best-effort.
    }
  }

  /// Copies the latest daily backup to a user-visible location (Downloads
  /// on Android, Desktop elsewhere) via share sheet so the user can save
  /// it wherever they want.
  static Future<void> saveToDownloads() async {
    final dir = await getBackupRoot();
    final entries = await dir.list().toList();
    entries.sort((a, b) => b.path.compareTo(a.path));
    if (entries.isEmpty) throw Exception('No backups found.');
    final latest = entries.first;
    await Share.shareXFiles(
      [XFile(latest.path)],
      text: 'Mohsin Material Supplier - database backup',
    );
  }

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
      await Share.shareXFiles([XFile(dbFile.path)], text: 'Mohsin Material Supplier backup');
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
