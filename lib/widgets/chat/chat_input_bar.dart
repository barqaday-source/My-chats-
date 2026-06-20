import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import 'voice_recorder_button.dart';

class ChatInputBar extends StatefulWidget {
  final Future<void> Function(String text, File? imageFile, String? audioPath, int audioDuration) onSend;
  final Map<String, dynamic>? replyTo;
  final VoidCallback? onCancelReply;
  const ChatInputBar({super.key, required this.onSend, this.replyTo, this.onCancelReply});

  @override State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  Future<void> _sendText() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try { await widget.onSend(t, null, null, 0); _ctrl.clear(); setState(() {}); }
    finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _pickImage() async {
    final imgPerm = await Permission.photos.request();
    if (!imgPerm.isGranted) return;
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x == null) return;
    setState(() => _sending = true);
    try { await widget.onSend('', File(x.path), null, 0); }
    finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _sendAudio(String path, int duration) async {
    setState(() => _sending = true);
    try { await widget.onSend('', null, path, duration); }
    finally { if (mounted) setState(() => _sending = false); }
  }

  @override Widget build(BuildContext context) {
    final hasText = _ctrl.text.trim().isNotEmpty;
    final reply = widget.replyTo;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.divider))),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (reply!= null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.bgCard2, border: Border(bottom: BorderSide(color: AppColors.glassBorder))),
              child: Row(children: [
                Container(width: 3, height: 36, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(reply['sender_name']?? 'رد', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  Text(
                    reply['content']?? (reply['image_url']!= null? '📷 صورة' : '🎤 رسالة صوتية'),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub),
                  ),
                ])),
                IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSub), onPressed: widget.onCancelReply),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              GestureDetector(
                onTap: hasText &&!_sending? _sendText : null,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: hasText? AppColors.primary : AppColors.bgCard2, shape: BoxShape.circle),
                  child: Icon(Icons.send_rounded, color: hasText? Colors.white : AppColors.textSub, size: 20, textDirection: TextDirection.rtl),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.glassBorder, width: 1.2)),
                  child: Row(children: [
                    IconButton(onPressed: _sending? null : _pickImage, icon: const Icon(Icons.image_outlined, color: AppColors.textSub, size: 22)),
                    Expanded(child: TextField(
                      controller: _ctrl,
                      onChanged: (_) => setState(() {}),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالة...',
                        hintStyle: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10)),
                      onSubmitted: (_) => _sendText(),
                    )),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 4),
                      child: SizedBox(
                        width: 42, height: 42,
                        child: _sending
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                          : VoiceRecorderButton(onRecordComplete: (path, duration) => _sendAudio(path, duration)),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
}
