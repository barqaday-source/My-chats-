import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class AuthService {
  final SupabaseClient _client = StorageService.client;

  // ===== الدوال اللي يطلبها auth_provider.dart =====

  Future<Map<String, dynamic>> fetchUserProfile(String userId) async {
    try {
      final res = await _client.from('profiles').select().eq('id', userId).maybeSingle();
      return res?? {};
    } catch (e) {
      debugPrint("fetchUserProfile error: $e");
      return {};
    }
  }

  Future<Map<String, dynamic>> signInWithEmail(String email, String password) async {
    final res = await _client.auth.signInWithPassword(email: email, password: password);
    return {'id': res.user?.id};
  }

  Future<void> setOnline() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('profiles').update({'is_online': true, 'last_seen': DateTime.now().toIso8601String()}).eq('id', user.id);
    } catch (e) {
      debugPrint("setOnline error: $e");
    }
  }

  Future<void> setOffline() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('profiles').update({'is_online': false, 'last_seen': DateTime.now().toIso8601String()}).eq('id', user.id);
    } catch (e) {
      debugPrint("setOffline error: $e");
    }
  }

  Future<Map<String, dynamic>> signUp(String email, String password, String username) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username}
    );

    if (res.user!= null) {
      await _client.from('profiles').insert({
        'id': res.user!.id,
        'email': email,
        'username': username,
        'created_at': DateTime.now().toIso8601String(),
        'is_online': false,
      });
    }
    return {'id': res.user?.id};
  }

  Future<void> signOut() async {
    await setOffline();
    await _client.auth.signOut();
  }

  Future<Map<String, dynamic>> updateProfile(String uid, Map<String, dynamic> data) async {
    await _client.from('profiles').update(data).eq('id', uid);
    return data;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final res = await _client.from('profiles').select('*').order('username', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint("getAllUsers error: $e");
      return [];
    }
  }

  // ===== دوال مساعدة =====
  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => _client.auth.currentUser!= null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
