import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/repositories/notification_repository.dart';
import '../../../core/widgets/adoptmatch_back_button.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = NotificationRepository();
  List<AppNotificationItem> _allNotifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final list = await _repo.getNotifications();
    if (mounted) {
      setState(() {
        _allNotifications = list;
        _isLoading = false;
      });
    }
  }

  List<AppNotificationItem> get _filteredList {
    if (_selectedFilter == 'All') return _allNotifications;
    if (_selectedFilter == 'Applications') {
      return _allNotifications.where((n) => n.category == NotificationCategory.application).toList();
    }
    if (_selectedFilter == 'Chat') {
      return _allNotifications.where((n) => n.category == NotificationCategory.chat).toList();
    }
    if (_selectedFilter == 'Health') {
      return _allNotifications.where((n) => n.category == NotificationCategory.care).toList();
    }
    if (_selectedFilter == 'SOS Alerts') {
      return _allNotifications.where((n) => n.category == NotificationCategory.emergency).toList();
    }
    return _allNotifications;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.application:
        return const Color(0xFF0D9488); // Teal
      case NotificationCategory.chat:
        return const Color(0xFF6366F1); // Indigo
      case NotificationCategory.care:
        return const Color(0xFF059669); // Emerald
      case NotificationCategory.emergency:
        return const Color(0xFFE11D48); // Rose
      case NotificationCategory.system:
        return const Color(0xFF64748B); // Slate
    }
  }

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.application:
        return Icons.assignment_turned_in_outlined;
      case NotificationCategory.chat:
        return Icons.chat_bubble_outline_rounded;
      case NotificationCategory.care:
        return Icons.medical_services_outlined;
      case NotificationCategory.emergency:
        return Icons.warning_amber_rounded;
      case NotificationCategory.system:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);

    final unreadCount = _allNotifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const AdoptMatchBackButton(
          fallbackPath: '/home',
        ),
        title: Row(
          children: [
            const Text('Notifications'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount new',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () async {
                await _repo.markAllAsRead();
                _loadNotifications();
              },
              child: const Text('Mark all read', style: TextStyle(color: teal, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: teal))
          : Column(
              children: [
                // Filter Tabs
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: ['All', 'Applications', 'Chat', 'Health', 'SOS Alerts'].map((f) {
                      final isSelected = _selectedFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: isSelected,
                          selectedColor: const Color(0xFFCCFBF1),
                          labelStyle: TextStyle(
                            color: isSelected ? teal : const Color(0xFF475569),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: (_) => setState(() => _selectedFilter = f),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Notifications List
                Expanded(
                  child: _filteredList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 14),
                              const Text(
                                'No notifications in this category',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: slateDark),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'You\'re all caught up! Updates will appear here.',
                                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredList.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final notif = _filteredList[index];
                            final catColor = _getCategoryColor(notif.category);

                            return Dismissible(
                              key: Key(notif.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) {
                                _repo.deleteNotification(notif.id);
                                setState(() {
                                  _allNotifications.removeWhere((n) => n.id == notif.id);
                                });
                              },
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  await _repo.markAsRead(notif.id);
                                  _loadNotifications();
                                  if (notif.targetRoute != null && context.mounted) {
                                    context.push(notif.targetRoute!);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: notif.isRead ? Colors.white : const Color(0xFFF0FDFA),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: notif.isRead ? const Color(0xFFE2E8F0) : const Color(0xFF99F6E4),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: catColor.withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(_getCategoryIcon(notif.category), color: catColor, size: 20),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    notif.title,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                                                      color: slateDark,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  _formatTime(notif.timestamp),
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              notif.body,
                                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!notif.isRead) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(top: 6),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF0D9488),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

