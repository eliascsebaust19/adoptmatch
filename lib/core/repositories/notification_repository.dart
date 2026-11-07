import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationCategory {
  application,
  chat,
  care,
  emergency,
  system,
}

class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime timestamp;
  final bool isRead;
  final String? targetRoute;

  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.isRead = false,
    this.targetRoute,
  });

  AppNotificationItem copyWith({
    bool? isRead,
  }) {
    return AppNotificationItem(
      id: id,
      title: title,
      body: body,
      category: category,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      targetRoute: targetRoute,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'category': category.name,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'targetRoute': targetRoute,
  };

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      category: NotificationCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => NotificationCategory.system,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      targetRoute: json['targetRoute'] as String?,
    );
  }
}

class NotificationRepository {
  static final NotificationRepository _instance = NotificationRepository._internal();
  factory NotificationRepository() => _instance;
  NotificationRepository._internal();

  static const String _storageKey = 'adoptmatch_notifications';
  final _streamController = StreamController<List<AppNotificationItem>>.broadcast();
  Stream<List<AppNotificationItem>> get notificationsStream => _streamController.stream;

  List<AppNotificationItem> _notifications = [];
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final List<dynamic> list = jsonDecode(raw);
        _notifications = list.map((item) => AppNotificationItem.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        _notifications = [];
      }
    } catch (_) {
      _notifications = [];
    }
    _initialized = true;
    _streamController.add(List.unmodifiable(_notifications));
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_notifications.map((n) => n.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  Future<List<AppNotificationItem>> getNotifications() async {
    if (!_initialized) await _init();
    return List.unmodifiable(_notifications);
  }

  Future<int> getUnreadCount() async {
    if (!_initialized) await _init();
    return _notifications.where((n) => !n.isRead).length;
  }

  Future<void> markAsRead(String id) async {
    if (!_initialized) await _init();
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _save();
      _streamController.add(List.unmodifiable(_notifications));
    }
  }

  Future<void> markAllAsRead() async {
    if (!_initialized) await _init();
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    await _save();
    _streamController.add(List.unmodifiable(_notifications));
  }

  Future<void> deleteNotification(String id) async {
    if (!_initialized) await _init();
    _notifications.removeWhere((n) => n.id == id);
    await _save();
    _streamController.add(List.unmodifiable(_notifications));
  }

  Future<void> addNotification({
    required String title,
    required String body,
    required NotificationCategory category,
    String? targetRoute,
  }) async {
    if (!_initialized) await _init();
    final item = AppNotificationItem(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      category: category,
      timestamp: DateTime.now(),
      isRead: false,
      targetRoute: targetRoute,
    );
    _notifications.insert(0, item);
    await _save();
    _streamController.add(List.unmodifiable(_notifications));
  }
}

