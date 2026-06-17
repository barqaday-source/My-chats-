import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../core/constants/supabase_config.dart';

class StorageService {
  // استخدم SupabaseConfig مباشرة - حذف التضارب
  static SupabaseStorageClient get storage => SupabaseConfig.storage;

  Future<String?> uploadChatMedia(String chatId, File file, String type) async {
    try {
      final fileExt = path.extension(file.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$type$fileExt';
      final filePath = 'chats/$chatId/$fileName';
      await storage.from(SupabaseConfig.bucketMedia).upload(filePath, file);
      return storage.from(SupabaseConfig.bucketMedia).getPublicUrl(filePath);
    } on StorageException catch (e, s) {
      debugPrint('''
      ❌ Storage Error - uploadChatMedia
      StatusCode: ${e.statusCode}
      Message: ${e.message}
      Error: ${e.error}
      $s
      ''');
      return null;
    }
  }

  Future<String?> uploadRoomImage(String roomId, File file) async {
    try {
      final fileExt = path.extension(file.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_room$fileExt';
      final filePath = 'rooms/$roomId/$fileName';
      await storage.from(SupabaseConfig.bucketRooms).upload(filePath, file);
      return storage.from(SupabaseConfig.bucketRooms).getPublicUrl(filePath);
    } on StorageException catch (e, s) {
      debugPrint('''
      ❌ Storage Error - uploadRoomImage
      StatusCode: ${e.statusCode}
      Message: ${e.message}
      Error: ${e.error}
      $s
      ''');
      return null;
    }
  }

  Future<String?> uploadAvatar(String userId, File file) async {
    try {
      final fileExt = path.extension(file.path);
      final fileName = '${userId}_avatar$fileExt';
      final filePath = 'public/$fileName';
      await storage.from(SupabaseConfig.bucketAvatars).upload(
        filePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );
      return storage.from(SupabaseConfig.bucketAvatars).getPublicUrl(filePath);
    } on StorageException catch (e, s) {
      debugPrint('''
      ❌ Storage Error - uploadAvatar
      StatusCode: ${e.statusCode}
      Message: ${e.message}
      Error: ${e.error}
      $s
      ''');
      return null;
    }
  }

  Future<bool> deleteFile(String bucket, String filePath) async {
    try {
      await storage.from(bucket).remove([filePath]);
      return true;
    } on StorageException catch (e, s) {
      debugPrint('''
      ❌ Storage Error - deleteFile
      StatusCode: ${e.statusCode}
      Message: ${e.message}
      Error: ${e.error}
      $s
      ''');
      return false;
    }
  }
}
