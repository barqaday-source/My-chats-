import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class ActivityBadge extends StatelessWidget {
  final DateTime createdAt;
  const ActivityBadge({super.key, required this.createdAt});

  @override
  Widget build(BuildContext context) {
    final days = DateTime.now().difference(createdAt).inDays;
    
    String label;
    IconData icon;
    Color color;

    if (days >= 90) {
      label = 'أسطوري';
      icon = Icons.workspace_premium_rounded;
      color = const Color(0xFFF59E0B);
    } else if (days >= 30) {
      label = 'مميز';
      icon = Icons.stars_rounded;
      color = const Color(0xFF8B5CF6);
    } else if (days >= 7) {
      label = 'نشيط';
      icon = Icons.local_fire_department_rounded;
      color = const Color(0xFF10B981);
    } else {
      label = 'عضو جديد';
      icon = Icons.spa_rounded;
      color = AppColors.textSub;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
