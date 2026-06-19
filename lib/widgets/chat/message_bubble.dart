import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';

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

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp.toString()).toLocal();
      return DateFormat('h:mm a', 'ar').format(dt);
    } catch (_) {
      return '';
    }
  }

  Future<void> _deleteMessage(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('حذف الرسالة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
        content: const Text('هل تريد حذف هذه الرسالة؟', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف', style: TextStyle(fontFamily: 'Tajawal', color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm!= true) return;
    try {
      await Supabase.instance.client.from('room_messages').delete().eq('id', message['id']);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الرسالة', style: TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e', style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = (message['content']?? '').toString();
    final mediaUrl = message['media_url'] as String?;
    final audioUrl = message['audio_url'] as String?;
    final senderName = (message['sender_name']?? 'مستخدم').toString();
    final senderAvatar = message['sender_avatar'] as String?;
    final timeStr = _formatTime(message['created_at']);
    final replyTo = message['reply_to'] as Map<String, dynamic>?;

    final bubbleColor = isMe? const Color(0xFFD6F5E8) : Colors.white;
    final textColor = const Color(0xFF1A1A1A);
    final timeColor = Colors.black45;

    Widget bubbleContent = Column(
      crossAxisAlignment: isMe? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMe && showAvatar)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(senderName,
                style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF008C6F))),
          ),
        if (replyTo!= null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: const BorderDirectional(start: BorderSide(color: Color(0xFF00C49A), width: 3)),
            ),
            child: Text(
              replyTo['content']?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.black54),
            ),
          ),
        if (mediaUrl!= null && mediaUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: mediaUrl,
              width: 220,
              fit: BoxFit.cover,
              placeholder: (c, u) => Container(
                  width: 220, height: 140,
                  color: Colors.black.withOpacity(0.05),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00C49A)))),
              errorWidget: (c, u, e) => Container(
                  width: 220, height: 140,
                  color: Colors.black.withOpacity(0.05),
                  child: const Icon(Icons.broken_image_rounded, color: Colors.black38)),
            ),
          ),
        if (audioUrl!= null && audioUrl.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.play_arrow_rounded, color: Color(0xFF00C49A)),
                SizedBox(width: 6),
                Text('رسالة صوتية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.black87)),
              ],
            ),
          ),
        if (content.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: (mediaUrl!= null || audioUrl!= null)? 6 : 0),
            child: Text(content,
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 15, color: textColor, height: 1.4)),
          ),
        const SizedBox(height: 4),
        Text(timeStr,
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: timeColor)),
      ],
    );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe? 18 : 4),
          bottomRight: Radius.circular(isMe? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: bubbleContent,
    );

    return GestureDetector(
      onLongPress: () => _deleteMessage(context),
      onDoubleTap: onReply,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment: isMe? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && showAvatar)
              Padding(
                padding: const EdgeInsets.only(right: 6, left: 0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE6F7F1),
                  backgroundImage: senderAvatar!= null && senderAvatar.isNotEmpty
                     ? CachedNetworkImageProvider(senderAvatar)
                      : null,
                  child: senderAvatar == null || senderAvatar.isEmpty
                     ? Text(senderName.isNotEmpty? senderName[0] : '?',
                          style: const TextStyle(fontFamily: 'Tajawal', color: Color(0xFF008C6F), fontWeight: FontWeight.w700))
                      : null,
                ),
              ),
            if (!isMe &&!showAvatar) const SizedBox(width: 38),
            Flexible(child: bubble),
          ],
        ),
      ),
    );
  }
}
