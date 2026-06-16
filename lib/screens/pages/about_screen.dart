import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: BoxDecoration(gradient: AppColors.bgGrad), // التدرج النعناعي الأبيض المعتمد
      child: SafeArea(
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent, 
              elevation: 0, 
              title: const Text(
                'حول التطبيق',
                style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontWeight: FontWeight.w700),
              ),
              iconTheme: const IconThemeData(color: AppColors.text), // لضمان ظهور سهم العودة باللون الداكن الواضح
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      // ─── المربع النعناعي الفخم بالهوية الجديدة ─────────────────
                      Container(
                        width: 130, height: 95, // أبعاد متناسقة ومريحة جداً لمحيط النص الجديد
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24), 
                          gradient: AppColors.primaryGrad, 
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4), 
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'SeaChat', // 👈 تم تغييرها لاسم التطبيق بالإنجليزية ليتطابق مع واجهة الترحيب
                            style: TextStyle(
                              fontFamily: 'Tajawal', 
                              color: AppColors.white, 
                              fontSize: 24, 
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // 💡 تم إلغاء النصوص البيضاء القديمة المختفية واستبدالها بالاسم العربي الواضح والمريح للعين
                      const Text(
                        'سي شات', 
                        style: TextStyle(
                          fontFamily: 'Tajawal', 
                          color: AppColors.text, // لون داكن صافي يظهر بوضوح فوق البياض
                          fontSize: 24, 
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // ─── كبسولة رقم الإصدار الحقيقي للنسخة الأولى ───────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), 
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1), 
                          borderRadius: BorderRadius.circular(20), 
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'الإصدار 1.0.0+1', // 👈 النسخة الأولى الحقيقية المطابقة للـ pubspec
                          style: TextStyle(
                            fontFamily: 'Tajawal', 
                            color: AppColors.primaryDark, // النعناعي العميق لسهولة القراءة
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      
                      // ─── مربع وصف التطبيق الآمن ─────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20), 
                        decoration: BoxDecoration(
                          color: AppColors.bgCard, // الرمادي الفخم الخفيف جداً المعتمد عندك
                          borderRadius: BorderRadius.circular(22), 
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: const Text(
                          'سي شات هو تطبيق دردشة اجتماعي متكامل يتيح لك التواصل مع الأصدقاء والانضمام إلى غرف الدردشة المتنوعة والاستمتاع بتجربة تواصل آمنة ومشفرة.',
                          textAlign: TextAlign.center, 
                          style: TextStyle(
                            fontFamily: 'Tajawal', 
                            color: AppColors.text, 
                            fontSize: 14, 
                            height: 1.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // ─── تذييل الصفحة وحقوق النشر لسنة 2026 ──────────────────────────
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                '© 2026 سي شات. جميع الحقوق محفوظة.', // 👈 إثبات الحقوق الحالية باحترافية كاملة
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  color: AppColors.textSub, // الرمادي الفرعي المتناسق
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
