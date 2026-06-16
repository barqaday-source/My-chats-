import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Container(
      decoration: BoxDecoration(gradient: AppColors.bgGrad), // تدرج مريح من الأبيض للرمادي الخفيف جداً
      child: SafeArea(
        child: Column(children: [
          const Spacer(flex: 2),
          // ─── Logo ─────────────────────────────────────────────────────────
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            builder: (_, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(offset: Offset(0, 30 * (1 - v)), child: child),
            ),
            child: Column(children: [
              // الأيقونة النعناعية الفخمة مع اسم التطبيق بالإنجليزية بداخلها
              Container(
                width: 140, height: 110, // تم توسيع العرض قليلاً بشكل متناسق ليتسع للاسم بالكامل
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: AppColors.primaryGrad,
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.45), blurRadius: 40, offset: const Offset(0, 15))],
                ),
                child: const Center(
                  child: Text(
                    'SeaChat', // 👈 تم استبدال حرف C باسم التطبيق بالإنجليزية داخل المربع بنجاح
                    style: TextStyle(
                      fontFamily: 'Tajawal', 
                      color: AppColors.white, 
                      fontSize: 26, // حجم خط متناسق ومناسب جداً لمحيط المربع الزجاجي
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              // 💡 تم حذف النصوص البيضاء المكسورة التي كانت هنا بالكامل لجعل الواجهة نظيفة ومريحة للعين
            ]),
          ),
          const Spacer(flex: 2),
          // ─── Buttons card ─────────────────────────────────────────────────
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 40 * (1 - v)), child: child)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.glass,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.glassBorder, width: 0.8),
                    ),
                    child: Column(children: [
                      Text(AppStrings.welcome, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontFamily: 'Tajawal', color: AppColors.text, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(AppStrings.welcomeSub, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'Tajawal', color: AppColors.textSub)),
                      const SizedBox(height: 28),
                      // ── تسجيل الدخول ───────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen(isLogin: true))),
                          child: const Text(AppStrings.login, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── إنشاء حساب ─────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark, // النعناعي العميق للأزرار النشطة
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen(isLogin: false))),
                          child: const Text(AppStrings.register, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    ),
  );
}
