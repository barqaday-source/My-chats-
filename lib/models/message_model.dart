enum MsgType { text, image, audio }

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String content;
  final MsgType type;
  final String? mediaUrl;
  final String? audioUrl;
  final int? duration;
  final bool isRead;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatar;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.type,
    this.mediaUrl,
    this.audioUrl,
    this.duration,
    this.isRead = false,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      chatId: json['chat_id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id']?? '',
      content: json['content']?? json['text']?? '',
      type: MsgType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MsgType.text,
      ),
      mediaUrl: json['media_url'],
      audioUrl: json['audio_url'],
      duration: json['duration'],
      isRead: json['is_read']?? false,
      createdAt: DateTime.parse(json['created_at']),
      senderName: json['sender_name'],
      senderAvatar: json['sender_avatar'],
    );
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) => MessageModel.fromJson(map);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'type': type.name,
      'media_url': mediaUrl,
      'audio_url': audioUrl,
      'duration': duration,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
    };
  }

  static String generateChatId(String user1, String user2) {
    final sorted = [user1, user2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // Getter للتوافق مع الكود القديم
  String get text => content;
}
