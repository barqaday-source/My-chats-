import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final sb.SupabaseClient _supabase = sb.Supabase.instance.client;
  StreamSubscription<sb.AuthState>? _authSubscription;

  bool _initialized = false;
  bool _isLoggedIn = false;
  UserModel? _currentUser;
  String? _errorMessage;

  bool get initialized => _initialized;
  bool get isLoggedIn => _isLoggedIn;
  bool get loading =>!_initialized;
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

    if ((event == sb.AuthChangeEvent.signedIn || event == sb.AuthChangeEvent.tokenRefreshed) && session!= null) {
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
      final data = await _supabase.from('profiles').select().eq('id', userId).maybeSingle();
      if (data!= null) {
        _currentUser = UserModel.fromMap(data);
      } else {
        final fallback = await _supabase.from('profiles').upsert({
          'id': userId,
          'email': email,
          'username': email?.split('@').first?? 'user_${userId.substring(0, 6)}',
          'role': 'user',
        }).select().single();
        _currentUser = UserModel.fromMap(fallback);
      }
    } catch (e) {
      _currentUser = UserModel(
        id: userId,
        email: email,
        username: email?.split('@').first?? 'user',
        role: 'user',
        isOnline: true,
        createdAt: DateTime.now(),
      );
    }
  }

  Future<bool> checkSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null || session.isExpired) {
        _isLoggedIn = false;
        _currentUser = null;
      } else {
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
      return res.user!= null;
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

  // ✅ هذي الدالة اللي كانت ناقصة
  Future<bool> register(String email, String password, String username) async {
    return await signUp(email, password, username);
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      _errorMessage = null;
      if (_currentUser == null) return false;

      final updated = await _supabase
         .from('profiles')
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
