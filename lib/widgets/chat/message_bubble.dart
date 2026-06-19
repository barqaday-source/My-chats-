import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:timeago/timeago.dart' as timeago;

class MessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool showAvatar;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showAvatar = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final _player = AudioPlayer();
  bool _isPlaying = false;

  String _getFileName(String url) {
    try {
      return Uri.parse(url).pathSegments.last.split('?').first;
    } catch (_) {
      return url.split('/').last;
    }
  }

  Future<void> _deleteMessage() async {
    try {
      final supabase = Supabase.instance.client;
      final msgId = widget.message['id'];
      final imageUrl = widget.message['media_url']?? widget.message['image_url'];
      final audioUrl = widget.message['audio_url']?? widget.message['voice_url'];

      if (imageUrl!= null) {
        try {
          await supabase.storage.from('chat_images').remove([_getFileName(imageUrl)]);
        } catch (_) {}
      }
      if (audioUrl!= null) {
        try {
          await supabase.storage.from('voice_messages').remove([_getFileName(audioUrl)]);
        } catch (_) {}
      }
      try {
        await supabase.from('messages').delete().eq('id', msgId);
      } catch (_) {
        await supabase.from('room_messages').delete().eq('id', msgId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('حذف الرسالة', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
        content: const Text('متأكد تريد تحذف هذه الرسالة؟',
            style: TextStyle(color: Colors.white70, fontFamily: 'Tajawal')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal'))),
          TextButton(
              onPressed: () { Navigator.pop(ctx); _deleteMessage(); },
              child: const Text('حذف', style: TextStyle(color: Colors.red, fontFamily: 'Tajawal'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.message['media_url']?? widget.message['image_url'];
    final audioUrl = widget.message['audio_url']?? widget.message['voice_url'];
    final content = widget.message['content'];
    final senderName = widget.message['sender_name']?? widget.message['username']?? 'مجهول';
    final createdAtRaw = widget.message['created_at'];
    DateTime createdAt;
    try { createdAt = DateTime.parse(createdAtRaw.toString()); } catch (_) { createdAt = DateTime.now(); }

    return GestureDetector(
      onLongPress: widget.isMe? _showDeleteDialog : null,
      child: Align(
        alignment: widget.isMe? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: widget.isMe? const Color(0xFF6C63FF) : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(widget.isMe? 16 : 4),
              bottomRight: Radius.circular(widget.isMe? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isMe)
                Text(senderName,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
              if (!widget.isMe) const SizedBox(height: 4),
              if (imageUrl!= null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 200,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(
                        width: 200, height: 150, color: Colors.white10,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                    errorWidget: (c, u, e) => Container(
                        width: 200, height: 100, color: Colors.white10,
                        child: const Icon(Icons.broken_image, color: Colors.white54)),
                  ),
                ),
              if (audioUrl!= null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () async {
                        if (_isPlaying) {
                          await _player.pause();
                        } else {
                          await _player.play(UrlSource(audioUrl));
                        }
                        setState(() => _isPlaying =!_isPlaying);
                      },
                      icon: Icon(_isPlaying? Icons.pause_circle : Icons.play_circle,
                          color: Colors.white, size: 32),
                    ),
                    const Text('رسالة صوتية',
                        style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
                  ],
                ),
              if (content!= null && content.toString().isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: imageUrl!= null? 8 : 0),
                  child: Text(content.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Tajawal')),
                ),
              const SizedBox(height: 4),
              Text(timeago.format(createdAt, locale: 'ar'),
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontFamily: 'Tajawal')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
