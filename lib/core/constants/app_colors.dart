import 'package:flutter/material.dart';

class AppColors {
  // الخلفيات - أبيض صافي للـ Light Mode
  static const Color bg = Color(0xFFFFFFFF);
  static const Color bgCard = Color(0xFFF8F9FA);
  static const Color bgCard2 = Color(0xFFF1F3F5);
  static const Color bgPrimary = Color(0xFFFFFFFF);
  
  // NEW: alias عشان الملفات اللي تستخدم card تشتغل
  static const Color card = bgCard;

  // الأساسي – نعناعي
  static const Color primary = Color(0xFF00D4AA);
  static const Color primaryLight = Color(0xFF33DDC2);
  static const Color primaryDark = Color(0xFF00AA88);

  // معلومات - رمادي بدل النيلي
  static const Color navy = Color(0xFF6B7280);
  static const Color info = Color(0xFF6B7280);

  // زجاجي - مهم جداً للـ UI 2026
  static const Color glass = Color(0x1A00D4AA); // نعناعي شفاف
  static const Color glassBg = Color(0xB2F8F9FA); // خلفية زجاجية للـ Light
  static const Color glassBgDark = Color(0xB21E1E1E); // خلفية زجاجية للـ Dark
  static const Color glassBorder = Color(0x1AFFFFFF); // أبيض شفاف للحدود - يشتغل بالدارك والفاتح
  static const Color glassBorderDark = Color(0x33FFFFFF); // أقوى للدارك

  static const Color accent = Color(0xFF00D4AA);

  // الحالات
  static const Color danger = Color(0xFFFF4757);
  static const Color warning = Color(0xFFFFA726);
  static const Color success = Color(0xFF00D4AA);

  // النصوص - كلها على أبيض
  static const Color white = Color(0xFF000000); // انت مسميه white بس هو أسود!
  static const Color black = Color(0xFF000000); // نضيف هذا أوضح
  static const Color white70 = Color(0xB3000000);
  static const Color text = Color(0xFF111827);
  static const Color textSub = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color online = Color(0xFF00D4AA);
  static const Color offline = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFE5E7EB);
  
  // NavBar شفاف مو أبيض صافي
  static const Color navBar = Color(0xB2FFFFFF); // شفاف 70%

  static const Color red = Color(0xFFFF5252);
  static const Color orange = Color(0xFFFFA726);

  static const LinearGradient primaryGrad = LinearGradient(
    colors: [Color(0xFF00D4AA), Color(0xFF33DDC2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGrad = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Dark Mode Colors - استخدمها إذا عندك ثيم ليلي
  static const Color bgDark = Color(0xFF121212);
  static const Color bgCardDark = Color(0xFF1E1E1E);
  static const Color textDark = Color(0xFFE5E7EB);
  static const Color textSubDark = Color(0xFF9CA3AF);
}
