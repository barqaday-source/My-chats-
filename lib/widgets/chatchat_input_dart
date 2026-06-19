// lib/widgets/chat/chat_input_bar.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';

class ChatInputBar extends StatefulWidget {
  final Future<void> Function(String text, String? imageUrl, String? voiceUrl) onSend;
  const ChatInputBar({super.key, required this.onSend});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _textController = TextEditingController();
  final _picker = ImagePicker();
  final _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  bool _recorderReady = false;

  @override
  void initState() {
    super.initState();
    _openRecorder();
  }

  Future<void> _openRecorder() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
    if (mounted) setState(() => _recorderReady = true);
  }

  Future<void> _toggleRecord() async {
    if (!_recorderReady) return;
    if (_isRecording) {
      final path = await _recorder.stopRecorder();
      setState(() => _isRecording = false);
      if (path!= null) await _uploadVoice(path);
    } else {
      final dir = await getTemporaryDirectory();
      final recordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder.startRecorder(toFile: recordPath, codec: Codec.aacADTS);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _uploadVoice(String path) async {
    final file = File(path);
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    await Supabase.instance.client.storage.from('chat_images').upload(fileName, file);
    final url = Supabase.instance.client.storage.from('chat_images').getPublicUrl(fileName);
    await widget.onSend('', null, url);
  }

  Future<void> _pickImage() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (xfile == null) return;
    final file = File(xfile.path);
    final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await Supabase.instance.client.storage.from('chat_images').upload(fileName, file);
    final url = Supabase.instance.client.storage.from('chat_images').getPublicUrl(fileName);
    await widget.onSend('', url, null);
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text, null, null);
    _textController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _textController.text.trim().isNotEmpty;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: const Color(0xFF1E1E1E),
        child: Row(
          children: [
            IconButton(onPressed: _pickImage, icon: const Icon(Icons.image, color: Colors.white70)),
            Expanded(
              child: TextField(
                controller: _textController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontFamily: 'Tajawal'),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onLongPressStart: (_) =>!hasText &&!_isRecording? _toggleRecord() : null,
              onLongPressEnd: (_) => _isRecording? _toggleRecord() : null,
              onTap: hasText? _sendText : _toggleRecord,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isRecording? Colors.red : const Color(0xFF6C63FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(hasText? Icons.send : (_isRecording? Icons.stop : Icons.mic), color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }
}
