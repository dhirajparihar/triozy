import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';


// === Permission messaging ====================================================

/// Centralized permission error handling and user prompts.
class PermissionCenter {
  PermissionCenter._();

  static const Duration _cooldown = Duration(seconds: 20);
  static final Map<String, DateTime> _lastShownAt = <String, DateTime>{};

  /// Throttles duplicate permission messages by [key].
  static bool _canShow(String key) {
    final now = DateTime.now();
    final last = _lastShownAt[key];
    if (last != null && now.difference(last) < _cooldown) {
      return false;
    }
    _lastShownAt[key] = now;
    return true;
  }

  /// Best-effort check if an error text implies permission denial.
  static bool looksPermissionDenied(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('permission') ||
        raw.contains('denied') ||
        raw.contains('not allowed');
  }

  /// Shows a permission-denied snack bar with optional settings shortcut.
  static Future<void> showDenied(
    BuildContext context, {
    required String key,
    required String message,
    bool allowOpenSettings = true,
  }) async {
    if (!_canShow(key)) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: allowOpenSettings
            ? SnackBarAction(
                label: 'Open Settings',
                onPressed: () async {
                  await openSettings();
                },
              )
            : null,
      ),
    );
  }

  /// Opens app settings (falls back to location settings if needed).
  static Future<void> openSettings() async {
    final opened = await Geolocator.openAppSettings();
    if (!opened) {
      await Geolocator.openLocationSettings();
    }
  }
}
