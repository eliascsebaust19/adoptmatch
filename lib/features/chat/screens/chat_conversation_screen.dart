import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/chat_message_model.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/widgets/guest_restriction_dialog.dart';
import '../../../shared/widgets/shared_widgets.dart';

class ChatConversationScreen extends StatefulWidget {
  final String conversationId;

  const ChatConversationScreen({super.key, required this.conversationId});

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _chatRepo = ChatRepository();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<List<ChatMessage>>? _messageSub;
  ChatConversation? _conversation;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;

  final List<String> _quickInquiries = [
    'Is this pet still available for adoption?',
    'Can I schedule a shelter visit or meet-and-greet?',
    'What is the daily diet and feeding schedule?',
    'Has this pet lived with children or other pets?',
  ];

  @override
  void initState() {
    super.initState();
    _loadConversationAndMessages();
  }

  Future<void> _loadConversationAndMessages() async {
    final conv = await _chatRepo.getConversationById(widget.conversationId);
    final msgs = await _chatRepo.getMessages(widget.conversationId);

    if (mounted) {
      setState(() {
        _conversation = conv;
        _messages = List.from(msgs);
        _isLoading = false;
      });
      _scrollToBottom();
    }

    _messageSub = _chatRepo.getMessagesStream(widget.conversationId).listen((
      newMsgs,
    ) {
      if (mounted) {
        setState(() {
          _messages = List.from(newMsgs);
        });
        _scrollToBottom();
      }
    });

    await _chatRepo.markConversationAsRead(widget.conversationId);
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText([String? predefinedText]) async {
    final isRestricted = await GuestRestrictionDialog.checkAndShow(
      context,
      featureName: 'Direct Shelter Messaging',
      customMessage: 'Direct communication with shelter managers is restricted in demo mode. Please sign in or register to message.\n\nসেল্টারের সাথে সরাসরি চ্যাট করতে সাইন ইন করুন।',
    );
    if (isRestricted || !context.mounted) return;

    final text = (predefinedText ?? _textController.text).trim();
    if (text.isEmpty) return;

    if (predefinedText == null) {
      _textController.clear();
    }

    await _chatRepo.sendMessage(widget.conversationId, text);
  }

  void _simulateSendHomePhoto() async {
    final isRestricted = await GuestRestrictionDialog.checkAndShow(
      context,
      featureName: 'Living Space Photo Sharing',
      customMessage: 'Photo sharing with rescues is restricted in demo mode. Please sign in or register.\n\nছবি শেয়ার করতে সাইন ইন করুন।',
    );
    if (isRestricted || !mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share Home / Living Area Photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Share photos of your living space or yard to expedite adoption screening.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFCCFBF1),
                child: Icon(Icons.home, color: Color(0xFF0D9488)),
              ),
              title: const Text('Living Room & Indoor Space'),
              subtitle: const Text('Photo of pet resting area'),
              onTap: () {
                Navigator.of(ctx).pop();
                _chatRepo.sendMessage(
                  widget.conversationId,
                  'Attached: Photo of our indoor living room & dedicated pet bedding area for review.',
                  attachmentUrl: 'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=600&q=80',
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE0E7FF),
                child: Icon(Icons.fence, color: Color(0xFF6366F1)),
              ),
              title: const Text('Fenced Yard / Balcony Area'),
              subtitle: const Text('Verification of perimeter fencing'),
              onTap: () {
                Navigator.of(ctx).pop();
                _chatRepo.sendMessage(
                  widget.conversationId,
                  'Attached: Photo of our secured outdoor balcony netting & safety barrier.',
                  attachmentUrl: 'https://images.unsplash.com/photo-1583847268964-b28dc8f51f92?auto=format&fit=crop&w=600&q=80',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMaskedCallDialog() {
    final conv = _conversation;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.lock_outline, color: Color(0xFF0D9488)),
            SizedBox(width: 8),
            Text('Masked Voice Relay'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connecting call to ${conv?.shelterName ?? 'Shelter'}...'),
            const SizedBox(height: 8),
            Text(
              'Virtual Number: ${conv?.shelterPhoneMasked ?? '+880 17•• •••567'}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your personal phone number remains private. Calls are routed through the AdoptMatch safety exchange.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Calling ${conv?.shelterName} via Masked Relay...',
                  ),
                  backgroundColor: const Color(0xFF0D9488),
                ),
              );
            },
            icon: const Icon(Icons.call, size: 16, color: Colors.white),
            label: const Text(
              'Connect Call',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);

    final conv = _conversation;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 0,
        title: conv == null
            ? const Text('Conversation')
            : Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push('/pet/${conv.petId}'),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: AppNetworkImage(
                          imageUrl: conv.petImageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conv.petName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${conv.shelterName} • Masked 🔒',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF0D9488),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk_rounded, color: teal),
            tooltip: 'Masked Call',
            onPressed: _showMaskedCallDialog,
          ),
          if (conv != null)
            TextButton(
              onPressed: () => context.push('/apply/${conv.petId}'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: teal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: teal))
          : Column(
              children: [
                // Top Pet Quick Access Pill Banner
                if (conv != null)
                  InkWell(
                    onTap: () => context.push('/pet/${conv.petId}'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: Colors.white,
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: teal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Inquiry for ${conv.petName} (${conv.petBreed}). Tap to view full profile & health passport.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: slateDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Messages Stream List
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.isFromUser;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: const Color(0xFFCCFBF1),
                                child: const Icon(
                                  Icons.pets,
                                  size: 16,
                                  color: teal,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.76,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe ? teal : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  border: isMe
                                      ? null
                                      : Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (msg.attachmentUrl != null) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: AppNetworkImage(
                                          imageUrl: msg.attachmentUrl!,
                                          height: 150,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    Text(
                                      msg.text,
                                      style: TextStyle(
                                        color: isMe ? Colors.white : slateDark,
                                        fontSize: 14,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            color: isMe
                                                ? Colors.white.withOpacity(0.75)
                                                : const Color(0xFF94A3B8),
                                            fontSize: 10,
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            msg.deliveryStatus ==
                                                    MessageDeliveryStatus.read
                                                ? Icons.done_all_rounded
                                                : msg.deliveryStatus ==
                                                      MessageDeliveryStatus
                                                          .delivered
                                                ? Icons.done_all_rounded
                                                : Icons.done_rounded,
                                            size: 14,
                                            color:
                                                msg.deliveryStatus ==
                                                    MessageDeliveryStatus.read
                                                ? const Color(0xFF93C5FD)
                                                : Colors.white70,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Quick Inquiries Chips Row
                Container(
                  height: 38,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickInquiries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final inquiry = _quickInquiries[index];
                      return ActionChip(
                        label: Text(
                          inquiry,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF0F766E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: const Color(0xFFF0FDFA),
                        side: const BorderSide(color: Color(0xFF99F6E4)),
                        onPressed: () => _sendText(inquiry),
                      );
                    },
                  ),
                ),

                // Bottom Input Field Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(
                      top: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: teal,
                          ),
                          tooltip: 'Send Living Space Photo',
                          onPressed: _simulateSendHomePhoto,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(
                              fontSize: 14,
                              color: slateDark,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type your message to shelter...',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(
                                  color: teal,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            onSubmitted: (_) => _sendText(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: teal,
                          child: IconButton(
                            icon: const Icon(
                              Icons.send_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                            onPressed: () => _sendText(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
