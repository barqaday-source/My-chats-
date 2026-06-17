import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class StorageService {
  // التعديل 7: حذف tUsers = 'profiles' الخطأ
  static const tUsers = 'users';
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

  static SupabaseStorageClient get storage => Supabase.instance.client.storage;

  // التعديل 8: Logging كامل + upsert
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
    } on StorageException catch (e, s) {
      debugPrint('''
      ❌ Storage Error - uploadAvatar
      StatusCode: ${e.statusCode}
      Message: ${e.message}
      Error: ${e.error}
      $s
      ''');
      return null;
    } catch (e, s) {
      debugPrint('❌ Unknown Error - uploadAvatar: $e\n$s');
      return null;
    }
  }

  Future<String?> uploadChatMedia(String chatId, File file, String type) async {
    try {
      final fileExt = path.extension(file.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$type$fileExt';
      final filePath = 'chats/$chatId/$fileName';
      await storage.from(bucketMedia).upload(filePath, file);
      return storage.from(bucketMedia).getPublicUrl(filePath);
    } on StorageException catch (e, s) {
      debugPrint('❌ Storage Error - uploadChatMedia\nStatusCode: ${e.statusCode}\nMessage: ${e.message}\nError: ${e.error}\n$s');
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
    } on StorageException catch (e, s) {
      debugPrint('❌ Storage Error - uploadRoomImage\nStatusCode: ${e.statusCode}\nMessage: ${e.message}\nError: ${e.error}\n$s');
      return null;
    }
  }

  Future<bool> deleteFile(String bucket, String filePath) async {
    try {
      await storage.from(bucket).remove([filePath]);
      return true;
    } on StorageException catch (e, s) {
      debugPrint('❌ Storage Error - deleteFile\nStatusCode: ${e.statusCode}\nMessage: ${e.message}\nError: ${e.error}\n$s');
      return false;
    }
  }
}
