import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/root_back_scope.dart';
import '../../adoption_match/screens/discover_screen.dart';
import '../../adoption_match/screens/swipe_match_screen.dart';
import '../../chat/screens/chat_inbox_screen.dart';
import '../../community/screens/happy_tails_feed_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../core/repositories/chat_repository.dart';

class MainNavScreen extends StatefulWidget {
  final StatefulNavigationShell? navigationShell;

  const MainNavScreen({super.key, this.navigationShell});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;
  bool _isNavVisible = true;
  int _unreadChatCount = 0;
  StreamSubscription? _chatSub;

  final List<Widget> _screens = const [
    DiscoverScreen(),
    SwipeMatchScreen(),
    ChatInboxScreen(),
    HappyTailsFeedScreen(),
    ProfileScreen(),
  ];

  int get _activeTabIndex => widget.navigationShell?.currentIndex ?? _currentIndex;

  void _onTabSelected(int index) {
    if (widget.navigationShell != null) {
      widget.navigationShell!.goBranch(
        index,
        initialLocation: index == widget.navigationShell!.currentIndex,
      );
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
    setState(() => _isNavVisible = true);
  }

  @override
  void initState() {
    super.initState();
    _loadUnreadChats();
    _chatSub = ChatRepository().conversationsStream.listen((_) {
      _loadUnreadChats();
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadChats() async {
    final count = await ChatRepository().getTotalUnreadCount();
    if (mounted) setState(() => _unreadChatCount = count);
  }

  bool _handleScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse) {
      if (_isNavVisible) {
        setState(() => _isNavVisible = false);
      }
    } else if (notification.direction == ScrollDirection.forward) {
      if (!_isNavVisible) {
        setState(() => _isNavVisible = true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    const primaryBrand = Color(0xFFE05626);
    const inactiveColor = Color(0xFF94A3B8);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final activeIndex = _activeTabIndex;

    final Widget bodyContent = widget.navigationShell ??
        IndexedStack(
          index: _currentIndex,
          children: _screens,
        );

    return RootBackScope(
      currentTabIndex: activeIndex,
      onSwitchToHomeTab: () => _onTabSelected(0),
      child: Scaffold(
        extendBody: true,
        body: NotificationListener<UserScrollNotification>(
          onNotification: _handleScrollNotification,
          child: bodyContent,
        ),
        bottomNavigationBar: isKeyboardOpen
            ? const SizedBox.shrink()
            : AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                offset: _isNavVisible ? Offset.zero : const Offset(0, 1.5),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavItem(
                            index: 0,
                            icon: Icons.home_rounded,
                            label: 'Home',
                            activeColor: primaryBrand,
                            inactiveColor: inactiveColor,
                          ),
                          _buildNavItem(
                            index: 1,
                            icon: Icons.favorite_border_rounded,
                            activeIcon: Icons.favorite_rounded,
                            label: 'Match',
                            activeColor: const Color(0xFFE11D48),
                            inactiveColor: inactiveColor,
                          ),
                          _buildNavItem(
                            index: 2,
                            icon: Icons.chat_bubble_outline_rounded,
                            activeIcon: Icons.chat_bubble_rounded,
                            label: 'Chat',
                            activeColor: const Color(0xFF6366F1),
                            inactiveColor: inactiveColor,
                            badgeCount: _unreadChatCount,
                          ),
                          _buildNavItem(
                            index: 3,
                            icon: Icons.pets_outlined,
                            activeIcon: Icons.pets_rounded,
                            label: 'Feed',
                            activeColor: primaryBrand,
                            inactiveColor: inactiveColor,
                          ),
                          _buildNavItem(
                            index: 4,
                            icon: Icons.person_outline_rounded,
                            activeIcon: Icons.person_rounded,
                            label: 'Profile',
                            activeColor: primaryBrand,
                            inactiveColor: inactiveColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    IconData? activeIcon,
    required String label,
    required Color activeColor,
    required Color inactiveColor,
    int badgeCount = 0,
  }) {
    final isSelected = _activeTabIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? (activeIcon ?? icon) : icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE11D48),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
