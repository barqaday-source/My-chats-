import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('isDark') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', _isDark);
    notifyListeners();
  }

  ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Tajawal',
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        primaryColor: const Color(0xFF00D4AA),
        cardColor: const Color(0xFFF8F9FA),
        dividerColor: const Color(0xFFE5E7EB),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF111827)),
          bodyMedium: TextStyle(color: Color(0xFF6B7280)),
        ),
      );

  ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Tajawal',
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00D4AA),
        cardColor: const Color(0xFF1E1E1E),
        dividerColor: const Color(0xFF2C2C2C),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFE5E7EB)),
          bodyMedium: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );
}
