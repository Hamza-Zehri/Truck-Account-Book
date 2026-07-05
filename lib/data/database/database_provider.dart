import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truck_account_book/data/database/app_database.dart';

/// Single shared instance of the Drift database for the whole app.
/// Kept alive for the app's lifetime (no autoDispose) since every feature
/// depends on it.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
