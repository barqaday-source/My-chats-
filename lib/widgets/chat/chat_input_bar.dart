import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  final Future<void> Function(String text, File? imageFile, File? audioFile) onSend;
  const ChatInputBar({super.key, required this.onSend});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _recorder = FlutterSoundRecorder();
  bool _recReady = false;
  bool _recording = false;
  bool _sending = false;
  Duration _recDuration = Duration.zero;
  Timer? _recTimer;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _initRec();
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat();
  }

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
    try {
      await widget.onSend(t, null, null);
      _ctrl.clear();
      setState(() {});
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    final imgPerm = await Permission.photos.request();
    if (!imgPerm.isGranted) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) return;
    }
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x == null) return;
    setState(() => _sending = true);
    try {
      await widget.onSend('', File(x.path), null);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startRec() async {
    if (!_recReady) { await _initRec(); return; }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
    setState(() { _recording = true; _recDuration = Duration.zero; });
    _recTimer?.cancel();
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRec({required bool send}) async {
    final path = await _recorder.stopRecorder();
    _recTimer?.cancel();
    setState(() => _recording = false);
    if (!send || path == null) return;
    setState(() => _sending = true);
    try {
      await widget.onSend('', null, File(path));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2,'0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2,'0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // --- UI نسخة طبق الأصل من ملفك ---
    final hasText = _ctrl.text.trim().isNotEmpty;

    if (_recording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.divider))),
        child: SafeArea(
          child: Row(children: [
            IconButton(onPressed: () => _stopRec(send: false), icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger)),
            const SizedBox(width: 4),
            const Icon(Icons.mic_rounded, color: AppColors.danger, size: 20),
            const SizedBox(width: 6),
            Text(_fmt(_recDuration), style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Expanded(child: AnimatedBuilder(
              animation: _waveController,
              builder: (_, __) => Row(mainAxisAlignment: MainAxisAlignment.start, children: List.generate(18, (i) {
                final h = 6 + ((i + _waveController.value * 18) % 5) * 5;
                return Container(width: 3, height: h.toDouble(), margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.7), borderRadius: BorderRadius.circular(2)));
              })),
            )),
            const SizedBox(width: 8),
            GestureDetector(onTap: () => _stopRec(send: true),
              child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.divider))),
      child: SafeArea(child: Row(children: [
        GestureDetector(
          onTap: hasText &&!_sending? _sendText : null,
          child: Container(width: 44, height: 44,
            decoration: BoxDecoration(color: hasText? AppColors.primary : AppColors.bgCard2, shape: BoxShape.circle),
            child: Icon(Icons.send_rounded, color: hasText? Colors.white : AppColors.textSub, size: 20, textDirection: TextDirection.rtl),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.glassBorder, width: 1.2)),
          child: Row(children: [
            IconButton(onPressed: _sending? null : _pickImage, icon: const Icon(Icons.image_outlined, color: AppColors.textSub, size: 22)),
            Expanded(child: TextField(
              controller: _ctrl, onChanged: (_) => setState(() {}), textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'اكتب رسالة...',
                hintStyle: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10)),
              onSubmitted: (_) => _sendText(),
            )),
            IconButton(onPressed: _sending? null : _startRec, icon: const Icon(Icons.mic_none_rounded, color: AppColors.textSub)),
          ]),
        )),
      ])),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose(); _recTimer?.cancel(); _waveController.dispose(); _recorder.closeRecorder();
    super.dispose();
  }
}
