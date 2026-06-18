class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final String type; // 'text' 'voice' 'image'
  final String? audioUrl;
  final String? fileUrl;
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
      id: json['id']?? '',
      chatId: json['chat_id']?? '',
      senderId: json['sender_id']?? '',
      receiverId: json['receiver_id']?? '',
      senderName: json['sender_name']?? '',
      senderAvatar: json['sender_avatar'],
      content: json['content']?? '',
      type: json['type']?? 'text',
      audioUrl: json['audio_url'],
      fileUrl: json['file_url'],
      duration: json['duration'],
      replyToId: json['reply_to_id'],
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['is_read']?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
      'content': content,
      'type': type,
      'audio_url': audioUrl,
      'file_url': fileUrl,
      'duration': duration,
      'reply_to_id': replyToId,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? receiverId,
    String? senderName,
    String? senderAvatar,
    String? content,
    String? type,
    String? audioUrl,
    String? fileUrl,
    int? duration,
    String? replyToId,
    DateTime? createdAt,
    bool? isRead,
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
