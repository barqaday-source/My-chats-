class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String? senderName;
  final String? senderAvatar;
  final String content;
  final String type;
  final String? mediaUrl;
  final String? audioUrl;
  final int? duration;
  final bool isRead;
  final DateTime createdAt;
  final String? replyToId; // ✅ إضافة فقط

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    this.senderName,
    this.senderAvatar,
    required this.content,
    this.type = 'text',
    this.mediaUrl,
    this.audioUrl,
    this.duration,
    this.isRead = false,
    required this.createdAt,
    this.replyToId, // ✅ إضافة فقط
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      senderName: json['sender_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
      content: json['content'] as String,
      type: json['type'] as String?? 'text',
      mediaUrl: json['media_url'] as String?,
      audioUrl: json['audio_url'] as String?,
      duration: json['duration'] as int?,
      isRead: json['is_read'] as bool?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      replyToId: json['reply_to_id'] as String?, // ✅ إضافة فقط
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // 'id': id, // محذوف سابقاً
      'chat_id': chatId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
      'content': content,
      'type': type,
      'media_url': mediaUrl,
      'audio_url': audioUrl,
      'duration': duration,
      'is_read': isRead,
      'reply_to_id': replyToId, // ✅ إضافة فقط
      'created_at': createdAt.toIso8601String(),
    };
  }
}
