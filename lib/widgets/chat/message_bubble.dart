import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_colors.dart';
import '../../services/chat_service.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool showAvatar;
  final VoidCallback? onReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showAvatar = true,
    this.onReply,
  });

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.reply_rounded, color: AppColors.primary),
            title: const Text('رد', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
            onTap: () { Navigator.pop(context); if (onReply != null) onReply!(); },
          ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('حذف الرسالة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(context);
                final id = message['id'].toString();
                await ChatService().deleteMessage(id);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = message['content'] ?? '';
    final mediaUrl = message['media_url'];
    final audioUrl = message['audio_url'];
    final createdAt = DateTime.tryParse(message['created_at'] ?? '') ?? DateTime.now();
    final timeStr = timeago.format(createdAt, locale: 'ar');
    final isDeleted = message['deleted_at'] != null;

    return GestureDetector(
      onLongPress: () => _showActions(context),
      onHorizontalDragEnd: (d) { 
        if (d.primaryVelocity != null && d.primaryVelocity! > 200 && onReply != null) onReply!(); 
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFE6F7F3) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (mediaUrl != null && !isDeleted)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(mediaUrl, fit: BoxFit.cover),
                ),
              if (audioUrl != null && !isDeleted)
                const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 32),
              Text(
                isDeleted ? 'تم حذف هذه الرسالة' : content,
                style: TextStyle(
                  fontFamily: 'Tajawal', 
                  color: isDeleted ? AppColors.textSub : AppColors.text,
                  fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              const SizedBox(height: 4),
              Text(timeStr, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textSub)),
            ],
          ),
        ),
      ),
    );
  }
}
