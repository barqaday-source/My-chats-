import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/app_colors.dart';

class AudioMessageWidget extends StatefulWidget {
  final String audioUrl;
  final int duration;
  final bool isMe;
  const AudioMessageWidget({super.key, required this.audioUrl, required this.duration, required this.isMe});

  @override State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  @override void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setVolume(1.0);
    _player.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: true, stayAwake: true,
        contentType: AndroidContentType.speech,
        usageType: AndroidUsageType.voiceCommunication,
        audioFocus: AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.playback, options: {AVAudioSessionOptions.defaultToSpeaker}),
    ));
    _total = Duration(seconds: widget.duration);
    _player.onPlayerStateChanged.listen((s) { if (!mounted) return; setState(() { _isPlaying = s == PlayerState.playing; if (s == PlayerState.completed) _position = Duration.zero; }); });
    _player.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); });
    _player.onDurationChanged.listen((d) { if (mounted && d!= Duration.zero) setState(() => _total = d); });
  }

  @override void dispose() { _player.dispose(); super.dispose(); }

  Future<void> _toggle() async {
    if (_isPlaying) { await _player.pause(); return; }
    await _player.setVolume(1.0);
    await _player.play(UrlSource(widget.audioUrl));
  }

  @override Widget build(BuildContext context) {
    final progress = _total.inMilliseconds == 0? 0.0 : (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
    final iconColor = widget.isMe? Colors.white : AppColors.primary;
    final trackColor = widget.isMe? Colors.white.withOpacity(0.3) : AppColors.glassBorder;
    final fillColor = widget.isMe? Colors.white : AppColors.primary;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280, minWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isMe? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: widget.isMe? Colors.white.withOpacity(0.2) : AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(_isPlaying? Icons.pause_rounded : Icons.play_arrow_rounded, color: iconColor, size: 24),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: SizedBox(height: 28, child: CustomPaint(painter: _WaveformPainter(progress: progress, trackColor: trackColor, fillColor: fillColor)))),
        const SizedBox(width: 8),
        Text('${(_position.inSeconds ~/ 60).toString().padLeft(2,'0')}:${(_position.inSeconds % 60).toString().padLeft(2,'0')}',
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: widget.isMe? Colors.white.withOpacity(0.85) : AppColors.textSub)),
      ]),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress; final Color trackColor; final Color fillColor;
  static const _bars = [4,8,12,7,16,11,5,9,14,8,13,6,15,10,7,12,5,9,8,14,6,11,14,7,10,16,9,13,7,12,5,10];
  const _WaveformPainter({required this.progress, required this.trackColor, required this.fillColor});
  @override void paint(Canvas canvas, Size size) {
    const count = 32; const barW = 2.0;
    final spacing = size.width > count * barW? (size.width - count * barW) / (count - 1) : 1.0;
    final filled = (count * progress).round();
    for (int i = 0; i < count; i++) {
      final h = (_bars[i] / 16.0) * size.height;
      final x = i * (barW + spacing);
      final top = (size.height - h) / 2;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, top, barW, h), const Radius.circular(1)),
        Paint()..color = i < filled? fillColor : trackColor);
    }
  }
  @override bool shouldRepaint(covariant _WaveformPainter old) => old.progress!= progress;
}
