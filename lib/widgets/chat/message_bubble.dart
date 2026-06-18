import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/app_colors.dart';
import '../../models/message_model.dart';

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
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPauseAudio(String url) async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(UrlSource(url));
      setState(() => _isPlaying = true);
      
      _audioPlayer.onDurationChanged.listen((d) {
        setState(() => _duration = d);
      });
      
      _audioPlayer.onPositionChanged.listen((p) {
        setState(() => _position = p);
      });
      
      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      });
    }
  }

  String _formatDuration(int seconds) {
    final mins = (seconds / 60).floor();
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final msg = MessageModel.fromJson(widget.message);
    
    return Align(
      alignment: widget.isMe? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: widget.isMe? AppColors.primary : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isMe)
              Text(
                msg.senderName,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (msg.replyToId!= null) _buildReplyContent(msg),
            const SizedBox(height: 4),
            if (msg.type == 'text') _buildTextContent(msg),
            if (msg.type == 'voice') _buildAudioContent(msg),
            if (msg.type == 'image') _buildImageContent(msg),
            const SizedBox(height: 4),
            _buildTime(msg),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyContent(MessageModel msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Text(
        'رد على رسالة',
        style: TextStyle(
          fontFamily: 'Tajawal',
          color: AppColors.textSub,
          fontSize: 11,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildTextContent(MessageModel msg) {
    return Text(
      msg.content,
      style: TextStyle(
        fontFamily: 'Tajawal',
        color: widget.isMe? Colors.white : AppColors.white,
        fontSize: 15,
      ),
    );
  }

  Widget _buildAudioContent(MessageModel msg) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _playPauseAudio(msg.audioUrl!),
          icon: Icon(
            _isPlaying? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: widget.isMe? Colors.white : AppColors.primary,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Slider(
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds.toDouble() > 0? _duration.inSeconds.toDouble() : 1,
                onChanged: (value) async {
                  await _audioPlayer.seek(Duration(seconds: value.toInt()));
                },
                activeColor: widget.isMe? Colors.white : AppColors.primary,
                inactiveColor: AppColors.glassBorder,
              ),
              Text(
                '${_formatDuration(_position.inSeconds)} / ${_formatDuration(msg.duration?? 0)}',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  color: widget.isMe? Colors.white70 : AppColors.textSub,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageContent(MessageModel msg) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        msg.fileUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                value: loadingProgress.expectedTotalBytes!= null
                 ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTime(MessageModel msg) {
    return Text(
      '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
      style: TextStyle(
        fontFamily: 'Tajawal',
        color: widget.isMe? Colors.white70 : AppColors.textSub,
        fontSize: 10,
      ),
    );
  }
}
