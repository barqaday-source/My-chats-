import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  static const url = 'https://jmsmrojtlstppnpwmkkk.supabase.co';
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imptc21yb2p0bHN0cHBucHdta2trIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4MTg2NDAsImV4cCI6MjA4ODM5NDY0MH0.j7gxr5CvrfvbJJzK_pMwVHiCE2AqpXUTThpeLEBmsos';

  // Tables
  static const tUsers = 'users';
  static const tRooms = 'rooms';
  static const tMessages = 'messages';
  static const tNotifications = 'notifications';
  static const tReports = 'reports';
  static const tRoomMembers = 'room_members';
  static const tPrivateChats = 'private_chats';
  static const tBlockedUsers = 'blocked_users'; // 👈 انتبه هذا اسم جدولك
  static const tContactInfo = 'contact_info';
  static const tBlocks = 'blocks'; // 👈 لو تستخدم اسم ثاني

  // Storage buckets - لازم تطابق Supabase بالضبط
  static const bucketAvatars = 'avatars';
  static const bucketRooms = 'room-images'; // 👈 اسمك
  static const bucketMedia = 'chat-media'; // 👈 اسمك
  static const bucketAudio = 'audio-messages'; // 👈 اسمك

  static bool _initialized = false;

  static Future<bool> init() async {
  if (_initialized) return true;
  
  try {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
        // persistSession: true,  // ❌ احذف هذا السطر - نسختك ما تدعمه
      ),
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
