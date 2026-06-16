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
        bottom: true, // 👈 رفع الشريط ذكياً فوق أزرار نظام الأندرويد لضمان حساسية الضغط
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), // تنسيق المسافات ليعطي مظهراً عائماً فخماً
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // تأثير الزجاج الضبابي (Glassmorphism)
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.navBar.withOpacity(0.92), // البياض النقي الشفاف المتناسق مع الثيم
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.glassBorder, width: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _item(0, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'الدردشات'),
                    _item(1, Icons.meeting_room_outlined, Icons.meeting_room_rounded, 'الغرف'),
                    _item(2, Icons.person_outline_rounded, Icons.person_rounded, 'الملف'),
                    _notifItem(), // ✅ الإشعارات مكان المنيو
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _item(int idx, IconData icon, IconData activeIcon, String label) => GestureDetector(
        onTap: () => onTap(idx),
        behavior: HitTestBehavior.opaque, // يوسع مساحة الضغط لتشمل كامل محيط الأيقونة
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: current == idx ? AppColors.primary.withOpacity(0.15) : Colors.transparent, // الخلفية النعناعية الشفيفة عند التفعيل
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            current == idx ? activeIcon : icon,
            color: current == idx ? AppColors.primary : AppColors.textSub, // النعناعي الأساسي للنشط والرمادي للمطفي
            size: 24,
          ),
        ),
      );

  Widget _notifItem() => GestureDetector(
        onTap: () => onTap(3), // ✅ اندكس 3 للإشعارات
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: current == 3 ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                current == 3 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                color: current == 3 ? AppColors.primary : AppColors.textSub,
                size: 24,
              ),
              if (notifCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.danger, // لون التنبيه الأحمر الصافي الثابت عندك
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$notifCount',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
