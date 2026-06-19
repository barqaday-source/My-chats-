import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';

class ChatInputBar extends StatefulWidget {
  final Future<void> Function(String text, String? imageUrl, String? voiceUrl) onSend;
  final void Function(String replyToId, String replyText)? onReply; // اختياري للرد
  const ChatInputBar({super.key, required this.onSend, this.onReply});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();
  final _recorder = FlutterSoundRecorder();
  bool _recReady = false;
  bool _recording = false;
  bool _sending = false;

  @override
  void initState() { super.initState(); _initRec(); }
  
  Future<void> _initRec() async {
    final mic = await Permission.microphone.request();
    if (mic.isGranted) {
      await _recorder.openRecorder();
      if (mounted) setState(() => _recReady = true);
    }
  }

  Future<void> _sendText() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    await widget.onSend(t, null, null);
    _ctrl.clear();
    setState(() => _sending = false);
  }

  Future<void> _pickImage() async {
    final perm = await Permission.photos.request();
    if (!perm.isGranted) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) return;
    }
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await x.readAsBytes();
      final name = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage.from('chat_images').uploadBinary(name, bytes);
      final url = Supabase.instance.client.storage.from('chat_images').getPublicUrl(name);
      await widget.onSend('', url, null);
    } finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _toggleRec() async {
    if (!_recReady) { await _initRec(); return; }
    if (_recording) {
      final path = await _recorder.stopRecorder();
      setState(() => _recording = false);
      if (path != null) {
        setState(() => _sending = true);
        final file = File(path);
        final name = 'voice_${DateTime.now().millisecondsSinceEpoch}.aac';
        await Supabase.instance.client.storage.from('voice_messages').upload(name, file);
        final url = Supabase.instance.client.storage.from('voice_messages').getPublicUrl(name);
        await widget.onSend('', null, url);
        if (mounted) setState(() => _sending = false);
      }
    } else {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
      setState(() => _recording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _ctrl.text.trim().isNotEmpty;
    const mint = Color(0xFF00C4B4);
    const navy = Color(0xFF1A2A4A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8EEF3))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // زر الإرسال - يسار في RTL
            GestureDetector(
              onTap: hasText ? _sendText : null,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: hasText ? mint.withOpacity(0.12) : const Color(0xFFF5F7F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.send_rounded, color: hasText ? mint : const Color(0xFF8A9BA8), size: 20, textDirection: TextDirection.rtl),
              ),
            ),
            const SizedBox(width: 8),
            // حقل الكتابة
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: mint, width: 1.5),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _sending ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined, color: Color(0xFF8A9BA8), size: 22),
                      tooltip: 'صورة',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        onChanged: (_) => setState(() {}),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontFamily: 'Tajawal', color: navy, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالة...',
                          hintStyle: TextStyle(fontFamily: 'Tajawal', color: Color(0xFF8A9BA8)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _sendText(),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : _toggleRec,
                      icon: Icon(
                        _recording ? Icons.stop_circle : Icons.mic_none_rounded,
                        color: _recording ? Colors.red : const Color(0xFF8A9BA8),
                      ),
                      tooltip: 'تسجيل صوتي',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }
}
