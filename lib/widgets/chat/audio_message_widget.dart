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
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() {
        _isPlaying = s == PlayerState.playing;
        if (s == PlayerState.completed) _position = Duration.zero;
      });
    });
    _player.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); });
    _player.onDurationChanged.listen((d) { if (mounted && d!= Duration.zero) setState(() => _total = d); });
    _total = Duration(seconds: widget.duration);
  }

  @override void dispose() { _player.dispose(); super.dispose(); }

  Future<void> _toggle() async {
    if (_isPlaying) { await _player.pause(); return; }
    await _player.play(UrlSource(widget.audioUrl));
  }

  @override Widget build(BuildContext context) {
    final progress = _total.inMilliseconds == 0? 0.0 : (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);

    // ألوان واتساب
    final iconColor = widget.isMe? const Color(0xFF075E54) : AppColors.primary;
    final bgIcon = widget.isMe? Colors.white.withOpacity(0.9) : AppColors.primary.withOpacity(0.12);
    final trackColor = widget.isMe? Colors.white.withOpacity(0.4) : AppColors.textSub.withOpacity(0.4);
    final fillColor = widget.isMe? Colors.white : AppColors.primary;
    final timeColor = widget.isMe? Colors.white.withOpacity(0.85) : AppColors.textSub;

    final displayTime = _position > Duration.zero? _position : _total;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: bgIcon, shape: BoxShape.circle),
            child: Icon(_isPlaying? Icons.pause_rounded : Icons.play_arrow_rounded, color: iconColor, size: 22),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 140,
          height: 28,
          child: CustomPaint(
            painter: _WaveformPainter(
              progress: progress,
              trackColor: trackColor,
              fillColor: fillColor
            )
          )
        ),
        const SizedBox(width: 8),
        Text(
          '${displayTime.inMinutes}:${(displayTime.inSeconds % 60).toString().padLeft(2,'0')}',
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: timeColor)
        ),
      ],
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
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, top, barW, h), const Radius.circular(1)),
        Paint()..color = i < filled? fillColor : trackColor
      );
    }
  }
  @override bool shouldRepaint(covariant _WaveformPainter old) => old.progress!= progress;
}
