import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/user_model.dart';
import '../core/constants/supabase_config.dart'; // استدعاء الكونفج لتوحيد أسماء الجداول

class AuthProvider extends ChangeNotifier {
  final sb.SupabaseClient _supabase = sb.Supabase.instance.client;
  StreamSubscription<sb.AuthState>? _authSubscription;

  bool _initialized = false;
  bool _isLoggedIn = false;
  UserModel? _currentUser;
  String? _errorMessage;

  bool get initialized => _initialized;
  bool get isLoggedIn => _isLoggedIn;
  bool get loading => !_initialized;
  UserModel? get user => _currentUser;
  UserModel? get currentUser => _currentUser;
  String? get error => _errorMessage;

  bool get isMod {
    if (_currentUser == null) return false;
    final role = _currentUser!.role;
    return role == 'admin' || role == 'moderator';
  }

  AuthProvider() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen(_handleAuthChange);
    checkSession();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleAuthChange(sb.AuthState data) async {
    final event = data.event;
    final session = data.session;

    if ((event == sb.AuthChangeEvent.signedIn || event == sb.AuthChangeEvent.tokenRefreshed) && session != null) {
      _isLoggedIn = true;
      await _loadUserProfile(session.user.id, session.user.email);
    } else if (event == sb.AuthChangeEvent.signedOut) {
      _isLoggedIn = false;
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<void> _loadUserProfile(String userId, String? email) async {
    try {
      // 🛠️ تم التصحيح: استدعاء جدول users المتوافق مع قاعدتك الـ SQL بدلاً من profiles
      final data = await _supabase.from(SupabaseConfig.tUsers).select().eq('id', userId).maybeSingle();
      
      if (data != null) {
        _currentUser = UserModel.fromMap(data);
      } else {
        // دعم حسابات الزوار (Anonymous) لكي لا ينهار التطبيق في حالة الـ Email Null
        String defaultUsername = 'user_${userId.substring(0, 6)}';
        if (email != null && email.contains('@')) {
          defaultUsername = email.split('@').first;
        }

        final fallback = await _supabase.from(SupabaseConfig.tUsers).upsert({
          'id': userId,
          'email': email,
          'username': defaultUsername,
          'role': 'user',
        }).select().single();
        _currentUser = UserModel.fromMap(fallback);
      }
    } catch (e) {
      debugPrint("Error loading user profile: $e");
      String defaultUsername = 'user_${userId.substring(0, 6)}';
      if (email != null && email.contains('@')) {
        defaultUsername = email.split('@').first;
      }
      _currentUser = UserModel(
        id: userId,
        email: email,
        username: defaultUsername,
        role: 'user',
        isOnline: true,
        createdAt: DateTime.now(),
      );
    }
  }

  Future<bool> checkSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        _isLoggedIn = false;
        _currentUser = null;
      } else {
        // 🛠️ تم التصحيح: محاولة تجديد الجلسة تلقائياً إذا كانت منتهية بدلاً من الطرد الفوري
        if (session.isExpired) {
          try {
            final refreshedSession = await _supabase.auth.refreshSession();
            if (refreshedSession.session != null) {
              _isLoggedIn = true;
              await _loadUserProfile(refreshedSession.session!.user.id, refreshedSession.session!.user.email);
              return _isLoggedIn;
            }
          } catch (_) {
            // فشل التجديد الشبكي
          }
        }
        _isLoggedIn = true;
        await _loadUserProfile(session.user.id, session.user.email);
      }
    } catch (e) {
      _isLoggedIn = false;
      _currentUser = null;
      _errorMessage = 'فشل التحقق من الجلسة';
    } finally {
      _initialized = true;
      notifyListeners();
    }
    return _isLoggedIn;
  }

  Future<bool> login(String email, String password) async {
    try {
      _errorMessage = null;
      notifyListeners();
      await _supabase.auth.signInWithPassword(email: email, password: password);
      return true;
    } on sb.AuthException catch (_) {
      _errorMessage = 'فشل تسجيل الدخول';
      _isLoggedIn = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'فشل تسجيل الدخول';
      _isLoggedIn = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String username) async {
    try {
      _errorMessage = null;
      notifyListeners();
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username.trim()},
      );
      return res.user != null;
    } on sb.AuthException catch (_) {
      _errorMessage = 'فشل إنشاء الحساب';
      _isLoggedIn = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'فشل إنشاء الحساب';
      _isLoggedIn = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String username) async {
    return await signUp(email, password, username);
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      _errorMessage = null;
      if (_currentUser == null) return false;

      // 🛠️ تم التصحيح: استدعاء جدول users لتحديث البروفايل بنجاح
      final updated = await _supabase
          .from(SupabaseConfig.tUsers)
          .update(data)
          .eq('id', _currentUser!.id)
          .select()
          .single();

      _currentUser = UserModel.fromMap(updated);
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'فشل تحديث البروفايل';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {} finally {
      _isLoggedIn = false;
      _currentUser = null;
      _errorMessage = null;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

