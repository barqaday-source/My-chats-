import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  static const url = 'https://vohlleqcuomudoryiwkc.supabase.co';
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvaGxsZXFjdW9tdWRvcnlpd2tjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MjE3NzAsImV4cCI6MjA5NzE5Nzc3MH0.VNUs7_WXzAeSz5TC_aD56FfzFQkmc_p99PY_b7hPZYU';

  static bool _initialized = false;

  static Future<bool> init() async {
    if (_initialized) return true;
    
    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 10,
        ),
        debug: kDebugMode,
      );
      
      _initialized = true;
      debugPrint("Supabase connected successfully");
      return true;
    } catch (e) {
      debugPrint("Supabase init failed: $e");
      return false;
    }
  } 

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;
  static bool get isInitialized => _initialized;
}
