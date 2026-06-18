import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/constants/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String text) onSendText;
  final Function(String path, int duration)? onSendAudio;
  final Function(String path)? onSendImage;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    this.onSendAudio,
    this.onSendImage,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _textController = TextEditingController();
  final _record = AudioRecorder();
  bool _isRecording = false;
  Timer? _timer;
  int _recordDuration = 0;

  @override
  void dispose() {
    _textController.dispose();
    _timer?.cancel();
    _record.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _record.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _record.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _recordDuration++);
        });
      }
    } catch (e) {
      debugPrint('Error recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _record.stop();
      _timer?.cancel();
      setState(() => _isRecording = false);
      if (path != null && _recordDuration > 0) {
        widget.onSendAudio?.call(path, _recordDuration);
      }
      _recordDuration = 0;
    } catch (e) {
      debugPrint('Error stopping: $e');
    }
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onSendText(text);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (widget.onSendImage != null)
              IconButton(
                icon: const Icon(Icons.image_rounded, color: AppColors.primary),
                onPressed: () {},
              ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'اكتب رسالة...',
                    hintStyle: TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.textSub,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendText(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_isRecording)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: AppColors.danger, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '$_recordDuration',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else if (_textController.text.trim().isNotEmpty)
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                onPressed: _sendText,
              )
            else if (widget.onSendAudio != null)
              GestureDetector(
                onLongPress: _startRecording,
                onLongPressUp: _stopRecording,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic_rounded, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
