import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: BoxDecoration(gradient: AppColors.bgGrad),
      child: SafeArea(child: Column(children: [
        AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text('سياسة الخصوصية')),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.glassBorder)),
          child: Text(AppStrings.privacyText, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 14, height: 1.8)),
        ))),
      ])),
    ),
  );
}
