import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool isOnline;
  final VoidCallback? onTap;
  final bool showBorder;
  final String? heroTag;

  const UserAvatar({
    super.key,
    this.url,
    required this.name,
    this.size = 40,
    this.isOnline = false,
    this.onTap,
    this.showBorder = false,
    this.heroTag,
  });

  // لون تدرج ثابت حسب الاسم
  List<Color> _getGradient(String name) {
    final colors = [
      [const Color(0xFF00C9A7), const Color(0xFF007A6C)],
      [const Color(0xFF5B8DEF), const Color(0xFF2D5BBA)],
      [const Color(0xFFFF8A65), const Color(0xFFE64A19)],
      [const Color(0xFFBA68C8), const Color(0xFF7B1FA2)],
      [const Color(0xFFFFD54F), const Color(0xFFFF8F00)],
      [const Color(0xFF4DD0E1), const Color(0xFF00838F)],
    ];
    final index = name.isNotEmpty? name.codeUnitAt(0) % colors.length : 0;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: showBorder
               ? Border.all(color: AppColors.primary.withOpacity(0.8), width: 2.5)
                : null,
            boxShadow: showBorder
               ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: CircleAvatar(
            radius: size / 2,
            backgroundColor: Colors.transparent,
            child: url!= null && url!.isNotEmpty
               ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: url!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildInitial(),
                      errorWidget: (context, url, error) => _buildInitial(),
                    ),
                  )
                : _buildInitial(),
          ),
        ),
        if (isOnline)
          Positioned(
            bottom: 1,
            right: 1,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
            ),
          ),
      ],
    );

    if (heroTag!= null) {
      avatar = Hero(tag: heroTag!, child: avatar);
    }

    if (onTap!= null) {
      avatar = GestureDetector(onTap: onTap, child: avatar);
    }

    return avatar;
  }

  Widget _buildInitial() {
    final gradient = _getGradient(name);
    final initial = name.isNotEmpty? name[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
