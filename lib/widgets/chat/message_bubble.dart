import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import 'audio_message_widget.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message; // غيرناه من MessageModel
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final type = message['type'] ?? 'text';

    // صوت
    if (type == 'voice' && message['audio_url'] != null) {
      return AudioMessageWidget(
        audioUrl: message['audio_url'],
        duration: message['duration'] ?? 0,
        isMe: isMe,
      );
    }

    // صورة
    if (type == 'image' && message['media_url'] != null) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 250),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: message['media_url'],
            placeholder: (context, url) => Container(
              height: 200,
              color: AppColors.bgCard,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: AppColors.bgCard,
              child: const Icon(Icons.error),
            ),
          ),
        ),
      );
    }

    // نص
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary : AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message['content'] ?? '',
        style: const TextStyle(
          fontFamily: 'Tajawal',
          color: AppColors.white,
          fontSize: 15,
        ),
      ),
    );
  }
}
