import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  final int notifCount;

  const AppBottomNav({
    super.key, 
    required this.current, 
    required this.onTap, 
    this.notifCount = 0,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false, // نلغي الحماية من فوق عشان يلزق
        bottom: true,
        child: ClipRect( // بدل ClipRRect عشان الحواف مستقيمة
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // زجاجي 2026
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.bgCard.withOpacity(0.7), // زجاجي مو أبيض صافي
                border: Border(
                  top: BorderSide(color: AppColors.glassBorder, width: 0.5), // خط علوي فقط
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _item(0, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
                  _item(1, Icons.meeting_room_outlined, Icons.meeting_room_rounded),
                  _item(2, Icons.person_outline_rounded, Icons.person_rounded),
                  _notifItem(), // الإشعارات
                ],
              ),
            ),
          ),
        ),
      );

  Widget _item(int idx, IconData icon, IconData activeIcon) => Expanded(
        child: InkWell(
          onTap: () => onTap(idx),
          splashColor: Colors.transparent, // بدون انميشن دائري
          highlightColor: Colors.transparent,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // أيقونة Outline تتملي عند التفعيل
                AnimatedScale(
                  scale: current == idx ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 250), // أنميشن 2026 ناعم
                  curve: Curves.easeOut,
                  child: Icon(
                    current == idx ? activeIcon : icon,
                    color: current == idx ? AppColors.primary : AppColors.textSub,
                    size: 26,
                  ),
                ),
                // خط صغير تحت الأيقونة النشطة - ستايل يوتيوب
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.only(top: 4),
                  height: 2,
                  width: current == idx ? 20 : 0,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _notifItem() => Expanded(
        child: InkWell(
          onTap: () => onTap(3),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: current == 3 ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        current == 3 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                        color: current == 3 ? AppColors.primary : AppColors.textSub,
                        size: 26,
                      ),
                      if (notifCount > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.bgCard, width: 1.5),
                            ),
                            constraints: const BoxConstraints(minWidth: 18),
                            child: Text(
                              notifCount > 99 ? '99+' : '$notifCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Tajawal',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.only(top: 4),
                  height: 2,
                  width: current == 3 ? 20 : 0,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
