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
    this.showAvatar = true,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _player.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
  }

  Future<void> _deleteMessage() async {
    try {
      final supabase = Supabase.instance.client;
      final msgId = widget.message['id'];

      // 1. احذف الصورة من Storage لو موجودة
      if (widget.message['image_url']!= null && widget.message['image_url'].toString().isNotEmpty) {
        try {
          final imagePath = Uri.parse(widget.message['image_url']).pathSegments.last;
          await supabase.storage.from('chat_images').remove([imagePath]);
        } catch (_) {}
      }

      // 2. احذف الصوت من Storage لو موجود
      if (widget.message['voice_url']!= null && widget.message['voice_url'].toString().isNotEmpty) {
        try {
          final voicePath = Uri.parse(widget.message['voice_url']).pathSegments.last;
          await supabase.storage.from('chat_images').remove([voicePath]);
        } catch (_) {}
      }

      // 3. احذف الرسالة من الجدول
      await supabase.from('messages').delete().eq('id', msgId);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحذف: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الرسالة', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
        content: const Text('متأكد تريد تحذف هذه الرسالة؟ لا يمكن التراجع',
          style: TextStyle(color: Colors.white70, fontFamily: 'Tajawal')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white70)),
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.message['content']!= null && widget.message['content'].toString().trim().isNotEmpty;
    final hasImage = widget.message['image_url']!= null && widget.message['image_url'].toString().isNotEmpty;
    final hasVoice = widget.message['voice_url']!= null && widget.message['voice_url'].toString().isNotEmpty;

    return GestureDetector(
      onLongPress: widget.isMe? _showDeleteDialog : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: Row(
          mainAxisAlignment: widget.isMe? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // أفتار للطرف الثاني
            if (!widget.isMe)
              widget.showAvatar
               ? CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF6C63FF),
                    backgroundImage: widget.message['avatar_url']!= null
                     ? NetworkImage(widget.message['avatar_url'])
                       : null,
                    child: widget.message['avatar_url'] == null
                     ? Text(
                          widget.message['username']?[0].toUpperCase()?? '?',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        )
                       : null,
                  )
                 : const SizedBox(width: 32),

            const SizedBox(width: 8),

            // الفقاعة
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.isMe? const Color(0xFF6C63FF) : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(widget.isMe? 18 : 4),
                    bottomRight: Radius.circular(widget.isMe? 4 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم المرسل للطرف الثاني
                    if (!widget.isMe && widget.showAvatar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          widget.message['username']?? 'مجهول',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ),

                    // صورة
                    if (hasImage)
                      Padding(
                        padding: EdgeInsets.only(bottom: hasText || hasVoice? 8 : 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: widget.message['image_url'],
                            width: 220,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(
                              width: 220,
                              height: 150,
                              color: Colors.white10,
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (c, u, e) => Container(
                              width: 220,
                              height: 150,
                              color: Colors.white10,
                              child: const Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        ),
                      ),

                    // صوت
                    if (hasVoice)
                      Container(
                        width: 220,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        margin: EdgeInsets.only(bottom: hasText? 8 : 0),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () async {
                                if (_isPlaying) {
                                  await _player.pause();
                                } else {
                                  await _player.play(UrlSource(widget.message['voice_url']));
                                }
                              },
                              icon: Icon(
                                _isPlaying? Icons.pause_circle_filled : Icons.play_circle_filled,
                                color: Colors.white,
                                size: 32,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LinearProgressIndicator(
                                    value: _duration.inSeconds > 0
                                     ? _position.inSeconds / _duration.inSeconds
                                       : 0,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 10,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // نص
                    if (hasText)
                      Text(
                        widget.message['content'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontFamily: 'Tajawal',
                          height: 1.3,
                        ),
                      ),

                    // الوقت
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeago.format(DateTime.parse(widget.message['created_at']), locale: 'ar'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        if (widget.isMe)...[
                          const SizedBox(width: 4),
                          Icon(Icons.done_all, size: 14, color: Colors.white.withOpacity(0.5)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // مساحة للأفتار مالتي
            if (widget.isMe) const SizedBox(width: 32),
          ],
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
