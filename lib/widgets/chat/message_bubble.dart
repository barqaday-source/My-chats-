import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/app_colors.dart';

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

  Future<void> _deleteMessage() async {
    try {
      final supabase = Supabase.instance.client;
      final msgId = widget.message['id'];
      try {
        await supabase.from('messages').delete().eq('id', msgId);
      } catch (_) {
        await supabase.from('room_messages').delete().eq('id', msgId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الرسالة', style: TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e', style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('حذف الرسالة', style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal')),
        content: const Text('هل تريد حذف هذه الرسالة؟', style: TextStyle(color: AppColors.textSub, fontFamily: 'Tajawal')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMessage();
            },
            child: const Text('حذف', style: TextStyle(color: AppColors.danger, fontFamily: 'Tajawal')),
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

  String _formatTime(dynamic ts) {
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final am = dt.hour < 12 ? 'ص' : 'م';
      return '$h:$m $am';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.message['media_url'];
    final audioUrl = widget.message['audio_url'];
    final content = widget.message['content']?.toString() ?? '';

    final senderName = widget.message['profile_username']
     ?? widget.message['sender_name']
     ?? widget.message['username']
     ?? 'مستخدم';
    final senderAvatar = widget.message['profile_avatar']
     ?? widget.message['sender_avatar'];

    final timeStr = _formatTime(widget.message['created_at']);

    final bubbleColor = widget.isMe ? const Color(0xFFE6F7F3) : Colors.white;
    final borderColor = widget.isMe ? AppColors.primary.withOpacity(0.3) : AppColors.glassBorder;

    Widget bubbleContent = Column(
      crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.isMe && widget.showAvatar)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(senderName,
              style: const TextStyle(
                fontFamily: 'Tajawal', fontSize: 12,
                fontWeight: FontWeight.w700, color: AppColors.navy)),
          ),
        if (imageUrl != null && imageUrl.toString().isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 220,
              fit: BoxFit.cover,
              placeholder: (c, u) => Container(
                width: 220, height: 140,
                color: AppColors.bgCard2,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
              errorWidget: (c, u, e) => Container(
                width: 220, height: 140, color: AppColors.bgCard2,
                child: const Icon(Icons.broken_image_rounded, color: AppColors.textSub)),
            ),
          ),
        if (audioUrl != null && audioUrl.toString().isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgCard2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
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
                  icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_arrow_rounded, color: AppColors.navy, size: 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('رسالة صوتية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppColors.text)),
                    if (_duration.inSeconds > 0)
                      Text('${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textSub)),
                  ],
                ),
              ],
            ),
          ),
        if (content.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: (imageUrl != null || audioUrl != null) ? 6 : 0),
            child: Text(content, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, color: AppColors.text, height: 1.4)),
          ),
        const SizedBox(height: 4),
        Text(timeStr, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textSub)),
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
          bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
          bottomRight: Radius.circular(widget.isMe ? 4 : 18),
        ),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: bubbleContent,
    );

    return GestureDetector(
      onLongPress: widget.isMe ? _showDeleteDialog : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!widget.isMe && widget.showAvatar)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.bgCard2,
                  backgroundImage: senderAvatar != null && senderAvatar.toString().isNotEmpty
                  ? CachedNetworkImageProvider(senderAvatar) : null,
                  child: senderAvatar == null || senderAvatar.toString().isEmpty
                  ? Text(senderName.isNotEmpty ? senderName[0] : '?',
                        style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.navy, fontWeight: FontWeight.w700))
                    : null,
                ),
              ),
            if (!widget.isMe && !widget.showAvatar) const SizedBox(width: 38),
            Flexible(child: bubble),
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
