import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truck_account_book/core/theme/app_theme.dart';
import 'package:truck_account_book/features/auth/auth_provider.dart';

/// Full-screen PIN pad shown on every cold launch. Keeps things extremely
/// simple: 4-digit entry, shake-to-reject on wrong PIN, no lockout timers
/// (a single truck owner locking themselves out is worse than the minor
/// security tradeoff).
class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  String _entered = '';
  bool _error = false;

  Future<void> _onDigit(String digit) async {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _error = false;
    });
    if (_entered.length == 4) {
      final ok = await ref.read(authServiceProvider).verifyPin(_entered);
      if (ok) {
        ref.read(isUnlockedProvider.notifier).state = true;
      } else {
        setState(() => _error = true);
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) setState(() => _entered = '');
      }
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Mohsin Material Supplier',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter PIN',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _entered.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? Colors.white : Colors.transparent,
                      border: Border.all(
                        color: _error ? Colors.redAccent : Colors.white,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              if (_error) ...[
                const SizedBox(height: 10),
                const Text('Incorrect PIN', style: TextStyle(color: Colors.redAccent)),
              ],
              const Spacer(flex: 2),
              _NumberPad(onDigit: _onDigit, onBackspace: _onBackspace),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  const _NumberPad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final rows = <List<String>>[
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) return const SizedBox(width: 72, height: 64);
              return _PadButton(
                label: key,
                onTap: () {
                  if (key == '⌫') {
                    onBackspace();
                  } else {
                    onDigit(key);
                  }
                },
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _PadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PadButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 72,
          height: 64,
          child: Center(
            child: label == '⌫'
                ? const Icon(Icons.backspace_outlined, color: Colors.white)
                : Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }
}
