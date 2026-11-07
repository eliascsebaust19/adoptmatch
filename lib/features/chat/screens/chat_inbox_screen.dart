import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../../core/models/chat_message_model.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../shared/widgets/shared_widgets.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final _chatRepo = ChatRepository();
  StreamSubscription<List<ChatConversation>>? _sub;
  List<ChatConversation> _conversations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Unread', 'Shelters'

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _sub = _chatRepo.conversationsStream.listen((convs) {
      if (mounted) {
        setState(() {
          _conversations = convs;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final convs = await _chatRepo.getConversations();
    if (mounted) {
      setState(() {
        _conversations = convs;
        _isLoading = false;
      });
    }
  }

  List<ChatConversation> get _filteredConversations {
    return _conversations.where((c) {
      if (_selectedFilter == 'Unread' && c.unreadCount == 0) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesPet = c.petName.toLowerCase().contains(query);
        final matchesShelter = c.shelterName.toLowerCase().contains(query);
        final matchesMsg = c.lastMessage.toLowerCase().contains(query);
        return matchesPet || matchesShelter || matchesMsg;
      }
      return true;
    }).toList();
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${time.day}/${time.month}';
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);

    final totalUnread = _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
    final authState = context.watch<AuthBloc>().state;
    final isGuest = authState is Authenticated && authState.user.role.isGuest;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Direct Messages', style: TextStyle(fontWeight: FontWeight.w800)),
            if (totalUnread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalUnread',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: teal))
          : Column(
              children: [
                if (isGuest)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      border: Border(bottom: BorderSide(color: Color(0xFFFDE68A))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Guest Demo Mode: Live shelter messaging is restricted. Sign in to chat directly with verified rescues.',
                            style: TextStyle(color: Color(0xFF92400E), fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => context.push('/auth/login'),
                          child: const Text('Sign In', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                // Privacy Protection Relay Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFEFF6FF),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_outlined, size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Privacy Shield Active: Personal phone numbers are masked. All chat history is encrypted and monitored for ethical adoption welfare.',
                          style: TextStyle(color: Color(0xFF1E40AF), fontSize: 11, fontWeight: FontWeight.w600, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search by pet, shelter, or message...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: teal, width: 1.5),
                      ),
                    ),
                  ),
                ),

                // Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: ['All', 'Unread', 'Shelters'].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter == 'Unread' ? 'Unread ($totalUnread)' : filter),
                          selected: isSelected,
                          selectedColor: const Color(0xFFCCFBF1),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF475569),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: (_) => setState(() => _selectedFilter = filter),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Divider(height: 12, color: Color(0xFFE2E8F0)),

                // Conversations List
                Expanded(
                  child: _filteredConversations.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: AppEmptyState(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: _searchQuery.isNotEmpty ? 'No conversations matching "$_searchQuery"' : 'No conversations yet',
                              message: 'Click "Chat with Shelter" on any pet profile to start a direct inquiry.',
                              actionText: 'Discover Pets',
                              onAction: () => context.go('/home'),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: _filteredConversations.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, indent: 84, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final conv = _filteredConversations[index];
                            final hasUnread = conv.unreadCount > 0;

                            return InkWell(
                              onTap: () async {
                                await _chatRepo.markConversationAsRead(conv.id);
                                if (!context.mounted) return;
                                context.push('/chat/${conv.id}');
                              },
                              child: Container(
                                color: hasUnread ? const Color(0xFFF0FDFA) : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Pet & Shelter Avatar with Online Dot
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: SizedBox(
                                            width: 54,
                                            height: 54,
                                            child: AppNetworkImage(
                                              imageUrl: conv.petImageUrl,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        if (conv.isOnline)
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 13,
                                              height: 13,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 14),

                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        conv.petName,
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
                                                          color: slateDark,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '• ${conv.shelterName}',
                                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                _formatTime(conv.lastMessageTime),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                                                  color: hasUnread ? teal : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  conv.lastMessage,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: hasUnread ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                                                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (hasUnread)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 8),
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: teal,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    '${conv.unreadCount}',
                                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
