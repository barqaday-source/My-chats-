import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class StorageService {
  static const url = 'https://jmsmrojtlstppnpwmkkk.supabase.co';
  static const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imptc21yb2p0bHN0cHBucHdta2trIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4MTg2NDAsImV4cCI6MjA4ODM5NDY0MH0.j7gxr5CvrfvbJJzK_pMwVHiCE2AqpXUTThpeLEBmsos';

  // Tables
  static const tUsers = 'profiles';
  static const tRooms = 'rooms';
  static const tMessages = 'messages';
  static const tNotifications = 'notifications';
  static const tReports = 'reports';
  static const tRoomMembers = 'room_members';
  static const tPrivateChats = 'private_chats';
  static const tBlockedUsers = 'blocked_users';
  static const tContactInfo = 'contact_info';

  // Storage buckets
  static const bucketAvatars = 'avatars';
  static const bucketRooms = 'room-images';
  static const bucketMedia = 'chat-media';
  static const bucketAudio = 'audio-messages';

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
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 10,
        ),
        debug: kDebugMode,
      );
      _initialized = true;
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

  // ===== الدوال اللي يطلبها البروفايدرز والشاشات =====

  Future<String?> uploadChatMedia(String chatId, File file, String type) async {
    try {
      final fileExt = path.extension(file.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$type$fileExt';
      final filePath = 'chats/$chatId/$fileName';
      await storage.from(bucketMedia).upload(filePath, file);
      return storage.from(bucketMedia).getPublicUrl(filePath);
    } catch (e) {
      debugPrint("uploadChatMedia error: $e");
      return null;
    }
  }

  Future<String?> uploadRoomImage(String roomId, File file) async {
    try {
      final fileExt = path.extension(file.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_room$fileExt';
      final filePath = 'rooms/$roomId/$fileName';
      await storage.from(bucketRooms).upload(filePath, file);
      return storage.from(bucketRooms).getPublicUrl(filePath);
    } catch (e) {
      debugPrint("uploadRoomImage error: $e");
      return null;
    }
  }

  Future<String?> uploadAvatar(String userId, File file) async {
    try {
      final fileExt = path.extension(file.path);
      final fileName = '${userId}_avatar$fileExt';
      final filePath = 'public/$fileName';
      await storage.from(bucketAvatars).upload(
        filePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );
      return storage.from(bucketAvatars).getPublicUrl(filePath);
    } catch (e) {
      debugPrint("uploadAvatar error: $e");
      return null;
    }
  }

  Future<bool> deleteFile(String bucket, String filePath) async {
    try {
      await storage.from(bucket).remove([filePath]);
      return true;
    } catch (e) {
      debugPrint("deleteFile error: $e");
      return false;
    }
  }
}
