import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_colors.dart';
import '../../services/chat_service.dart';
import 'audio_message_widget.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool showAvatar;
  final VoidCallback? onReply;
  final void Function(String messageId)? onDelete;
  final bool isRoom;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showAvatar = true,
    this.onReply,
    this.onDelete,
    this.isRoom = false,
  });

  Future<void> _handleDelete(BuildContext context) async {
    final id = message['id'].toString();
    final imageUrl = message['image_url']?? message['media_url'];
    final audioUrl = message['audio_url'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('حذف الرسالة؟', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
        content: const Text('سيتم حذف الملف من التخزين أيضا', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء', style: TextStyle(color: AppColors.textSub, fontFamily: 'Tajawal'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف', style: TextStyle(color: AppColors.danger, fontFamily: 'Tajawal'))),
        ],
      ),
    );
    if (ok!= true) return;

    await ChatService().deleteMessage(
      id,
      isRoom: isRoom,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
    );
    if (onDelete!= null) onDelete!(id);
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.reply_rounded, color: AppColors.primary),
            title: const Text('رد', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
            onTap: () { Navigator.pop(context); onReply?.call(); },
          ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('حذف الرسالة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger)),
              onTap: () { Navigator.pop(context); _handleDelete(context); },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _buildReplyPreview() {
    final replyText = message['reply_to_text'] as String?;
    final replyType = message['reply_to_type'] as String??? 'text';
    final replySender = message['reply_to_sender_name'] as String?;
    if (replyText == null || replyText.isEmpty) return const SizedBox.shrink();

    String display = replyText;
    if (replyType == 'image') display = '📷 صورة';
    if (replyType == 'audio') display = '🎤 رسالة صوتية';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe? Colors.white.withOpacity(0.15) : AppColors.bgCard2,
        borderRadius: BorderRadius.circular(8),
        border: Border(right: BorderSide(color: isMe? Colors.white.withOpacity(0.7) : AppColors.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replySender!= null)
            Text(replySender, style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w700, color: isMe? Colors.white.withOpacity(0.9) : AppColors.primary)),
          Text(display, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: isMe? Colors.white.withOpacity(0.8) : AppColors.textSub)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = message['content']?? '';
    final imageUrl = message['image_url']?? message['media_url'];
    final audioUrl = message['audio_url'] as String?;
    final createdAt = DateTime.tryParse(message['created_at']?? '')?? DateTime.now();
    final timeStr = timeago.format(createdAt, locale: 'ar');
    final isDeleted = message['deleted_at']!= null;

    if (audioUrl!= null && audioUrl.isNotEmpty &&!isDeleted) {
      final duration = (message['audio_duration'] as num?)?.toInt()?? (message['duration'] as num?)?.toInt()?? 0;
      return GestureDetector(
        onLongPress: () => _showActions(context),
        onHorizontalDragEnd: (d) { if (d.primaryVelocity!= null && d.primaryVelocity! > 200) onReply?.call(); },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
          child: Column(
            crossAxisAlignment: isMe? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (message['reply_to_text']!= null) SizedBox(width: 280, child: _buildReplyPreview()),
              AudioMessageWidget(audioUrl: audioUrl, duration: duration, isMe: isMe),
              const SizedBox(height: 3),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(timeStr, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textSub))),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showActions(context),
      onHorizontalDragEnd: (d) { if (d.primaryVelocity!= null && d.primaryVelocity! > 200) onReply?.call(); },
      child: Align(
        alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
          child: Column(
            crossAxisAlignment: isMe? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe? 18 : 4),
                    bottomRight: Radius.circular(isMe? 4 : 18),
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReplyPreview(),
                    if (imageUrl!= null &&!isDeleted)
                      Padding(
                        padding: EdgeInsets.only(bottom: content.isNotEmpty? 8 : 0),
                        child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(imageUrl, fit: BoxFit.cover)),
                      ),
                    if (content.isNotEmpty)
                      Text(isDeleted? 'تم حذف هذه الرسالة' : content,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: isDeleted? AppColors.textSub : (isMe? Colors.white : AppColors.text),
                          fontStyle: isDeleted? FontStyle.italic : FontStyle.normal,
                          fontSize: 15, height: 1.4,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(timeStr, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textSub))),
            ],
          ),
        ),
      ),
    );
  }
}
