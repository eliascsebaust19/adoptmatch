import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_network_image.dart';

import '../../../core/models/pet_model.dart';
import '../../../core/repositories/pet_repository.dart';
import '../../../core/services/ai_assistant_service.dart';
import '../../../core/services/gemini_ai_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  late final GeminiAiService _geminiService;
  final PetRepository _petRepo = PetRepository();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  final List<AiAssistantMessage> _messages = [
    AiAssistantMessage(
      id: 'welcome',
      text:
          '🐾 Hi there! I\'m your AdoptMatch companion.\n\n'
          'I can help you find rescue pets, answer pet care and vaccination questions, or guide you through the adoption process in English বা বাংলায়।\n\n'
          'How can I help you today?',
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  final List<String> _quickPrompts = [
    'Best pets for apartment living',
    'How does adoption process work?',
    'Puppy vaccination chart',
    'Indoor cats for first-time owners',
    'Monthly pet budget in Dhaka',
    'বিড়ালের প্রথম ভ্যাকসিনের বয়স কত?',
  ];

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiAiService();
  }

  void _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMsg = AiAssistantMessage(
      id: 'u-${DateTime.now().millisecondsSinceEpoch}',
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      // 1. Get response from Gemini AI (with smart local fallback)
      final replyText = await _geminiService.sendMessage(trimmed);

      // 2. Discover relevant pet recommendations if user is looking for pets
      List<Pet> recommendedPets = [];
      final normalized = trimmed.toLowerCase();
      if (normalized.contains('apartment') ||
          normalized.contains('flat') ||
          normalized.contains('cat') ||
          normalized.contains('dog') ||
          normalized.contains('puppy') ||
          normalized.contains('kitten') ||
          normalized.contains('adopt') ||
          normalized.contains('rescue') ||
          normalized.contains('বিড়াল') ||
          normalized.contains('কুকুর')) {
        final allPets = await _petRepo.getAllPets();
        if (normalized.contains('cat') ||
            normalized.contains('kitten') ||
            normalized.contains('বিড়াল')) {
          recommendedPets = allPets
              .where((p) => p.species.toLowerCase() == 'cat')
              .take(3)
              .toList();
        } else if (normalized.contains('dog') ||
            normalized.contains('puppy') ||
            normalized.contains('কুকুর')) {
          recommendedPets = allPets
              .where((p) => p.species.toLowerCase() == 'dog')
              .take(3)
              .toList();
        } else if (normalized.contains('apartment') ||
            normalized.contains('flat')) {
          recommendedPets = allPets
              .where((p) => p.isApartmentFriendly)
              .take(3)
              .toList();
        } else {
          recommendedPets = allPets.take(2).toList();
        }
      }

      if (mounted) {
        setState(() {
          _messages.add(
            AiAssistantMessage(
              id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
              text: replyText,
              isUser: false,
              timestamp: DateTime.now(),
              recommendedPets: recommendedPets.isNotEmpty
                  ? recommendedPets
                  : null,
            ),
          );
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(
            AiAssistantMessage(
              id: 'err-${DateTime.now().millisecondsSinceEpoch}',
              text: 'I had trouble processing that request. Please try again or rephrase your question.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF6366F1)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'AdoptMatch AI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: slateDark,
                  ),
                ),
                Text(
                  'Gemini Powered Pet Assistant',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF14B8A6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            tooltip: 'New Conversation',
            onPressed: () {
              _geminiService.resetChat();
              setState(() {
                _messages.clear();
                _messages.add(
                  AiAssistantMessage(
                    id: 'welcome-reset',
                    text: 'Conversation reset. What kind of pet or guidance are you looking for today?',
                    isUser: false,
                    timestamp: DateTime.now(),
                  ),
                );
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Medical & informational disclaimer banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFFEF3C7),
            child: Row(
              children: const [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Color(0xFFD97706),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI advice is informational. In urgent medical cases, visit an emergency vet immediately.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Suggestion Chips (at the top, above messages)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: _quickPrompts
                  .map((prompt) => _buildSuggestionChip(prompt))
                  .toList(),
            ),
          ),

          // 3. Message history list (EXPANDED takes all remaining vertical space)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Typing indicator
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: teal,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'AdoptMatch AI is thinking...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 4. Input Box pinned at the bottom in SafeArea
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        hintText: 'Ask about breeds, care, or adoption...',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    backgroundColor: teal,
                    elevation: 0,
                    onPressed: () => _sendMessage(_textController.text),
                    child: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF0D9488),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFFCCFBF1),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () => _sendMessage(label),
      ),
    );
  }

  Widget _buildMessageBubble(AiAssistantMessage msg) {
    const teal = Color(0xFF0D9488);
    const slateDark = Color(0xFF0F172A);

    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: teal,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                  color: slateDark,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),

            // If AI recommended pets, render interactive cards!
            if (msg.recommendedPets != null &&
                msg.recommendedPets!.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: msg.recommendedPets!.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final pet = msg.recommendedPets![index];
                    return _buildPetRecommendationCard(pet);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPetRecommendationCard(Pet pet) {
    const teal = Color(0xFF0D9488);

    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              width: 160,
              height: 90,
              child: AppNetworkImage(
                imageUrl: pet.imageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        pet.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${pet.matchScore}%',
                      style: const TextStyle(
                        color: teal,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${pet.breed} • ${pet.ageDisplay}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 28,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teal,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => context.push('/pets/${pet.id}'),
                    child: const Text(
                      'View Pet',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
