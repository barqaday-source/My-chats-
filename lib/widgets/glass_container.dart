import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width, height, borderRadius, blur;
  final EdgeInsets? padding, margin;
  final Color? color, borderColor;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;

  const GlassContainer({super.key, required this.child, this.width, this.height,
    this.borderRadius = 18, this.blur = 12, this.padding, this.margin,
    this.color, this.borderColor, this.onTap, this.shadows});

  @override
  Widget build(BuildContext context) {
    Widget w = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius!),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur!, sigmaY: blur!),
        child: Container(
          width: width, height: height,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color ?? AppColors.glass,
            borderRadius: BorderRadius.circular(borderRadius!),
            border: Border.all(color: borderColor ?? AppColors.glassBorder, width: 0.8),
            boxShadow: shadows ?? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: -4)],
          ),
          child: child,
        ),
      ),
    );
    if (onTap != null) w = GestureDetector(onTap: onTap, child: w);
    if (margin != null) w = Padding(padding: margin!, child: w);
    return w;
  }
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool outlined, loading, small;
  final IconData? icon;
  final Color? color;

  const AppButton({super.key, required this.label, this.onTap, this.outlined = false,
    this.loading = false, this.small = false, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.primary;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: small ? 16 : 22, vertical: small ? 10 : 14),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : bg,
          borderRadius: BorderRadius.circular(12),
          border: outlined ? Border.all(color: bg, width: 1.5) : null,
          // solid block — no gradient
          boxShadow: outlined ? null : [BoxShadow(color: bg.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, color: outlined ? bg : AppColors.white, size: small ? 16 : 18), const SizedBox(width: 6)],
              Text(label, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700,
                fontSize: small ? 13 : 15, color: outlined ? bg : AppColors.white)),
            ]),
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  final bool isOnline;
  final double size;
  const StatusDot({super.key, required this.isOnline, this.size = 10});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: isOnline ? AppColors.online : AppColors.offline,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.bg, width: 2),
      boxShadow: isOnline ? [BoxShadow(color: AppColors.online.withOpacity(0.5), blurRadius: 6)] : null,
    ),
  );
}

class UserAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool isOnline;
  const UserAvatar({super.key, this.url, required this.name, this.size = 44, this.isOnline = false});
  @override
  Widget build(BuildContext context) => Stack(children: [
    Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
        border: Border.all(color: AppColors.glassBorder, width: 1.5),
        image: url != null ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover) : null,
        color: url == null ? AppColors.bgCard2 : null,
      ),
      child: url == null ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: size * 0.4, fontWeight: FontWeight.bold))) : null,
    ),
    if (isOnline) Positioned(right: 0, bottom: 0, child: StatusDot(isOnline: true, size: size * 0.25)),
  ]);
}
