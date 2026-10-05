import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the one-time receipt photo guide has been shown.
///
/// Key is versioned (`_v1`) so copy can be refreshed in the future without
/// collisions. Fail-open: if storage is unavailable the guide is shown again
/// rather than crashing capture.
class ReceiptPhotoGuidePrefs {
  const ReceiptPhotoGuidePrefs._();

  /// Preference key mirroring `finance_ai.theme_mode` naming style.
  static const guideSeenKey = 'finance_ai.receipt_photo_guide_seen_v1';

  /// Returns true when the guide dialog should be presented.
  ///
  /// [overrides] exists only for widget tests (`SharedPreferences.setMockInitialValues`).
  static Future<bool> shouldShowGuide({SharedPreferences? overrides}) async {
    try {
      final prefs = overrides ?? await SharedPreferences.getInstance();
      return !(prefs.getBool(guideSeenKey) ?? false);
    } catch (_) {
      return true;
    }
  }

  /// Marks the guide as seen so it is only shown once.
  static Future<void> markGuideSeen({SharedPreferences? overrides}) async {
    try {
      final prefs = overrides ?? await SharedPreferences.getInstance();
      await prefs.setBool(guideSeenKey, true);
    } catch (_) {
      // Fail-open: next open will simply show the guide again.
    }
  }

  /// Clears the flag (used in tests / "ver guía de nuevo").
  static Future<void> clear({SharedPreferences? overrides}) async {
    try {
      final prefs = overrides ?? await SharedPreferences.getInstance();
      await prefs.remove(guideSeenKey);
    } catch (_) {}
  }
}
