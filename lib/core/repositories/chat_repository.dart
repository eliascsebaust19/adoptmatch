import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message_model.dart';
import '../models/pet_model.dart';
import '../network/api_client.dart';
import '../services/local_storage_service.dart';
import '../storage/secure_storage_service.dart';

/// Server-backed messaging. No timed replies or fabricated delivery receipts.
class ChatRepository {
  static final ChatRepository _instance = ChatRepository._internal();
  factory ChatRepository() => _instance;
  ChatRepository._internal();

  final _storage = LocalStorageService.instance;
  http.Client _client = http.Client();
  Future<String?> Function() _readToken = SecureStorageService.instance.getAuthToken;
  Future<String?> Function() _readUserId = () async =>
      (await SecureStorageService.instance.getUserProfile())?.id;
  String? _ownerId;
  String? lastSyncError;

  void configureForTesting({required http.Client client,
      required Future<String?> Function() tokenReader, String userId = 'test-user'}) {
    _client = client;
    _readToken = tokenReader;
    _readUserId = () async => userId;
    resetForTesting();
  }

  final _conversationsStreamController = StreamController<List<ChatConversation>>.broadcast();
  final Map<String, StreamController<List<ChatMessage>>> _messageStreamControllers = {};
  Stream<List<ChatConversation>> get conversationsStream => _conversationsStreamController.stream;
  List<ChatConversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messages = {};
  bool _initialized = false;
  Future<void>? _initFuture;

  Future<void> _init() {
    if (_initialized) return Future.value();
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    _ownerId = await _readUserId();
    final saved = await _storage.loadConversations();
    _conversations = saved?.where((c) => c.id.startsWith('remote-')).toList() ?? [];
    for (final conv in _conversations) {
      final savedMessages = await _storage.loadMessages(conv.id) ?? [];
      _messages[conv.id] = savedMessages.where((m) =>
          m.senderId != 'system' && !m.id.startsWith('m-reply-')).map((m) =>
          m.deliveryStatus == MessageDeliveryStatus.sending
              ? m.copyWith(deliveryStatus: MessageDeliveryStatus.failed) : m).toList();
    }
    _initialized = true;
    _initFuture = null;
  }

  void resetForTesting() {
    _initialized = false;
    _initFuture = null;
    _ownerId = null;
    _conversations = [];
    _messages.clear();
    lastSyncError = null;
  }

  Future<void> clearCache() async {
    await _storage.clearAllChats();
    resetForTesting();
    _conversationsStreamController.add(const []);
  }

  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    return (_messageStreamControllers[conversationId] ??=
        StreamController<List<ChatMessage>>.broadcast()).stream;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _readToken();
    if (token == null || token.isEmpty) throw Exception('Sign in to use messaging.');
    return {'Accept': 'application/json', 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'};
  }

  Uri _uri(String path) => Uri.parse('${ApiClient.rootUrl}/api/v1$path');
  Never _responseError(http.Response response) {
    String message = 'Messaging request failed (HTTP ${response.statusCode}).';
    try { message = (jsonDecode(response.body)['message'] ?? message).toString(); } catch (_) {}
    throw Exception(message);
  }

