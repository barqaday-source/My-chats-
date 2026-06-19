import 'package:flutter/material.dart';

class AppColors {
  // الخلفيات - أبيض
  static const Color bg = Color(0xFFFFFFFF);
  static const Color bgCard = Color(0xFFF8F9FA);
  static const Color bgCard2 = Color(0xFFF1F3F5);
  static const Color bgPrimary = Color(0xFFFFFFFF);

  // الأساسي – نعناعي للنجاح فقط
  static const Color primary = Color(0xFF00D4AA);
  static const Color primaryLight = Color(0xFF33DDC2);
  static const Color primaryDark = Color(0xFF00AA88);

  // الكحلي – للتنبيهات والمعلومات
  static const Color navy = Color(0xFF1A237E);
  static const Color info = navy;

  static const Color glass = Color(0x1A00D4AA);
  static const Color glassBorder = Color(0x2B00D4AA);

  // accent كان نعناعي، حولته كحلي حسب طلبك
  static const Color accent = navy;

  // الحالات
  static const Color danger = Color(0xFFFF4757);
  static const Color warning = navy;
  static const Color success = Color(0xFF00D4AA);

  // النصوص
  static const Color white = Color(0xFF000000);      // للتوافق القديم – أسود
  static const Color white70 = Color(0xB3000000);
  static const Color text = Color(0xFF000000);
  static const Color textSub = navy;                 // كحلي
  static const Color textMuted = navy;
  static const Color textSecondary = navy;

  static const Color online = Color(0xFF00D4AA);
  static const Color offline = Color(0xFF757575);
  static const Color divider = Color(0xFFE0E0);
  static const Color navBar = Color(0xFFFFFFFF);

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
}
