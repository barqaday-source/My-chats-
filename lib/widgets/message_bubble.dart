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
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _isPlaying = false; _position = Duration.zero; });
    });
  }

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

      // 1. احذف الصورة من Storage لو موجودة
      final imageUrl = widget.message['media_url'];
      if (imageUrl!= null) {
        final imagePath = _getFileName(imageUrl);
        await supabase.storage.from('chat_images').remove([imagePath]);
      }

      // 2. احذف الصوت من Storage لو موجود
      final audioUrl = widget.message['audio_url'];
      if (audioUrl!= null) {
        final voicePath = _getFileName(audioUrl);
        await supabase.storage.from('voice_messages').remove([voicePath]);
      }

      // 3. احذف الرسالة - جرب messages ثم room_messages
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.message['media_url'];
    final audioUrl = widget.message['audio_url'];
    final content = widget.message['content'];
    final senderName = widget.message['sender_name']?? widget.message['username']?? 'مجهول';
    final createdAtRaw = widget.message['created_at'];

    DateTime createdAt;
    try {
      createdAt = DateTime.parse(createdAtRaw.toString());
    } catch (_) {
      createdAt = DateTime.now();
    }

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
                  senderName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
              if (!widget.isMe) const SizedBox(height: 4),

              // صورة
              if (imageUrl!= null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 200,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(
                      width: 200,
                      height: 150,
                      color: Colors.white10,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (c, u, e) => Container(
                      width: 200, height: 100, color: Colors.white10,
                      child: const Icon(Icons.broken_image, color: Colors.white54),
                    ),
                  ),
                ),

              // صوت
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
                      },
                      icon: Icon(
                        _isPlaying? Icons.pause_circle : Icons.play_circle,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('رسالة صوتية', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 13)),
                        if (_duration.inSeconds > 0)
                          Text(
                            '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                            style: const TextStyle(color: Colors.white54, fontFamily: 'Tajawal', fontSize: 11),
                          ),
                      ],
                    ),
                  ],
                ),

              // نص
              if (content!= null && content.toString().isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: imageUrl!= null? 8 : 0),
                  child: Text(
                    content.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Tajawal'),
                  ),
                ),

              const SizedBox(height: 4),
              Text(
                timeago.format(createdAt, locale: 'ar'),
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
