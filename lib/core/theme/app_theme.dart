import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static const double kRadius = 20.0;
  static const String fontFamily = 'Tajawal';

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: fontFamily,
      
      // إعدادات شريط التطبيق العلوي
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.text),
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),

      // إعدادات ألوان الأزرار الافتراضية في التطبيق
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
      ),

      // إعدادات حقول الإدخال بنمط نعناعي نظيف
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: AppColors.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),

      // --- إضافات UI فقط ---
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1.5,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.black87,
          fontSize: 14,
        ),
      ),

      // توحيد الخطوط والأحجام
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: fontFamily, fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text),
        titleLarge: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
        bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: 15, color: AppColors.text, height: 1.4),
        bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: 13, color: AppColors.text),
        labelLarge: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600),
      ),

      iconTheme: const IconThemeData(size: 22, color: AppColors.text),
    );
  }

  // --- وضع داكن كامل، UI فقط ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: const Color(0xFF121318),
      fontFamily: fontFamily,

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121318),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white70),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C1E24),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1C1E24),
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: fontFamily, fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        titleLarge: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: 15, color: Colors.white70, height: 1.4),
        bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: 13, color: Colors.white54),
        labelLarge: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      ),

      iconTheme: const IconThemeData(size: 22, color: Colors.white70),
    );
  }
}
