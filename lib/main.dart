import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truck_account_book/app.dart';
import 'package:truck_account_book/features/settings/backup_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  // Daily auto-backup (best-effort, runs in background before first frame).
  BackupService.dailyAutoBackup();
  runApp(const ProviderScope(child: MohsinMaterialApp()));
}
