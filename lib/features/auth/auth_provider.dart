import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truck_account_book/core/constants/app_constants.dart';

String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();

/// Handles PIN storage/verification. No email, no OTP, no server - just a
/// hashed 4-digit PIN kept in SharedPreferences, per the spec.
class AuthService {
  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(PrefsKeys.pinHash);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(PrefsKeys.pinHash);
    if (storedHash == null) return false;
    return storedHash == _hash(pin);
  }

  Future<void> setPin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.pinHash, _hash(newPin));
  }

  Future<void> deletePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefsKeys.pinHash);
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Whether the app is currently unlocked for this session. Locks again
/// every time the app is fully restarted (kept simple, no biometrics).
final isUnlockedProvider = StateProvider<bool>((ref) => false);

/// Whether a PIN has been configured (persisted in SharedPreferences).
final pinConfiguredProvider = FutureProvider<bool>((ref) async {
  return ref.read(authServiceProvider).hasPin();
});
