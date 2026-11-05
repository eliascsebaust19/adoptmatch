import 'package:equatable/equatable.dart';

enum MessageDeliveryStatus {
  sending,
  sent,
  delivered,
  read,
}

class ChatMessage extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isFromUser;
  final MessageDeliveryStatus deliveryStatus;
  final String? attachmentUrl;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isFromUser,
    this.deliveryStatus = MessageDeliveryStatus.read,
    this.attachmentUrl,
  });

  bool get isRead => deliveryStatus == MessageDeliveryStatus.read;

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? timestamp,
    bool? isFromUser,
    MessageDeliveryStatus? deliveryStatus,
    String? attachmentUrl,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isFromUser: isFromUser ?? this.isFromUser,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isFromUser': isFromUser,
      'deliveryStatus': deliveryStatus.name,
      'attachmentUrl': attachmentUrl,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isFromUser: json['isFromUser'] as bool,
      deliveryStatus: MessageDeliveryStatus.values.firstWhere(
        (e) => e.name == json['deliveryStatus'],
        orElse: () => MessageDeliveryStatus.read,
      ),
      attachmentUrl: json['attachmentUrl'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        conversationId,
        senderId,
        senderName,
        text,
        timestamp,
        isFromUser,
        deliveryStatus,
        attachmentUrl,
      ];
}

class ChatConversation extends Equatable {
  final String id;
  final String petId;
  final String petName;
  final String petBreed;
  final String petImageUrl;
  final String shelterName;
  final String shelterPhoneMasked;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isPhoneMasked;
  final bool isOnline;

  const ChatConversation({
    required this.id,
    required this.petId,
    required this.petName,
    required this.petBreed,
    required this.petImageUrl,
    required this.shelterName,
    this.shelterPhoneMasked = '+880 17•• •••567',
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isPhoneMasked = true,
    this.isOnline = true,
  });

  ChatConversation copyWith({
    String? id,
    String? petId,
    String? petName,
    String? petBreed,
    String? petImageUrl,
    String? shelterName,
    String? shelterPhoneMasked,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isPhoneMasked,
    bool? isOnline,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      petName: petName ?? this.petName,
      petBreed: petBreed ?? this.petBreed,
      petImageUrl: petImageUrl ?? this.petImageUrl,
      shelterName: shelterName ?? this.shelterName,
      shelterPhoneMasked: shelterPhoneMasked ?? this.shelterPhoneMasked,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isPhoneMasked: isPhoneMasked ?? this.isPhoneMasked,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'petName': petName,
      'petBreed': petBreed,
      'petImageUrl': petImageUrl,
      'shelterName': shelterName,
      'shelterPhoneMasked': shelterPhoneMasked,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'isPhoneMasked': isPhoneMasked,
      'isOnline': isOnline,
    };
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String,
      petId: json['petId'] as String,
      petName: json['petName'] as String,
      petBreed: json['petBreed'] as String,
      petImageUrl: json['petImageUrl'] as String,
      shelterName: json['shelterName'] as String,
      shelterPhoneMasked: json['shelterPhoneMasked'] as String? ?? '+880 17•• •••567',
      lastMessage: json['lastMessage'] as String,
      lastMessageTime: DateTime.parse(json['lastMessageTime'] as String),
      unreadCount: json['unreadCount'] as int? ?? 0,
      isPhoneMasked: json['isPhoneMasked'] as bool? ?? true,
      isOnline: json['isOnline'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
        id,
        petId,
        petName,
        petBreed,
        petImageUrl,
        shelterName,
        shelterPhoneMasked,
        lastMessage,
        lastMessageTime,
        unreadCount,
        isPhoneMasked,
        isOnline,
      ];
}
