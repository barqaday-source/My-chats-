import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/app_colors.dart';
import '../../services/chat_service.dart';
import '../../screens/profile/user_profile_screen.dart';
import 'app_snackbar.dart';

class MessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool showAvatar;
  final VoidCallback? onReply;
  final bool isRoom;
  final void Function(String messageId)? onDelete; // NEW: اختياري

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showAvatar = true,
    this.onReply,
    this.isRoom = true,
    this.onDelete,
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
    _player.onPlayerStateChanged.listen((s) { if (mounted) setState(() => _isPlaying = s == PlayerState.playing); });
    _player.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); });
    _player.onDurationChanged.listen((d) { if (mounted) setState(() => _duration = d); });
    _player.onPlayerComplete.listen((_) { if (mounted) setState(() { _isPlaying = false; _position = Duration.zero; }); });
  }

  Future<void> _deleteMessage() async {
    try {
      // UPDATED: نمرر روابط الملفات حتى تنمسح من Storage
      final msg = widget.message;
      final imageUrl = msg['image_url']?? msg['media_url'];
      final audioUrl = msg['audio_url'];

      await ChatService().deleteMessage(
        msg['id'].toString(),
        isRoom: widget.isRoom,
        imageUrl: imageUrl,
        audioUrl: audioUrl,
      );
      if (mounted) showAppSnack(context, 'تم حذف الرسالة', success: true);
      widget.onDelete?.call(msg['id'].toString());
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل الحذف', success: false);
    }
  }

  void _showDeleteDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: const Text('حذف الرسالة', style: TextStyle(color: AppColors.white, fontFamily: 'Tajawal')),
      content: const Text('هل تريد حذف هذه الرسالة؟', style: TextStyle(color: AppColors.textSub, fontFamily: 'Tajawal')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub))),
        TextButton(onPressed: () { Navigator.pop(ctx); _deleteMessage(); },
          child: const Text('حذف', style: TextStyle(color: AppColors.danger, fontFamily: 'Tajawal'))),
      ],
    ));
  }

  void _openProfile() {
    final userId = widget.message['sender_id'];
    if (userId == null || widget.isMe) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => UserProfileScreen(userId: userId),
    ));
  }

  String _formatDuration(Duration d) { final m = d.inMinutes.remainder(60).toString().padLeft(2, '0'); final s = d.inSeconds.remainder(60).toString().padLeft(2, '0'); return '$m:$s'; }
  String _formatTime(dynamic ts) { try { final dt = DateTime.parse(ts.toString()).toLocal(); final h = dt.hour % 12 == 0? 12 : dt.hour % 12; final m = dt.minute.toString().padLeft(2, '0'); final am = dt.hour < 12? 'ص' : 'م'; return '$h:$m $am'; } catch (_) { return ''; } }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.message['media_url']?? widget.message['image_url'];
    final audioUrl = widget.message['audio_url'];
    final content = widget.message['content']?.toString()?? '';
    final senderName = widget.message['profile_username']?? widget.message['sender_name']?? widget.message['username']?? 'مستخدم';
    final senderAvatar = widget.message['profile_avatar']?? widget.message['sender_avatar'];
    final timeStr = _formatTime(widget.message['created_at']);

    // UPDATED: معاينة الرد - تدعم الحقول الجديدة مع fallback للقديمة
    final replyText = widget.message['reply_to_text']?? widget.message['reply_content'];
    final replyType = widget.message['reply_to_type']?? 'text';
    String? replyContent;
    if (replyText!= null) {
      replyContent = replyText;
      if (replyType == 'image') replyContent = '📷 صورة';
      if (replyType == 'audio') replyContent = '🎤 رسالة صوتية';
    }

    final bubbleColor = widget.isMe? const Color(0xFFE6F7F3) : Colors.white;
    final borderColor = widget.isMe? AppColors.primary.withOpacity(0.3) : AppColors.glassBorder;

    Widget bubbleContent = Column(
      crossAxisAlignment: widget.isMe? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.isMe && widget.showAvatar)
          Padding(padding: const EdgeInsets.only(bottom: 4),
            child: Text(senderName, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navy))),
        if (replyContent!= null) Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), borderRadius: BorderRadius.circular(8),
            border: const Border(right: BorderSide(color: AppColors.primary, width: 3))),
          child: Text(replyContent, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub))),
        if (imageUrl!= null && imageUrl.toString().isNotEmpty)
          ClipRRect(borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(imageUrl: imageUrl, width: 220, fit: BoxFit.cover,
              placeholder: (c, u) => Container(width: 220, height: 140, color: AppColors.bgCard2,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
              errorWidget: (c, u, e) => Container(width: 220, height: 140, color: AppColors.bgCard2,
                child: const Icon(Icons.broken_image_rounded, color: AppColors.textSub)))),
        if (audioUrl!= null && audioUrl.toString().isNotEmpty)
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: AppColors.bgCard2, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(onPressed: () async { if (_isPlaying) { await _player.pause(); } else { await _player.play(UrlSource(audioUrl)); } },
                icon: Icon(_isPlaying? Icons.pause_circle : Icons.play_arrow_rounded, color: AppColors.navy, size: 28),
                padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              const SizedBox(width: 6),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('رسالة صوتية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppColors.text)),
                if (_duration.inSeconds > 0)
                  Text('${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textSub)),
              ]),
            ])),
        if (content.isNotEmpty)
          Padding(padding: EdgeInsets.only(top: (imageUrl!= null || audioUrl!= null)? 6 : 0),
            child: Text(content, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, color: AppColors.text, height: 1.4))),
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
          topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(widget.isMe? 18 : 4),
          bottomRight: Radius.circular(widget.isMe? 4 : 18)),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: bubbleContent,
    );

    return GestureDetector(
      onLongPress: widget.isMe? _showDeleteDialog : null,
      onHorizontalDragEnd: (_) => widget.onReply?.call(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment: widget.isMe? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!widget.isMe && widget.showAvatar)
              GestureDetector(
                onTap: _openProfile,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: CircleAvatar(
                    radius: 16, backgroundColor: AppColors.bgCard2,
                    backgroundImage: senderAvatar!= null && senderAvatar.toString().isNotEmpty
                 ? CachedNetworkImageProvider(senderAvatar) : null,
                    child: senderAvatar == null || senderAvatar.toString().isEmpty
                 ? Text(senderName.isNotEmpty? senderName[0] : '?',
                          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.navy, fontWeight: FontWeight.w700))
                      : null,
                  ),
                ),
              ),
            if (!widget.isMe &&!widget.showAvatar) const SizedBox(width: 38),
            Flexible(child: bubble),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() { _player.dispose(); super.dispose(); }
}
