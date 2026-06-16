import 'package:flutter/material.dart';

class AppColors {
  // الخلفيات - ابيض
  static const Color bg       = Color(0xFFFFFFFF);
  static const Color bgCard   = Color(0xFFF8F9FA);
  static const Color bgCard2  = Color(0xFFF1F3F5);

  // النعناعي للايقونات والازرار فقط
  static const Color primary      = Color(0xFF00D4AA);
  static const Color primaryLight = Color(0xFF33DDC2);
  static const Color primaryDark  = Color(0xFF00AA88);

  static const Color glass       = Color(0x1A00D4AA);
  static const Color glassBorder = Color(0x2B00D4AA);

  static const Color accent  = Color(0xFF00D4AA);
  static const Color danger  = Color(0xFFFF4757);
  static const Color warning = Color(0xFFFFBB33);
  static const Color success = Color(0xFF2ED573);

  // النصوص: اسود + كحلي
  static const Color white    = Color(0xFF000000); // اسود
  static const Color white70  = Color(0xB3000000); // اسود 70%
  static const Color text     = Color(0xFF000000); // اسود اساسي
  static const Color textSub  = Color(0xFF1A237E); // كحلي للنصوص الفرعية
  static const Color textMuted = Color(0xFF1A237E); // كحلي
  
  static const Color online   = Color(0xFF2ED573);
  static const Color offline  = Color(0xFF757575);
  static const Color divider  = Color(0xFFE0E0E0);
  static const Color navBar   = Color(0xFFFFFFFF); 

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
