import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../core/constants/supabase_config.dart';
import '../services/presence_service.dart';
import '../main.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final supabase = Supabase.instance.client;

  User? _authUser;
  UserModel? _profile;
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;

  RealtimeChannel? _banChannel;

  // للتوافق مع الكود القديم
  User? get currentUser => _authUser;
  // هذا اللي تستخدمه شاشات المحفظة / البروفايل
  UserModel? get user => _profile;
  
  bool get isLoading => _isLoading;
  bool get loading => _isLoading;
  String? get error => _error;
  bool get initialized => _initialized;
  bool get isLoggedIn => _authUser != null;
  bool get isAuthenticated => _authUser != null;
  
  // للتوافق القديم - يرجع Map
  Map<String, dynamic>? get userProfile => _profile?.toJson();

  AuthProvider() {
    checkSession();
    _authService.authStateChanges.listen((data) async {
      _authUser = data.session?.user;
      if (_authUser != null) {
        await _loadUserProfile();
        if (_authUser != null) {
          _startPresence();
          _startBanWatch();
        }
      } else {
        await _stopPresence();
        _profile = null;
      }
      notifyListeners();
    });
  }

  Future<void> checkSession() async {
    _authUser = _authService.currentUser;
    if (_authUser != null) {
      await _loadUserProfile();
      if (_authUser != null) {
        _startPresence();
        _startBanWatch();
      }
    }
    _initialized = true;
    notifyListeners();
  }

  void _startPresence() {
    PresenceService().init();
  }

  Future<void> _stopPresence() async {
    _banChannel?.unsubscribe();
    _banChannel = null;
    PresenceService().close();
  }

  void _startBanWatch() {
    if (_authUser == null) return;
    _banChannel?.unsubscribe();
    _banChannel = SupabaseConfig.client
        .channel('ban_watch_${_authUser!.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConfig.tUsers,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _authUser!.id,
          ),
          callback: (payload) {
            final banned = payload.newRecord['is_banned'] == true;
            if (banned) {
              _handleBanned();
            }
          },
        )
        .subscribe();
  }

  Future<void> _handleBanned() async {
    _error = 'تم حظر حسابك';
    await _stopPresence();
    await _authService.signOut();
    _authUser = null;
    _profile = null;
    notifyListeners();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _loadUserProfile() async {
    try {
      if (_authUser == null) return;
      final res = await SupabaseConfig.client
          .from(SupabaseConfig.tUsers)
          .select()
          .eq('id', _authUser!.id)
          .maybeSingle();
      
      if (res == null) {
        _profile = null;
        return;
      }

      // فحص الحظر
      if (res['is_banned'] == true) {
        await _handleBanned();
        return;
      }

      _profile = UserModel.fromJson(res);
    } catch (e) {
      _profile = null;
    }
  }

  // تحديث بيانات المستخدم - للاستخدام بعد الشراء
  Future<void> refreshUser() async {
    await _loadUserProfile();
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.signInWithEmail(email: email, password: password);
      _authUser = _authService.currentUser;
      
      if (_authUser != null) {
        await _loadUserProfile();
        if (_profile == null && _authUser != null) {
          // محظور، _handleBanned اشتغلت
          _isLoading = false;
          notifyListeners();
          return false;
        }
        _startPresence();
        _startBanWatch();
      }

      _isLoading = false;
      notifyListeners();
      return _authUser != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String name) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final res = await _authService.signUpWithEmail(
        email: email,
        password: password,
        data: {'username': name}
      );

      if (res.user != null) {
        await SupabaseConfig.client.from(SupabaseConfig.tUsers).upsert({
          'id': res.user!.id,
          'email': email,
          'username': name,
          'is_online': true,
          'last_seen': DateTime.now().toIso8601String(),
          'is_banned': false,
          'coins': 0,
        }, onConflict: 'id');
        _authUser = res.user;
        await _loadUserProfile();
        if (_authUser != null) {
          _startPresence();
          _startBanWatch();
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signIn(String email, String password) async {
    await login(email, password);
  }

  Future<void> signUp(String email, String password, Map<String, dynamic>? data) async {
    await register(email, password, data?['username'] ?? '');
  }

  Future<void> logout() async {
    await signOut();
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _stopPresence();
      await _authService.signOut();
      _profile = null;
      _authUser = null;

      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      notifyListeners();

      final success = await _authService.updateProfile(data);
      if (success) {
        await _loadUserProfile();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> resetPassword(String email) async {
    await _authService.resetPassword(email);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
