import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../core/constants/supabase_config.dart';
import '../services/presence_service.dart';
import '../main.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;
  Map<String, dynamic>? _userProfile;

  RealtimeChannel? _banChannel;

  User? get currentUser => _user;
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get loading => _isLoading;
  String? get error => _error;
  bool get initialized => _initialized;
  bool get isLoggedIn => _user != null;
  bool get isAuthenticated => _user != null;
  Map<String, dynamic>? get userProfile => _userProfile;

  AuthProvider() {
    checkSession();
    _authService.authStateChanges.listen((data) async {
      _user = data.session?.user;
      if (_user != null) {
        await _loadUserProfile();
        if (_user != null) {
          _startPresence();
          _startBanWatch();
        }
      } else {
        await _stopPresence();
        _userProfile = null;
      }
      notifyListeners();
    });
  }

  Future<void> checkSession() async {
    _user = _authService.currentUser;
    if (_user != null) {
      await _loadUserProfile();
      if (_user != null) {
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
    if (_user == null) return;
    _banChannel?.unsubscribe();
    _banChannel = SupabaseConfig.client
        .channel('ban_watch_${_user!.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConfig.tUsers,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _user!.id,
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
    _user = null;
    _userProfile = null;
    notifyListeners();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _loadUserProfile() async {
    try {
      if (_user == null) return;
      final res = await SupabaseConfig.client
          .from(SupabaseConfig.tUsers)
          .select()
          .eq('id', _user!.id)
          .maybeSingle();
      
      if (res == null) {
        _userProfile = null;
        return;
      }

      // فحص الحظر
      if (res['is_banned'] == true) {
        await _handleBanned();
        return;
      }

      _userProfile = res;
    } catch (e) {
      _userProfile = null;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.signInWithEmail(email: email, password: password);
      _user = _authService.currentUser;
      
      if (_user != null) {
        await _loadUserProfile();
        if (_user == null) {
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
      return _user != null;
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
        }, onConflict: 'id');
        _user = res.user;
        await _loadUserProfile();
        if (_user != null) {
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
      _userProfile = null;
      _user = null;

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
