import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truck_account_book/app_router.dart';
import 'package:truck_account_book/core/theme/app_theme.dart';
import 'package:truck_account_book/features/auth/auth_provider.dart';
import 'package:truck_account_book/features/auth/pin_lock_screen.dart';
import 'package:truck_account_book/features/settings/settings_provider.dart';

class MohsinMaterialApp extends ConsumerWidget {
  const MohsinMaterialApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinConfigured = ref.watch(pinConfiguredProvider);
    final isUnlocked = ref.watch(isUnlockedProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Wait for SharedPreferences before deciding what to show.
    return pinConfigured.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => _buildApp(themeMode),
      data: (hasPin) {
        if (hasPin && !isUnlocked) {
          return MaterialApp(
            title: 'Mohsin Material Supplier',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            home: const PinLockScreen(),
          );
        }
        return _buildApp(themeMode);
      },
    );
  }

  Widget _buildApp(ThemeMode themeMode) {
    return MaterialApp.router(
      title: 'Mohsin Material Supplier',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
