import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/app_colors.dart';

class AudioMessageWidget extends StatefulWidget {
  final String audioUrl;
  final int duration;
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const AudioMessageWidget({
    super.key,
    required this.audioUrl,
    required this.duration,
    required this.isMe,
    this.onReply,
    this.onDelete,
  });

  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _total = Duration(seconds: widget.duration);

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        _isLoading = state == PlayerState.playing && _position == Duration.zero;
        if (state == PlayerState.completed) {
          _position = Duration.zero;
          _isPlaying = false;
          _isLoading = false;
        }
      });
    });

    _posSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() {
        _position = pos;
        if (_isLoading && pos > Duration.zero) _isLoading = false;
      });
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (!mounted) return;
      setState(() => _total = dur);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        setState(() => _isLoading = true);
        await _player.play(UrlSource(widget.audioUrl));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تعذّر تشغيل الصوت',
                style: TextStyle(fontFamily: 'Tajawal')),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progress {
    if (_total.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isMe? AppColors.white : AppColors.primary;
    final trackColor = widget.isMe
       ? AppColors.white.withOpacity(0.3)
        : AppColors.glassBorder;
    final fillColor = widget.isMe? AppColors.white : AppColors.primary;

    return Column(
      crossAxisAlignment:
          widget.isMe? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // فقاعة الفويس
        Container(
          constraints: const BoxConstraints(maxWidth: 300, minWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isMe? AppColors.primary : AppColors.bgCard,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // زر تشغيل دائري
              GestureDetector(
                onTap: _isLoading? null : _togglePlay,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.isMe
                       ? AppColors.white.withOpacity(0.2)
                        : AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                     ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: iconColor),
                        )
                      : Icon(
                          _isPlaying
                             ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: iconColor,
                          size: 26,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 28,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _WaveformPainter(
                          progress: _progress,
                          trackColor: trackColor,
                          fillColor: fillColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isPlaying
                         ? _fmt(_position)
                          : _fmt(_total.inMilliseconds > 0
                             ? _total
                              : Duration(seconds: widget.duration)),
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: widget.isMe
                           ? AppColors.white.withOpacity(0.8)
                            : AppColors.textSub,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.mic_rounded,
                  color: widget.isMe
                     ? AppColors.white.withOpacity(0.7)
                      : AppColors.textSub,
                  size: 18),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // أزرار الرد والحذف - مفصولة
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onReply!= null)
                _actionChip(
                  Icons.reply_rounded,
                  'رد',
                  AppColors.textSub,
                  widget.onReply!,
                ),
              if (widget.onReply!= null && widget.onDelete!= null)
                const SizedBox(width: 18),
              if (widget.onDelete!= null)
                _actionChip(
                  Icons.delete_outline_rounded,
                  'حذف',
                  AppColors.danger,
                  () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: AppColors.bgCard,
                        title: const Text('حذف التسجيل؟',
                            style: TextStyle(
                                fontFamily: 'Tajawal',
                                color: AppColors.white)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('إلغاء',
                                  style: TextStyle(color: AppColors.textSub))),
                          TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('حذف',
                                  style: TextStyle(color: AppColors.danger))),
                        ],
                      ),
                    );
                    if (ok == true) widget.onDelete!();
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionChip(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;

  static const _bars = [
    4, 8, 12, 7, 16, 11, 5, 9, 14, 8,
    13, 6, 15, 10, 7, 12, 5, 9, 8, 14,
    6, 11, 14, 7, 10, 16, 9, 13, 7, 12,
    5, 10
  ];

  const _WaveformPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const count = 32;
    const barW = 2.0;
    final spacing = size.width > count * barW
       ? (size.width - count * barW) / (count - 1)
        : 1.0;
    final filled = (count * progress).round();

    for (int i = 0; i < count; i++) {
      final h = (_bars[i] / 16.0) * size.height;
      final x = i * (barW + spacing);
      final top = (size.height - h) / 2;
      final paint = Paint()
       ..color = i < filled? fillColor : trackColor
       ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barW, h),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress!= progress ||
      old.trackColor!= trackColor ||
      old.fillColor!= fillColor;
}
