class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final String type; // 'text' 'image' 'audio'
  final String? audioUrl;
  final String? fileUrl; // maps to media_url in DB
  final int? duration;
  final String? replyToId;
  final DateTime createdAt;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.type,
    this.audioUrl,
    this.fileUrl,
    this.duration,
    this.replyToId,
    required this.createdAt,
    this.isRead = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id']?.toString()?? '',
      chatId: json['chat_id']?? '',
      senderId: json['sender_id']?? '',
      receiverId: json['receiver_id']?? '',
      senderName: json['sender_name']?? '',
      senderAvatar: json['sender_avatar'],
      content: json['content']?? '',
      type: json['type']?? 'text',
      audioUrl: json['audio_url'],
      fileUrl: json['media_url']?? json['file_url'],
      duration: json['duration'],
      replyToId: json['reply_to']?? json['reply_to_id'],
      createdAt: json['created_at']!= null? DateTime.parse(json['created_at']) : DateTime.now(),
      isRead: json['is_read']?? false,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'chat_id': chatId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'type': type,
      'media_url': fileUrl,
      'audio_url': audioUrl,
      'reply_to': replyToId,
      'is_read': isRead,
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }

  MessageModel copyWith({
    String? id, String? chatId, String? senderId, String? receiverId,
    String? senderName, String? senderAvatar, String? content, String? type,
    String? audioUrl, String? fileUrl, int? duration, String? replyToId,
    DateTime? createdAt, bool? isRead,
  }) {
    return MessageModel(
      id: id?? this.id,
      chatId: chatId?? this.chatId,
      senderId: senderId?? this.senderId,
      receiverId: receiverId?? this.receiverId,
      senderName: senderName?? this.senderName,
      senderAvatar: senderAvatar?? this.senderAvatar,
      content: content?? this.content,
      type: type?? this.type,
      audioUrl: audioUrl?? this.audioUrl,
      fileUrl: fileUrl?? this.fileUrl,
      duration: duration?? this.duration,
      replyToId: replyToId?? this.replyToId,
      createdAt: createdAt?? this.createdAt,
      isRead: isRead?? this.isRead,
    );
  }
}
