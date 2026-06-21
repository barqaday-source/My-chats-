import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  final Future<void> Function(String text, File? imageFile, File? audioFile, int audioDuration) onSend;
  final Map<String, dynamic>? replyTo;
  final VoidCallback? onCancelReply;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.replyTo,
    this.onCancelReply,
  });

  @override State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _recorderReady = false;
  bool _isRecording = false;
  Timer? _timer;
  Duration _recordDuration = Duration.zero;
  String? _recordPath;

  // معاينة الصوت بعد التسجيل
  File? _pendingAudio;
  int _pendingDuration = 0;

  @override void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    _recorderReady = true;
  }

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
    if (!_recorderReady || _sending || _isRecording || _pendingAudio != null) return;
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return;

    final dir = await getTemporaryDirectory();
    _recordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder.startRecorder(
      toFile: _recordPath,
      codec: Codec.aacADTS,
    );

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
    await _recorder.stopRecorder();

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

    // لا ترسل تلقائي، خليه معاينة
    setState(() {
      _pendingAudio = File(path);
      _pendingDuration = duration;
    });
  }

  Future<void> _sendPendingAudio() async {
    if (_pendingAudio == null) return;
    setState(() => _sending = true);
    try {
      await widget.onSend('', null, _pendingAudio, _pendingDuration);
      await _pendingAudio!.delete().catchError((_){});
      setState(() {
        _pendingAudio = null;
        _pendingDuration = 0;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _cancelPendingAudio() async {
    if (_pendingAudio != null) {
      await _pendingAudio!.delete().catchError((_){});
    }
    setState(() {
      _pendingAudio = null;
      _pendingDuration = 0;
    });
  }

  @override void dispose() {
    _timer?.cancel();
    _recorder.closeRecorder();
    _ctrl.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    final hasText = _ctrl.text.trim().isNotEmpty;
    final reply = widget.replyTo;
    final hasPendingAudio = _pendingAudio != null;

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
            if (reply != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppColors.bgCard,
                  border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
                ),
                child: Row(
                  children: [
                    Container(width: 3, height: 36, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reply['sender_name'] ?? 'رد', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          Text(
                            reply['content'] ?? (reply['image_url'] != null ? '📷 صورة' : '🎤 رسالة صوتية'),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSub), onPressed: widget.onCancelReply),
                  ],
                ),
              ),

            // معاينة الصوت قبل الإرسال
            if (hasPendingAudio)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(color: AppColors.bgCard, border: Border(bottom: BorderSide(color: AppColors.glassBorder))),
                child: Row(
                  children: [
                    IconButton(onPressed: _cancelPendingAudio, icon: const Icon(Icons.delete_outline, color: AppColors.danger)),
                    const SizedBox(width: 8),
                    const Icon(Icons.mic_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('${_pendingDuration}s', style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _sending ? null : _sendPendingAudio,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('إرسال', style: TextStyle(fontFamily: 'Tajawal')),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // زر إرسال / مايك
                  GestureDetector(
                    onLongPressStart: hasText || _sending || hasPendingAudio ? null : (_) => _startRecord(),
                    onLongPressEnd: hasText || _sending ? null : (_) => _stopRecord(),
                    onLongPressCancel: () => _stopRecord(cancel: true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: hasText ? AppColors.primary : AppColors.bgCard,
                        shape: BoxShape.circle,
                        border: Border.all(color: hasText ? AppColors.primary : AppColors.glassBorder, width: 1.2),
                      ),
                      child: IconButton(
                        onPressed: hasText && !_sending ? _sendText : null,
                        icon: Icon(hasText ? Icons.send_rounded : Icons.mic_rounded,
                          color: hasText ? Colors.white : AppColors.textSub, size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // الحقل
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: _isRecording
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () => _stopRecord(cancel: true),
                                    child: const Icon(Icons.close_rounded, color: AppColors.danger, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Text(_format(_recordDuration), style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.danger, fontSize: 14, fontWeight: FontWeight.w700)),
                                  const Spacer(),
                                  const Text('جار التسجيل...', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 13)),
                                ],
                              ),
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                IconButton(
                                  onPressed: _sending || hasPendingAudio ? null : _pickImage,
                                  icon: const Icon(Icons.image_outlined, color: AppColors.textSub, size: 24),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _ctrl,
                                    onChanged: (_) => setState(() {}),
                                    maxLines: 5, minLines: 1,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 15),
                                    decoration: const InputDecoration(
                                      hintText: 'اكتب رسالة...',
                                      hintStyle: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
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
