import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:timeago/timeago.dart' as timeago;

class MessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  
  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final _player = AudioPlayer();
  bool _isPlaying = false;

  Future<void> _deleteMessage() async {
    try {
      final supabase = Supabase.instance.client;
      final msgId = widget.message['id'];
      
      // 1. احذف الصورة من Storage لو موجودة
      if (widget.message['image_url']!= null) {
        final imagePath = widget.message['image_url'].split('/').last;
        await supabase.storage.from('chat_images').remove([imagePath]);
      }
      
      // 2. احذف الصوت من Storage لو موجود
      if (widget.message['voice_url']!= null) {
        final voicePath = widget.message['voice_url'].split('/').last;
        await supabase.storage.from('chat_images').remove([voicePath]);
      }
      
      // 3. احذف الرسالة من الجدول
      await supabase.from('messages').delete().eq('id', msgId);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e', style: TextStyle(fontFamily: 'Tajawal'))),
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
        content: const Text('متأكد تريد تحذف هذه الرسالة؟', style: TextStyle(color: Colors.white70, fontFamily: 'Tajawal')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMessage();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                Text(
                  widget.message['username']?? 'مجهول',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
              if (!widget.isMe) const SizedBox(height: 4),
              
              // صورة
              if (widget.message['image_url']!= null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: widget.message['image_url'],
                    width: 200,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(
                      width: 200,
                      height: 150,
                      color: Colors.white10,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
                
              // صوت
              if (widget.message['voice_url']!= null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () async {
                        if (_isPlaying) {
                          await _player.pause();
                        } else {
                          await _player.play(UrlSource(widget.message['voice_url']));
                        }
                        setState(() => _isPlaying =!_isPlaying);
                      },
                      icon: Icon(
                        _isPlaying? Icons.pause_circle : Icons.play_circle,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const Text('رسالة صوتية', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
                  ],
                ),
                
              // نص
              if (widget.message['content']!= null && widget.message['content'].toString().isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: widget.message['image_url']!= null? 8 : 0),
                  child: Text(
                    widget.message['content'],
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Tajawal'),
                  ),
                ),
                
              const SizedBox(height: 4),
              Text(
                timeago.format(DateTime.parse(widget.message['created_at']), locale: 'ar'),
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontFamily: 'Tajawal'),
              ),
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
