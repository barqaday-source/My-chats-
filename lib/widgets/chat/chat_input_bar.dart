import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String text, String? replyToId) onSendText;
  final Function(File file, String? replyToId) onSendImage;
  final Function(File file, int duration, String? replyToId) onSendVoice;
  final String? replyToId;
  final String? replyToContent;
  final VoidCallback? onCancelReply;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    required this.onSendVoice,
    this.replyToId,
    this.replyToContent,
    this.onCancelReply,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _textController = TextEditingController();
  final _recorder = FlutterSoundRecorder();
  final _picker = ImagePicker();
  
  bool _isRecording = false;
  bool _recorderReady = false;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status!= PermissionStatus.granted) return;
    
    await _recorder.openRecorder();
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    _recorder.onProgress?.listen((e) {
      if (mounted) setState(() => _recordDuration = e.duration.inSeconds);
    });
    setState(() => _recorderReady = true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _startRecord() async {
    if (!_recorderReady) return;
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    
    await _recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
    setState(() {
      _isRecording = true;
      _recordDuration = 0;
    });
  }

  Future<void> _stopRecord() async {
    final path = await _recorder.stopRecorder();
    setState(() => _isRecording = false);
    
    if (path!= null && _recordDuration > 0) {
      final file = File(path);
      widget.onSendVoice(file, _recordDuration, widget.replyToId);
      widget.onCancelReply?.call();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final status = source == ImageSource.camera
       ? await Permission.camera.request()
        : await Permission.photos.request();
    
    if (status!= PermissionStatus.granted) return;
    
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image!= null) {
      widget.onSendImage(File(image.path), widget.replyToId);
      widget.onCancelReply?.call();
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.white),
              title: const Text('الكاميرا', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.white),
              title: const Text('المعرض', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    widget.onSendText(text, widget.replyToId);
    _textController.clear();
    widget.onCancelReply?.call();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          border: Border(top: BorderSide(color: AppColors.glassBorder, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyToId!= null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgCard2,
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, color: AppColors.textSub, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.replyToContent?? 'رد على رسالة',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.textSub,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.textSub,
                      onPressed: widget.onCancelReply,
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file_rounded),
                  color: AppColors.textSub,
                  onPressed: _showImageOptions,
                ),
                Expanded(
                  child: _isRecording
                     ? Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.mic, color: AppColors.danger),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_recordDuration),
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'جار التسجيل...',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: AppColors.danger,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : TextField(
                          controller: _textController,
                          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالة...',
                            hintStyle: const TextStyle(color: AppColors.textSub),
                            filled: true,
                            fillColor: AppColors.bgCard2,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          maxLines: 5,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendText(),
                        ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onLongPressStart: (_) => _startRecord(),
                  onLongPressEnd: (_) => _stopRecord(),
                  onTap: () {
                    if (_textController.text.trim().isNotEmpty) _sendText();
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _textController.text.trim().isNotEmpty
                         ? Icons.send_rounded
                          : _isRecording
                             ? Icons.stop_rounded
                              : Icons.mic_rounded,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
