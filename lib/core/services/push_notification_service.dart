import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';

// ── Push Notification Token Registration Service ─────────────────────────────

/// Caches the device push token locally and synchronizes it with `/auth/fcm-token`.
class PushNotificationService {
  static final PushNotificationService instance =
      PushNotificationService._internal();
  factory PushNotificationService() => instance;
  PushNotificationService._internal();

  final ApiClient _apiClient = ApiClient();
  static const String _fcmTokenPrefKey = 'user_fcm_device_token';

  /// Registers or updates the device push token with the AdoptMatch API.
  Future<bool> registerDeviceToken(String fcmToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenPrefKey, fcmToken);

      final response = await _apiClient.dio.post(
        '/auth/fcm-token',
        data: {'fcm_token': fcmToken},
      );

      debugPrint(
        '[PushNotificationService] Token registered successfully: ${response.data}',
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[PushNotificationService] Token sync notice: $e');
      return false;
    }
  }

  /// Get locally cached device token
  Future<String?> getSavedDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fcmTokenPrefKey);
  }

  /// Initialize device notifications (handles Android, iOS, and Web/Desktop fallbacks)
  Future<void> initialize() async {
    try {
      final savedToken = await getSavedDeviceToken();
      if (savedToken != null && savedToken.isNotEmpty) {
        // Automatically sync with backend if user is logged in
        final authToken = await ApiClient.getToken();
        if (authToken != null && authToken.isNotEmpty) {
          await registerDeviceToken(savedToken);
        }
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Initialization notice: $e');
    }
  }
}
