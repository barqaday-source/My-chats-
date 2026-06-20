import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  final Future<void> Function(String text, File? imageFile, String? audioPath, int audioDuration) onSend;
  final Map<String, dynamic>? replyTo;
  final VoidCallback? onCancelReply;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.replyTo,
    this.onCancelReply,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  // تسجيل صوتي
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _timer;
  Duration _recordDuration = Duration.zero;
  String? _recordPath;

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _sendText() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(t, null, null, 0);
      _ctrl.clear();
      setState(() {});
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    final perm = await Permission.photos.request();
    if (!perm.isGranted) return;
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x == null) return;
    setState(() => _sending = true);
    try {
      await widget.onSend('', File(x.path), null, 0);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startRecord() async {
    if (_sending || _isRecording) return;
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return;

    final dir = await getTemporaryDirectory();
    _recordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    
    await _recorder.start(const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
    ), path: _recordPath!);

    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecord({bool cancel = false}) async {
    if (!_isRecording) return;
    _timer?.cancel();
    await _recorder.stop();
    final path = _recordPath;
    final duration = _recordDuration.inSeconds;

    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
      _recordPath = null;
    });

    if (cancel || path == null || duration < 1) {
      if (path != null) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.onSend('', null, path, duration);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _ctrl.text.trim().isNotEmpty;
    final reply = widget.replyTo;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // معاينة الرد
            if (reply != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppColors.bgCard,
                  border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reply['sender_name'] ?? 'رد',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            reply['content'] ??
                                (reply['image_url'] != null ? '📷 صورة' : '🎤 رسالة صوتية'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              color: AppColors.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSub),
                      onPressed: widget.onCancelReply,
                    ),
                  ],
                ),
              ),

            // الشريط الموحد
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // زر الإرسال / المايك
                  GestureDetector(
                    onLongPressStart: hasText || _sending ? null : (_) => _startRecord(),
                    onLongPressEnd: hasText || _sending ? null : (_) => _stopRecord(),
                    onLongPressCancel: () => _stopRecord(cancel: true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: hasText || _isRecording ? AppColors.primary : AppColors.bgCard,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasText || _isRecording ? AppColors.primary : AppColors.glassBorder,
                          width: 1.2,
                        ),
                      ),
                      child: IconButton(
                        onPressed: hasText && !_sending ? _sendText : null,
                        icon: Icon(
                          hasText ? Icons.send_rounded : Icons.mic_rounded,
                          color: hasText || _isRecording ? Colors.white : AppColors.textSub,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // حقل الكتابة الموحد
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: _isRecording
                          // وضع التسجيل
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              child: Row(
                                children: [
                                  // زر إلغاء مفرغ
                                  InkWell(
                                    onTap: () => _stopRecord(cancel: true),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.danger.withOpacity(0.5)),
                                      ),
                                      child: const Icon(Icons.close_rounded,
                                          color: AppColors.danger, size: 16),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.danger,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _format(_recordDuration),
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      color: AppColors.danger,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Text(
                                    'جار التسجيل...',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      color: AppColors.textSub,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          // وضع الكتابة
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                IconButton(
                                  onPressed: _sending ? null : _pickImage,
                                  icon: const Icon(Icons.image_outlined,
                                      color: AppColors.textSub, size: 24),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _ctrl,
                                    onChanged: (_) => setState(() {}),
                                    maxLines: 5,
                                    minLines: 1,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      color: AppColors.white,
                                      fontSize: 15,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'اكتب رسالة...',
                                      hintStyle: TextStyle(
                                        fontFamily: 'Tajawal',
                                        color: AppColors.textSub,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    onSubmitted: (_) => _sendText(),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
