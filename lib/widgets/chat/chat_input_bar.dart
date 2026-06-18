import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../models/message_model.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String text, String? replyToId) onSendText;
  final Function(String path, int duration, String? replyToId)? onSendAudio;
  final Function(String path, String? replyToId)? onSendImage;
  final String? replyToId;
  final MessageModel? replyToMessage;
  final VoidCallback? onCancelReply;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    this.onSendAudio,
    this.onSendImage,
    this.replyToId,
    this.replyToMessage,
    this.onCancelReply,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _textController = TextEditingController();
  final _recorder = FlutterSoundRecorder();
  final _imagePicker = ImagePicker();
  bool _isRecorderInited = false;
  bool _isRecording = false;
  Timer? _timer;
  int _recordDuration = 0;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لازم توافق على صلاحية المايك')),
        );
      }
      return;
    }
    await _recorder.openRecorder();
    setState(() => _isRecorderInited = true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _timer?.cancel();
    if (_isRecorderInited) _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInited) {
      await _initRecorder();
      if (!_isRecorderInited) return;
    }
    try {
      final dir = await getTemporaryDirectory();
      _recordingPath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacADTS,
      );
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordDuration++);
      });
    } catch (e) {
      debugPrint('Error recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل بدء التسجيل: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stopRecorder();
      _timer?.cancel();
      setState(() => _isRecording = false);
      if (_recordingPath != null && _recordDuration > 0) {
        widget.onSendAudio?.call(_recordingPath!, _recordDuration, widget.replyToId);
      }
      _recordDuration = 0;
      _recordingPath = null;
      widget.onCancelReply?.call();
    } catch (e) {
      debugPrint('Error stopping: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        widget.onSendImage?.call(image.path, widget.replyToId);
        widget.onCancelReply?.call();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل اختيار الصورة: $e')),
        );
      }
    }
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onSendText(text, widget.replyToId);
      _textController.clear();
      widget.onCancelReply?.call();
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyToMessage != null) _buildReplyPreview(),
            Row(
              children: [
                if (widget.onSendImage != null)
                  IconButton(
                    icon: const Icon(Icons.image_rounded, color: AppColors.primary),
                    onPressed: _pickImage,
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
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isRecording)
                  GestureDetector(
                    onTap: _stopRecording,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stop, color: AppColors.danger, size: 18),
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
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.replyToMessage!.senderName,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.replyToMessage!.type == 'voice'
                      ? 'رسالة صوتية'
                      : widget.replyToMessage!.type == 'image'
                          ? 'صورة'
                          : widget.replyToMessage!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.textSub,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textSub),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }
}
