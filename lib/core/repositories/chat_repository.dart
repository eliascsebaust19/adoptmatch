import 'dart:async';
import '../models/chat_message_model.dart';
import '../models/pet_model.dart';
import '../services/local_storage_service.dart';

class ChatRepository {
  static final ChatRepository _instance = ChatRepository._internal();
  factory ChatRepository() => _instance;
  ChatRepository._internal() {
    _init();
  }

  final _storage = LocalStorageService.instance;
  final _conversationsStreamController = StreamController<List<ChatConversation>>.broadcast();
  final Map<String, StreamController<List<ChatMessage>>> _messageStreamControllers = {};

  Stream<List<ChatConversation>> get conversationsStream => _conversationsStreamController.stream;

  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    if (!_messageStreamControllers.containsKey(conversationId)) {
      _messageStreamControllers[conversationId] = StreamController<List<ChatMessage>>.broadcast();
    }
    return _messageStreamControllers[conversationId]!.stream;
  }

  List<ChatConversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messages = {};
  bool _initialized = false;

  final List<ChatConversation> _defaultConversations = [
    ChatConversation(
      id: 'c-001',
      petId: 'p1',
      petName: 'Luna',
      petBreed: 'Lab Mix',
      petImageUrl: 'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_1.jpg',
      shelterName: 'Dhaka Animal Rescue',
      shelterPhoneMasked: '+880 17•• •••124',
      lastMessage: 'Hello Elias! We reviewed your adoption inquiry for Luna. Would you like to schedule a virtual meet-and-greet?',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 25)),
      unreadCount: 1,
      isPhoneMasked: true,
      isOnline: true,
    ),
    ChatConversation(
      id: 'c-002',
      petId: 'p2',
      petName: 'Mochi',
      petBreed: 'Calico Cat',
      petImageUrl: 'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_4.jpg',
      shelterName: 'Care For Paws BD',
      shelterPhoneMasked: '+880 18•• •••891',
      lastMessage: 'How is Mochi adjusting to the trial foster arrangement?',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 3)),
      unreadCount: 0,
      isPhoneMasked: true,
      isOnline: false,
    ),
    ChatConversation(
      id: 'c-003',
      petId: 'p3',
      petName: 'Cooper',
      petBreed: 'Golden Retriever Pup',
      petImageUrl: 'https://3kht7mdtcvdag9ff.private.blob.vercel-storage.com/pets/pet_6.jpg',
      shelterName: 'Pawfect Shelter BD',
      shelterPhoneMasked: '+880 19•• •••442',
      lastMessage: 'Can you confirm if your yard has a secured perimeter fence?',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
      isPhoneMasked: true,
      isOnline: true,
    ),
  ];

  final Map<String, List<ChatMessage>> _defaultMessages = {
    'c-001': [
      ChatMessage(
        id: 'm1',
        conversationId: 'c-001',
        senderId: 'shelter',
        senderName: 'Dhaka Animal Rescue',
        text: 'Hello Elias! Thank you for expressing interest in adopting Luna.',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        isFromUser: false,
        deliveryStatus: MessageDeliveryStatus.read,
      ),
      ChatMessage(
        id: 'm2',
        conversationId: 'c-001',
        senderId: 'user',
        senderName: 'Elias Ahmed',
        text: 'Hi! Luna seems like an incredible match for our home. Is she comfortable around young kids?',
        timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
        isFromUser: true,
        deliveryStatus: MessageDeliveryStatus.read,
      ),
      ChatMessage(
        id: 'm3',
        conversationId: 'c-001',
        senderId: 'shelter',
        senderName: 'Dhaka Animal Rescue',
        text: 'Yes! She was fostered in a home with two toddlers and was exceptionally patient, calm, and sweet.',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
        isFromUser: false,
        deliveryStatus: MessageDeliveryStatus.read,
      ),
      ChatMessage(
        id: 'm4',
        conversationId: 'c-001',
        senderId: 'shelter',
        senderName: 'Dhaka Animal Rescue',
        text: 'Hello Elias! We reviewed your adoption inquiry for Luna. Would you like to schedule a virtual meet-and-greet?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        isFromUser: false,
        deliveryStatus: MessageDeliveryStatus.delivered,
      ),
    ],
    'c-002': [
      ChatMessage(
        id: 'm201',
        conversationId: 'c-002',
        senderId: 'shelter',
        senderName: 'Care For Paws BD',
        text: 'Welcome to Mochi\'s adoption foster channel. All medical records are available in her Health Passport.',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        isFromUser: false,
        deliveryStatus: MessageDeliveryStatus.read,
      ),
      ChatMessage(
        id: 'm202',
        conversationId: 'c-002',
        senderId: 'user',
        senderName: 'Elias Ahmed',
        text: 'She has been eating well and sleeping peacefully in her cat tree!',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        isFromUser: true,
        deliveryStatus: MessageDeliveryStatus.read,
      ),
      ChatMessage(
        id: 'm203',
        conversationId: 'c-002',
        senderId: 'shelter',
        senderName: 'Care For Paws BD',
        text: 'How is Mochi adjusting to the trial foster arrangement?',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        isFromUser: false,
        deliveryStatus: MessageDeliveryStatus.read,
      ),
    ],
    'c-003': [
      ChatMessage(
        id: 'm301',
        conversationId: 'c-003',
        senderId: 'shelter',
        senderName: 'Pawfect Shelter BD',
        text: 'Hi Elias! Thanks for inquiring about Cooper the Golden Retriever pup.',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        isFromUser: false,
        deliveryStatus: MessageDeliveryStatus.read,
      ),
      ChatMessage(
        id: 'm302',
        conversationId: 'c-003',
        senderId: 'shelter',
        senderName: 'Pawfect Shelter BD',
        text: 'Can you confirm if your yard has a secured perimeter fence?',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isFromUser: false,
        deliveryStatus: MessageDeliveryStatus.read,
      ),
    ],
  };

  Future<void> _init() async {
    if (_initialized) return;
    final savedConvs = await _storage.loadConversations();
    if (savedConvs != null && savedConvs.isNotEmpty) {
      _conversations = savedConvs;
    } else {
      _conversations = List.from(_defaultConversations);
      await _storage.saveConversations(_conversations);
    }

    for (final conv in _conversations) {
      final savedMsgs = await _storage.loadMessages(conv.id);
      if (savedMsgs != null && savedMsgs.isNotEmpty) {
        _messages[conv.id] = savedMsgs;
      } else if (_defaultMessages.containsKey(conv.id)) {
        _messages[conv.id] = List.from(_defaultMessages[conv.id]!);
        await _storage.saveMessages(conv.id, _messages[conv.id]!);
      } else {
        _messages[conv.id] = [];
      }
    }

    _initialized = true;
    _conversationsStreamController.add(List.unmodifiable(_conversations));
  }

  Future<List<ChatConversation>> getConversations() async {
    if (!_initialized) await _init();
    return List.unmodifiable(_conversations);
  }

  Future<ChatConversation?> getConversationById(String conversationId) async {
    if (!_initialized) await _init();
    try {
      return _conversations.firstWhere((c) => c.id == conversationId);
    } catch (_) {
      return null;
    }
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    if (!_initialized) await _init();
    final msgs = _messages[conversationId] ?? [];
    return List.unmodifiable(msgs);
  }

  Future<ChatConversation> getOrCreateConversationForPet(Pet pet) async {
    if (!_initialized) await _init();

    // Check if conversation already exists for this pet
    final existingIndex = _conversations.indexWhere((c) => c.petId == pet.id);
    if (existingIndex != -1) {
      return _conversations[existingIndex];
    }

    // Create new conversation
    final newConvId = 'c-${pet.id}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final initialGreeting = 'Hello! Thank you for your interest in ${pet.name} (${pet.breed}). Our adoption coordinator at ${pet.shelterName} is here to assist you!';

    final newConv = ChatConversation(
      id: newConvId,
      petId: pet.id,
      petName: pet.name,
      petBreed: pet.breed,
      petImageUrl: pet.imageUrl,
      shelterName: pet.shelterName,
      shelterPhoneMasked: '+880 17•• •••${pet.id.padLeft(3, '0')}',
      lastMessage: initialGreeting,
      lastMessageTime: DateTime.now(),
      unreadCount: 0,
      isPhoneMasked: true,
      isOnline: true,
    );

    final initialMessage = ChatMessage(
      id: 'm-init-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: newConvId,
      senderId: 'shelter',
      senderName: pet.shelterName,
      text: initialGreeting,
      timestamp: DateTime.now(),
      isFromUser: false,
      deliveryStatus: MessageDeliveryStatus.read,
    );

    _conversations.insert(0, newConv);
    _messages[newConvId] = [initialMessage];

    await _storage.saveConversations(_conversations);
    await _storage.saveMessages(newConvId, _messages[newConvId]!);

    _conversationsStreamController.add(List.unmodifiable(_conversations));
    _notifyMessagesChanged(newConvId);

    return newConv;
  }

  Future<ChatMessage> sendMessage(
    String conversationId,
    String text, {
    String? attachmentUrl,
  }) async {
    if (!_initialized) await _init();

    final userMsg = ChatMessage(
      id: 'm-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: 'user',
      senderName: 'Elias Ahmed',
      text: text,
      timestamp: DateTime.now(),
      isFromUser: true,
      deliveryStatus: MessageDeliveryStatus.sent,
      attachmentUrl: attachmentUrl,
    );

    _messages.putIfAbsent(conversationId, () => []).add(userMsg);
    _updateConversationLastMessage(conversationId, text, DateTime.now(), incrementUnread: false);

    await _storage.saveMessages(conversationId, _messages[conversationId]!);
    _notifyMessagesChanged(conversationId);

    // Fast deliver status transition
    Timer(const Duration(milliseconds: 300), () {
      final idx = _messages[conversationId]?.indexWhere((m) => m.id == userMsg.id) ?? -1;
      if (idx != -1) {
        _messages[conversationId]![idx] = _messages[conversationId]![idx].copyWith(
          deliveryStatus: MessageDeliveryStatus.delivered,
        );
        _notifyMessagesChanged(conversationId);
      }
    });

    // Auto-generate contextual shelter response
    Timer(const Duration(milliseconds: 1400), () async {
      final conv = await getConversationById(conversationId);
      final petName = conv?.petName ?? 'this pet';
      final shelter = conv?.shelterName ?? 'Shelter Committee';

      String replyText = 'Thank you for your message! Our adoption coordinator is reviewing your inquiry and will follow up shortly.';
      final lower = text.toLowerCase();

      if (lower.contains('available') || lower.contains('pete pari')) {
        replyText = 'Yes! $petName is currently available for adoption and waiting for a loving home.';
      } else if (lower.contains('kid') || lower.contains('child') || lower.contains('family')) {
        replyText = '$petName has been temperament tested and gets along wonderfully with respectful family members and children.';
      } else if (lower.contains('visit') || lower.contains('meet') || lower.contains('dekhte')) {
        replyText = 'We would love to arrange a visit! Our shelter is open daily 10 AM - 5 PM. You can also submit an adoption application to begin the official process.';
      } else if (lower.contains('vaccine') || lower.contains('health') || lower.contains('sick') || lower.contains('treatment')) {
        replyText = 'All vaccinations (Rabies, DHPP) and preventive deworming are up-to-date. You can view the full Health Passport in the app profile.';
      } else if (lower.contains('diet') || lower.contains('food') || lower.contains('eat')) {
        replyText = '$petName is currently on a balanced, vet-recommended diet of high-protein kibble supplemented with boiled chicken and broth.';
      }

      final shelterReply = ChatMessage(
        id: 'm-reply-${DateTime.now().millisecondsSinceEpoch}',
        conversationId: conversationId,
        senderId: 'shelter',
        senderName: shelter,
        text: replyText,
        timestamp: DateTime.now(),
        isFromUser: false,
        deliveryStatus: MessageDeliveryStatus.read,
      );

      _messages[conversationId]?.add(shelterReply);
      _updateConversationLastMessage(conversationId, replyText, DateTime.now(), incrementUnread: false);

      await _storage.saveMessages(conversationId, _messages[conversationId]!);
      _notifyMessagesChanged(conversationId);
    });

    return userMsg;
  }

  void _updateConversationLastMessage(
    String conversationId,
    String lastText,
    DateTime time, {
    bool incrementUnread = false,
  }) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      final old = _conversations[idx];
      _conversations[idx] = old.copyWith(
        lastMessage: lastText,
        lastMessageTime: time,
        unreadCount: incrementUnread ? old.unreadCount + 1 : old.unreadCount,
      );
      // Bring conversation to top of list
      final item = _conversations.removeAt(idx);
      _conversations.insert(0, item);
      _storage.saveConversations(_conversations);
      _conversationsStreamController.add(List.unmodifiable(_conversations));
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1 && _conversations[idx].unreadCount > 0) {
      _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
      await _storage.saveConversations(_conversations);
      _conversationsStreamController.add(List.unmodifiable(_conversations));
    }
  }

  Future<int> getTotalUnreadCount() async {
    return _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
  }

  void _notifyMessagesChanged(String conversationId) {
    if (_messageStreamControllers.containsKey(conversationId)) {
      _messageStreamControllers[conversationId]!.add(List.unmodifiable(_messages[conversationId] ?? []));
    }
  }

  void dispose() {
    _conversationsStreamController.close();
    for (final ctrl in _messageStreamControllers.values) {
      ctrl.close();
    }
  }
}
