import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  static const url = 'https://vohlleqcuomudoryiwkc.supabase.co';
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvaGxsZXFjdW9tdWRvcnlpd2tjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MjE3NzAsImV4cCI6MjA5NzE5Nzc3MH0.VNUs7_WXzAeSz5TC_aD56FfzFQkmc_p99PY_b7hPZYU';

  // Tables
  static const tUsers = 'users';
  static const tRooms = 'rooms';
  static const tMessages = 'messages';
  static const tPrivateMessages = 'private_messages'; // ضيف هذا
  static const tRoomMessages = 'room_messages'; // ضيف هذا
  static const tNotifications = 'notifications';
  static const tReports = 'reports';
  static const tRoomMembers = 'room_members';
  static const tPrivateChats = 'private_chats';
  static const tBlockedUsers = 'blocked_users'; 
  static const tContactInfo = 'contact_info';
  static const tBlocks = 'blocks';
  static const tAdmins = 'admins'; // ضيف هذا

  // Storage buckets - محدثة للأسماء الجديدة
  static const bucketAvatars = 'avatars';
  static const bucketRooms = 'room-images'; 
  static const bucketMedia = 'chat_images'; // كان chat-media
  static const bucketAudio = 'voice_messages'; // كان audio-messages

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