  /// Fetch the inbox and real message history, including replies from the shelter.
  Future<void> refreshRemote() async {
    await _init();
    final headers = await _headers();
    final currentOwner = await _readUserId();
    if (currentOwner != _ownerId) { await clearCache(); await _init(); }
    final response = await _client.get(_uri('/messages/conversations'), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) _responseError(response);
    final data = jsonDecode(response.body)['data'];
    if (data is! List) throw Exception('Invalid conversation response.');
    final refreshed = <ChatConversation>[];
    for (final raw in data) {
      final item = Map<String, dynamic>.from(raw as Map);
      final other = Map<String, dynamic>.from(item['other_user'] as Map? ?? {});
      final pet = Map<String, dynamic>.from(item['pet'] as Map? ?? {});
      final id = 'remote-${other['id']}';
      if (other['id'] == null) continue;
      final history = await _client.get(_uri('/messages/${other['id']}'), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (history.statusCode != 200) _responseError(history);
      final rows = jsonDecode(history.body)['data'];
      if (rows is! List) throw Exception('Invalid message history response.');
      final messages = rows.map((row) {
        final m = Map<String, dynamic>.from(row as Map);
        final fromMe = m['sender_id'].toString() == _ownerId;
        return ChatMessage(
          id: m['id'].toString(), conversationId: id,
          senderId: m['sender_id'].toString(),
          senderName: (fromMe ? 'You' : other['name'] ?? 'Shelter').toString(),
          text: (m['message_text'] ?? '').toString(),
          timestamp: DateTime.parse(m['created_at'].toString()), isFromUser: fromMe,
          deliveryStatus: !fromMe || m['is_read'] == true || m['is_read'] == 1
              ? MessageDeliveryStatus.read : MessageDeliveryStatus.sent,
          attachmentUrl: m['attachment_url']?.toString(),
        );
      }).toList();
      refreshed.add(ChatConversation(
        id: id, petId: pet['id']?.toString() ?? '',
        petName: pet['name']?.toString() ?? 'General inquiry',
        petBreed: pet['species']?.toString() ?? '',
        petImageUrl: pet['primary_image_url']?.toString() ?? '',
        shelterName: (other['name'] ?? 'Shelter').toString(),
        shelterUserId: other['id'].toString(), isOnline: false,
        lastMessage: (item['last_message'] ?? '').toString(),
        lastMessageTime: DateTime.parse(item['last_message_time'].toString()),
        unreadCount: (item['unread_count'] as num?)?.toInt() ?? 0,
      ));
      // Preserve only failed drafts; authoritative server history replaces sent copies.
      final failed = (_messages[id] ?? []).where((m) =>
          m.deliveryStatus == MessageDeliveryStatus.failed).toList();
      _messages[id] = [...messages, ...failed];
      await _storage.saveMessages(id, _messages[id]!);
      _notifyMessagesChanged(id);
    }
    _conversations = refreshed;
    await _storage.saveConversations(_conversations);
    _conversationsStreamController.add(List.unmodifiable(_conversations));
    lastSyncError = null;
  }

  Future<List<ChatConversation>> getConversations() async {
    await refreshRemote();
    return List.unmodifiable(_conversations);
  }

  Future<ChatConversation?> getConversationById(String id) async {
    await _init();
    try { return _conversations.firstWhere((c) => c.id == id); } catch (_) { return null; }
  }

  Future<List<ChatMessage>> getMessages(String id) async {
    await refreshRemote();
    return List.unmodifiable(_messages[id] ?? const []);
  }

  Future<ChatConversation> getOrCreateConversationForPet(Pet pet) async {
    await _init();
    final recipient = pet.ownerId;
    if (recipient == null || int.tryParse(recipient) == null || int.tryParse(pet.id) == null) {
      throw Exception('Messaging is available only for published server listings.');
    }
    final id = 'remote-$recipient';
    final existing = await getConversationById(id);
    if (existing != null) return existing;
    final conv = ChatConversation(id: id, petId: pet.id, petName: pet.name,
      petBreed: pet.breed, petImageUrl: pet.imageUrl, shelterName: pet.shelterName,
      shelterUserId: recipient, isOnline: false,
      lastMessage: 'No messages yet. Start the conversation.', lastMessageTime: DateTime.now());
    _conversations.insert(0, conv);
    _messages[id] = [];
    await _storage.saveConversations(_conversations);
    _conversationsStreamController.add(List.unmodifiable(_conversations));
    return conv;
  }

  Future<ChatMessage> sendMessage(String conversationId, String text,
      {String? attachmentUrl, String? senderName}) async {
    await _init();
    final conv = await getConversationById(conversationId);
    final recipient = int.tryParse(conv?.shelterUserId ?? '');
    if (conv == null || recipient == null) throw Exception('This conversation has no server recipient.');
    if (text.trim().isEmpty || text.length > 1000) throw Exception('Messages must contain 1–1000 characters.');
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    var message = ChatMessage(id: localId, conversationId: conversationId,
      senderId: _ownerId ?? 'user', senderName: senderName ?? 'You', text: text,
      timestamp: DateTime.now(), isFromUser: true,
      deliveryStatus: MessageDeliveryStatus.sending, attachmentUrl: attachmentUrl);
    _messages.putIfAbsent(conversationId, () => []).add(message);
    _notifyMessagesChanged(conversationId);
    String? failure;
    try {
      final response = await _client.post(_uri('/messages'), headers: await _headers(),
        body: jsonEncode({'receiver_id': recipient,
          if (int.tryParse(conv.petId) != null) 'pet_id': int.parse(conv.petId),
          'message_text': text, if (attachmentUrl != null) 'attachment_url': attachmentUrl}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 201 && response.statusCode != 200) _responseError(response);
      final data = jsonDecode(response.body)['data'];
      if (data is! Map || data['id'] == null) throw Exception('No server message acknowledgement.');
      message = message.copyWith(id: data['id'].toString(), deliveryStatus: MessageDeliveryStatus.sent);
    } catch (e) {
      failure = e.toString();
      message = message.copyWith(deliveryStatus: MessageDeliveryStatus.failed);
    }
    final messages = _messages[conversationId]!;
    final index = messages.indexWhere((m) => m.id == localId);
    if (index == -1) throw Exception('The conversation cache was cleared during delivery.');
    messages[index] = message;
    final convIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convIndex != -1) _conversations[convIndex] = conv.copyWith(lastMessage: text, lastMessageTime: message.timestamp);
    await _storage.saveMessages(conversationId, messages);
    await _storage.saveConversations(_conversations);
    _notifyMessagesChanged(conversationId);
    _conversationsStreamController.add(List.unmodifiable(_conversations));
    if (failure != null) throw Exception(failure);
    return message;
  }

  Future<ChatMessage> retryFailedMessage(ChatMessage message) async {
    if (message.deliveryStatus != MessageDeliveryStatus.failed) {
      throw Exception('Only failed messages can be retried.');
    }
    final messages = _messages[message.conversationId];
    messages?.removeWhere((m) => m.id == message.id);
    await _storage.saveMessages(message.conversationId, messages ?? const []);
    _notifyMessagesChanged(message.conversationId);
    return sendMessage(message.conversationId, message.text, attachmentUrl: message.attachmentUrl);
  }

  Future<void> markConversationAsRead(String id) async {
    await getMessages(id); // The API marks incoming messages read while fetching history.
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index != -1) _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
    await _storage.saveConversations(_conversations);
    _conversationsStreamController.add(List.unmodifiable(_conversations));
  }

  Future<int> getTotalUnreadCount() async =>
      _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

  void _notifyMessagesChanged(String id) {
    _messageStreamControllers[id]?.add(List.unmodifiable(_messages[id] ?? const []));
  }

  void dispose() {
    _conversationsStreamController.close();
    for (final ctrl in _messageStreamControllers.values) { ctrl.close(); }
    _client.close();
  }
}
