import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_config.dart';

class AuthService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await _supabase.from(SupabaseConfig.tUsers).select();
    return List<Map<String, dynamic>>.from(response);
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      
      await _supabase.from(SupabaseConfig.tUsers).update(data).eq('id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
