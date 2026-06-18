import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

class ChatInput extends StatefulWidget {
  final Function(String text, String? imageUrl, String? voiceUrl) onSend;
  const ChatInput({super.key, required this.onSend});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _textCtrl = TextEditingController();
  final _record = AudioRecorder();
  final _player = AudioPlayer();
  bool _isRecording = false;
  bool _isUploading = false;
  String? _voicePath;

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploading = true);
      final bytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await Supabase.instance.client.storage
          .from('chat_images')
          .uploadBinary(fileName, bytes);
          
      final url = Supabase.instance.client.storage
          .from('chat_images')
          .getPublicUrl(fileName);
          
      widget.onSend('', url, null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل رفع الصورة: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _toggleRecord() async {
    try {
      if (_isRecording) {
        final path = await _record.stop();
        setState(() => _isRecording = false);
        if (path != null) {
          setState(() => _isUploading = true);
          final bytes = await File(path).readAsBytes();
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
          
          await Supabase.instance.client.storage
              .from('chat_images')
              .uploadBinary(fileName, bytes);
              
          final url = Supabase.instance.client.storage
              .from('chat_images')
              .getPublicUrl(fileName);
              
          widget.onSend('', null, url);
        }
      } else {
        if (await _record.hasPermission()) {
          await _record.start(const RecordConfig(), path: '${DateTime.now().millisecondsSinceEpoch}.m4a');
          setState(() => _isRecording = true);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التسجيل: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _sendText() {
    if (_textCtrl.text.trim().isEmpty) return;
    widget.onSend(_textCtrl.text.trim(), null, null);
    _textCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _isUploading ? null : _pickImage,
              icon: _isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.image, color: Colors.white70),
            ),
            IconButton(
              onPressed: _isUploading ? null : _toggleRecord,
              icon: Icon(
                _isRecording ? Icons.stop_circle : Icons.mic,
                color: _isRecording ? Colors.red : Colors.white70,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontFamily: 'Tajawal'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sendText,
              icon: const Icon(Icons.send, color: Color(0xFF6C63FF)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _record.dispose();
    _player.dispose();
    super.dispose();
  }
}
