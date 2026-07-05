import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:truck_account_book/core/theme/app_theme.dart';
import 'package:truck_account_book/features/auth/auth_provider.dart';
import 'package:truck_account_book/features/settings/backup_service.dart';
import 'package:truck_account_book/features/settings/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final pinConfigured = ref.watch(pinConfiguredProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionLabel('Security'),
          pinConfigured.when(
            data: (hasPin) => ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(hasPin ? 'Change PIN' : 'Set PIN'),
              trailing: hasPin
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.pendingRed),
                      tooltip: 'Remove PIN lock',
                      onPressed: () => _confirmRemovePin(context, ref),
                    )
                  : null,
              onTap: () => hasPin
                  ? _showChangePinDialog(context, ref)
                  : _showSetPinDialog(context, ref),
            ),
            loading: () => const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('PIN settings'),
            ),
            error: (_, __) => ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Set PIN'),
              onTap: () => _showSetPinDialog(context, ref),
            ),
          ),
          const Divider(height: 1),
          const _SectionLabel('Data'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup Database'),
            subtitle: const Text('Save or share your account book file'),
            onTap: () async {
              try {
                await BackupService.backup();
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Backup created')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore Database'),
            subtitle: const Text('Replace current data from a backup file'),
            onTap: () => _confirmRestore(context),
          ),
          const Divider(height: 1),
          const _SectionLabel('Appearance'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            value: themeMode == ThemeMode.dark,
            onChanged: (v) => ref.read(themeModeProvider.notifier).toggle(v),
          ),
          const Divider(height: 1),
          const _SectionLabel('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About App'),
            onTap: () => _showAbout(context),
          ),
        ],
      ),
    );
  }

  void _showSetPinDialog(BuildContext context, WidgetRef ref) {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Set PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'New PIN'),
              ),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: AppColors.pendingRed)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                if (newCtrl.text.length != 4 || newCtrl.text != confirmCtrl.text) {
                  setState(() => error = 'PIN must be 4 digits and match confirmation');
                  return;
                }
                await ref.read(authServiceProvider).setPin(newCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('PIN set')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, WidgetRef ref) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Change PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'Current PIN'),
              ),
              TextField(
                controller: newCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'New PIN'),
              ),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'Confirm New PIN'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: AppColors.pendingRed)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final auth = ref.read(authServiceProvider);
                if (newCtrl.text.length != 4 || newCtrl.text != confirmCtrl.text) {
                  setState(() => error = 'New PIN must be 4 digits and match confirmation');
                  return;
                }
                final ok = await auth.verifyPin(currentCtrl.text);
                if (!ok) {
                  setState(() => error = 'Current PIN is incorrect');
                  return;
                }
                await auth.setPin(newCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('PIN updated')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemovePin(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove PIN lock?'),
        content: const Text('The app will no longer require a PIN to open.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(authServiceProvider).deletePin();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('PIN lock removed')));
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _confirmRestore(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore database?'),
        content: const Text(
          'This will replace all current trips, customers, expenses, and payments with the backup file you choose. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final restored = await BackupService.restore();
              if (context.mounted && restored) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx2) => AlertDialog(
                    title: const Text('Restore complete'),
                    content: const Text('Please close and reopen the app to load the restored data.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('OK')),
                    ],
                  ),
                );
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) async {
    String version = '1.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
    } catch (_) {
      // Fine to fall back to the hardcoded version if plugin isn't wired
      // up yet on a given platform during early development.
    }
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'Truck Account Book',
      applicationVersion: version,
      applicationIcon: const Icon(Icons.local_shipping, color: AppColors.primaryBlue, size: 40),
      children: const [
        SizedBox(height: 12),
        Text('A simple digital account book for a single truck owner: '
            'trips, expenses, customer payments, and profit — all in one place, '
            'with no internet connection required.'),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
