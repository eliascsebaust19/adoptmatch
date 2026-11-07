import 'package:flutter/foundation.dart';

class NotificationService {
  /// Displays a notification to the user or dispatches local system notification
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    debugPrint(
      '[NotificationService] Notification Triggered: "$title" - "$body"',
    );
  }
}
