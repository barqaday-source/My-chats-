import 'user_model.dart';

class ChatModel {
  final String id;
  final UserModel peer;
  final String? lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;

  ChatModel({
    required this.id,
    required this.peer,
    this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id']?? '',
      peer: UserModel.fromJson(json['peer']?? {}),
      lastMessage: json['last_message'],
      lastMessageTime: DateTime.parse(json['last_message_time']),
      unreadCount: json['unread_count']?? 0,
    );
  }
}
