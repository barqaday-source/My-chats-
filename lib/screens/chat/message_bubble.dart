import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/app_colors.dart';

class MessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.play(UrlSource(widget.message['audio_url']));
        setState(() => _isPlaying = true);

        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _isPlaying = false);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التشغيل: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.message['type'] ?? 'text';

    // رسالة صوتية
    if (type == 'voice' && widget.message['audio_url'] != null) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: widget.isMe
              ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark])
              : null,
          color: widget.isMe ? null : AppColors.bgCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
            bottomRight: Radius.circular(widget.isMe ? 4 : 16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _playAudio,
              icon: Icon(
                _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: AppColors.white,
              ),
            ),
            Text(
              '${widget.message['duration'] ?? 0}s',
              style: const TextStyle(
                fontFamily: 'Tajawal',
                color: AppColors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // رسالة صورة
    if (type == 'image' && widget.message['media_url'] != null) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 250),
        decoration: BoxDecoration(
          color: widget.isMe ? AppColors.primary : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: widget.message['media_url'],
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

    // رسالة نصية
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: widget.isMe
            ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark])
            : null,
        color: widget.isMe ? null : AppColors.bgCard,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
          bottomRight: Radius.circular(widget.isMe ? 4 : 16),
        ),
      ),
      child: Text(
        widget.message['content'] ?? '',
        style: const TextStyle(
          fontFamily: 'Tajawal',
          color: AppColors.white,
          fontSize: 15,
        ),
      ),
    );
  }
}
