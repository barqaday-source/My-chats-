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

      // --- فحص الحظر ---
      try {
        final userData = await _supabase
           .from('profiles')
           .select('is_blocked')
           .eq('id', res.user!.id)
           .maybeSingle();

        if (userData!= null && userData['is_blocked'] == true) {
          await _supabase.auth.signOut();
          throw AuthException('تم حظر هذا الحساب نهائيا من قبل الإدارة');
        }
      } catch (e) {
        // إذا كان الخطأ هو الحظر نفسه، ارميه لفوق
        if (e is AuthException && e.message.contains('تم حظر')) rethrow;
        // غير ذلك، تجاهل خطأ قراءة is_blocked حتى لا نمنع دخول مستخدم سليم إذا العمود ناقص
        debugPrint('Block check warning: $e');
      }

      return res;
    } on AuthException catch (e, s) {
      debugPrint('''
      ❌ Auth Error - signIn
      Code: ${e.statusCode}
      Message: ${e.message}
      $s
      ''');
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
        await _supabase.from('profiles').upsert({
          'id': res.user!.id,
          'email': email,
          'username': data?['username']?? email.split('@')[0],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      return res;
    } on AuthException catch (e, s) {
      debugPrint('''
      ❌ Auth Error - signUp
      Code: ${e.statusCode}
      Message: ${e.message}
      $s
      ''');
      rethrow;
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - signUp insert user
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
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
      final response = await _supabase.from('profiles').select();
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - getAllUsers
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
      return [];
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('No authenticated user');

      data['id'] = userId;
      data['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.from('profiles').upsert(data).select();
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
