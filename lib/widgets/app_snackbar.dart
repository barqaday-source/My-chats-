import 'package:flutter/material.dart';
import 'package:mychats/core/constants/app_colors.dart';

void showAppSnack(BuildContext context, String msg, {bool success = true}) {
  final color = success ? AppColors.success : AppColors.danger;
  final icon = success ? Icons.check_circle_rounded : Icons.error_outline_rounded;

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                color: AppColors.text,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}
