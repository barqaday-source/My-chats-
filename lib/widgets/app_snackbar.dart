import 'package:flutter/material.dart';
import 'package:mychats/core/constants/app_colors.dart';

void showAppSnack(BuildContext context, String msg, {bool success = true}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Tajawal')),
      backgroundColor: success ? AppColors.success : AppColors.danger,
    ),
  );
}
