import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import 'audio_message_widget.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isRoom;
  final VoidCallback? onReply;
  final String? replyToContent;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isRoom = false,
    this.onReply,
    this.replyToContent,
  });

  void _showOptions(BuildContext context) {
    final me = context.read<AuthProvider>().user!;
    final chatService = ChatService();
    final messageId = message['id'] as String;
    final senderId = message['sender_id'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppColors.white),
              title: const Text('رد', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
              onTap: () {
                Navigator.pop(context);
                onReply?.call();
              },
            ),
            if (senderId == me.id)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: AppColors.danger),
                title: const Text('حذف', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger)),
                onTap: () async {
                  Navigator.pop(context);
                  await chatService.deleteMessage(messageId, isRoom);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = message['type'] ?? 'text';
    final replyToId = message['reply_to_id'];

    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // ✅ بوكس الرد
            if (replyToId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: const BoxConstraints(maxWidth: 280),
                decoration: BoxDecoration(
                  color: AppColors.bgCard2.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.reply_rounded, color: AppColors.textSub, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        replyToContent ?? 'رد على رسالة',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.textSub,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // ✅ المحتوى
            _buildContent(type),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(String type) {
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
        constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
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
              color: AppColors.bgCard2,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: AppColors.bgCard2,
              child: const Icon(Icons.error, color: AppColors.white),
            ),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // نص
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: isMe
            ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark])
            : null,
        color: isMe ? null : AppColors.bgCard,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
      ),
      child: Text(
        message['content'] ?? '',
        style: const TextStyle(
          fontFamily: 'Tajawal',
          color: AppColors.white,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }
}
