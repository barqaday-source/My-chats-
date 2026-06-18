import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';

class VoiceRecorderButton extends StatefulWidget {
  final Function(String path, int duration) onRecordComplete;

  const VoiceRecorderButton({
    super.key,
    required this.onRecordComplete,
  });

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton>
    with TickerProviderStateMixin {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  bool _recorderReady = false;
  int _recordDuration = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  List<double> _waveform = [];
  String? _currentPath;
  StreamSubscription? _recorderSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _openRecorder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorderSub?.cancel();
    _pulseController.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _openRecorder() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    if (status != PermissionStatus.granted) return;

    try {
      await _recorder.openRecorder();
      _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
      if (mounted) setState(() => _recorderReady = true);
    } catch (e) {
      debugPrint('Recorder init error: $e');
    }
  }

  Future<void> _startRecording() async {
    if (!_recorderReady) {
      await _openRecorder();
      if (!_recorderReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يجب منح إذن الميكروفون للتسجيل',
                  style: TextStyle(fontFamily: 'Tajawal')),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${const Uuid().v4()}.aac';
      _currentPath = path;

      await _recorder.startRecorder(
        toFile: path,
        codec: Codec.aacADTS,
        bitRate: 128000,
        sampleRate: 44100,
      );

      setState(() {
        _isRecording = true;
        _recordDuration = 0;
        _waveform.clear();
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _recordDuration++);
        if (_recordDuration >= 60) _stopRecording();
      });

      _recorderSub = _recorder.onProgress!.listen((e) {
        if (!mounted) return;
        final db = e.decibels ?? 0;
        final normalized = ((db + 60) / 60).clamp(0.1, 1.0);
        setState(() {
          _waveform.add(normalized);
          if (_waveform.length > 30) _waveform.removeAt(0);
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل بدء التسجيل',
                style: TextStyle(fontFamily: 'Tajawal')),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _recorderSub?.cancel();

    if (_recordDuration < 1) {
      await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
        _waveform.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اضغط مطولاً للتسجيل',
                style: TextStyle(fontFamily: 'Tajawal')),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    try {
      final path = await _recorder.stopRecorder();
      final finalPath = path ?? _currentPath ?? '';
      final duration = _recordDuration;

      setState(() {
        _isRecording = false;
        _waveform.clear();
      });

      if (finalPath.isNotEmpty) {
        widget.onRecordComplete(finalPath, duration);
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _waveform.clear();
      });
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    _recorderSub?.cancel();
    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
      _recordDuration = 0;
      _waveform.clear();
    });
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.danger, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.danger
                      .withOpacity(0.5 + _pulseController.value * 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _waveform.map((amp) {
                  return Container(
                    width: 2.5,
                    height: 4 + (amp * 22),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _fmt(_recordDuration),
              style: const TextStyle(
                fontFamily: 'Tajawal',
                color: AppColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _cancelRecording,
              child: const Icon(Icons.close_rounded,
                  color: AppColors.danger, size: 20),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: AppColors.white, size: 15),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPress: _startRecording,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.mic_rounded, color: AppColors.white, size: 20),
      ),
    );
  }
}
