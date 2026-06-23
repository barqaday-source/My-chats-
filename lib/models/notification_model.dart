import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? imageUrl; // NEW: صورة الإشعار اختيارية

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.imageUrl,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      body: json['body'],
      type: json['type']?? 'general',
      isRead: json['is_read']?? false,
      createdAt: DateTime.parse(json['created_at']),
      imageUrl: json['image_url'], // NEW
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'image_url': imageUrl, // NEW
    };
  }

  @override
  List<Object?> get props => [id, userId, title, body, type, isRead, createdAt, imageUrl];
}
