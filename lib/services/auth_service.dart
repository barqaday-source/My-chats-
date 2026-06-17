import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/supabase_config.dart';

class AuthService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _supabase.auth.signInWithPassword(email: email, password: password);
      if (res.user == null) throw Exception('Login failed: user null');
      return res;
    } on AuthException catch (e, s) {
      debugPrint('❌ Auth Error - signIn\nCode: ${e.statusCode}\nMessage: ${e.message}\n$s');
      rethrow;
    }
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    try {
      final res = await _supabase.auth.signUp(email: email, password: password, data: data);
      if (res.user!= null) {
        // التعديل 5: إنشاء user بـ جدول users مباشرة بعد التسجيل
        await _supabase.from('users').insert({
          'id': res.user!.id,
          'email': email,
          'username': data?['username']?? email.split('@')[0],
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      return res;
    } on AuthException catch (e, s) {
      debugPrint('❌ Auth Error - signUp\nCode: ${e.statusCode}\nMessage: ${e.message}\n$s');
      rethrow;
    } on PostgrestException catch (e, s) {
      debugPrint('❌ Supabase Error - signUp insert user\nCode: ${e.code}\nMessage: ${e.message}\nDetails: ${e.details}\nHint: ${e.hint}\n$s');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _supabase.from('users').select();
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e, s) {
      debugPrint('❌ Supabase Error - getAllUsers\nCode: ${e.code}\nMessage: ${e.message}\nDetails: ${e.details}\nHint: ${e.hint}\n$s');
      return [];
    }
  }

  // التعديل 6: تحديث users مو profiles + Logging
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('No authenticated user');

      await _supabase.from('users').update(data).eq('id', userId).select();
      return true;
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - updateProfile
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
      return false;
    } catch (e, s) {
      debugPrint('❌ Unknown Error - updateProfile: $e\n$s');
      return false;
    }
  }
}
