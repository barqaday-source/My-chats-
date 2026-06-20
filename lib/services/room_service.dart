import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/supabase_config.dart';
import '../models/room_model.dart';

class RoomService {
  final _sb = Supabase.instance.client;

  // --- Rooms ---
  Future<List<RoomModel>> getRooms() async {
    try {
      final data = await _sb
          .from(SupabaseConfig.tRooms)
          .select()
          .eq('is_approved', true)
          .order('is_official', ascending: false)
          .order('online_count', ascending: false)
          .order('member_count', ascending: false);
      return (data as List)
          .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e, s) {
      debugPrint('❌ Supabase Error - getRooms: ${e.message}\n$s');
      return [];
    } catch (e, s) {
      debugPrint('❌ Unknown Error - getRooms: $e\n$s');
      return [];
    }
  }

  Future<RoomModel?> getRoom(String id) async {
    try {
      final data = await _sb.from(SupabaseConfig.tRooms).select().eq('id', id).maybeSingle();
      return data != null ? RoomModel.fromJson(data) : null;
    } catch (e) {
      debugPrint('getRoom error: $e');
      return null;
    }
  }

  Future<RoomModel> createRoom(RoomModel room, String userId) async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    if (user.id != userId) throw Exception('userId mismatch with auth.uid()');

    final data = room.toJson()
      ..['owner_id'] = userId
      ..['created_by'] = userId
      ..['members'] = [userId];

    final response = await _sb.from(SupabaseConfig.tRooms).insert(data).select().single();
    final newRoom = RoomModel.fromJson(response);
    await joinRoom(newRoom.id, userId);
    return newRoom;
  }

  Future<void> updateRoom(RoomModel room) async {
    await _sb.from(SupabaseConfig.tRooms).update(room.toJson()).eq('id', room.id);
  }

  Future<void> deleteRoom(String roomId) async {
    await _sb.from(SupabaseConfig.tRooms).delete().eq('id', roomId);
  }

  // --- Members ---
  Future<void> joinRoom(String roomId, String userId) async {
    try {
      await _sb.from(SupabaseConfig.tRoomMembers).upsert({
        'room_id': roomId,
        'user_id': userId,
        'joined_at': DateTime.now().toIso8601String(),
        'is_online': true,
      });
      await _sb.rpc('increment_room_member', params: {'room_id': roomId});
    } catch (e) {
      debugPrint('joinRoom error: $e');
    }
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    await _sb.from(SupabaseConfig.tRoomMembers).delete().eq('room_id', roomId).eq('user_id', userId);
    await _sb.rpc('decrement_room_member', params: {'room_id': roomId});
  }

  Future<bool> isMember(String roomId, String userId) async {
    final data = await _sb.from(SupabaseConfig.tRoomMembers)
        .select()
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .maybeSingle();
    return data != null;
  }

  Future<List<Map<String, dynamic>>> getRoomMembers(String roomId) async {
    final res = await _sb
        .from(SupabaseConfig.tRoomMembers)
        .select('*, users(*)')
        .eq('room_id', roomId)
        .order('is_online', ascending: false);
    return res.map((m) => {
      ...m['users'] as Map<String, dynamic>,
      'is_online': m['is_online'] ?? false,
      'last_seen': m['last_seen'],
    }).toList();
  }

  Future<void> removeRoomMember(String roomId, String userId) async {
    await _sb.from(SupabaseConfig.tRoomMembers).delete().eq('room_id', roomId).eq('user_id', userId);
    await _sb.rpc('decrement_room_member', params: {'room_id': roomId});
  }

  Future<void> updateRoomImage(String roomId, String imageUrl) async {
    await _sb.from(SupabaseConfig.tRooms).update({'image_url': imageUrl}).eq('id', roomId);
  }

  // --- Upload ---
  Future<String> uploadRoomImage(File file, String roomId) async {
    final ext = file.path.split('.').last;
    final path = 'rooms/$roomId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _sb.storage.from('chat_media').upload(
      path,
      file,
      fileOptions: const FileOptions(upsert: true),
    );

    return _sb.storage.from('chat_media').getPublicUrl(path);
  }

  Future<void> approveRoom(String roomId) async {
    await _sb.from(SupabaseConfig.tRooms).update({'is_approved': true}).eq('id', roomId);
  }

  // --- Messages - موحد مع PrivateChat ---
  /// stream رسائل الغرفة، نفس شكل messages الخاصة
  Stream<List<Map<String, dynamic>>> getRoomMessagesStream(String roomId) {
    return _sb
        .from(SupabaseConfig.tRoomMessages)
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .map((maps) => maps);
  }

  /// إرسال رسالة غرفة – content '' بدل null
  Future<void> sendRoomMessage({
    required String roomId,
    required String senderId,
    String text = '',
    String? imageUrl,
    String? voiceUrl,
  }) async {
    await _sb.from(SupabaseConfig.tRoomMessages).insert({
      'room_id': roomId,
      'sender_id': senderId,
      'content': text.isEmpty ? '' : text,
      'media_url': imageUrl,
      'audio_url': voiceUrl,
      'type': voiceUrl != null ? 'audio' : imageUrl != null ? 'image' : 'text',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// حذف حقيقي
  Future<void> deleteRoomMessage(String messageId) async {
    await _sb.from(SupabaseConfig.tRoomMessages).delete().eq('id', messageId);
  }

  // --- Online ---
  Future<void> setOnline(String roomId, String userId) async {
    await _sb.rpc('set_user_online_room', params: {
      'room_id_input': roomId,
      'user_id_input': userId,
    });
  }

  Future<void> setOffline(String roomId, String userId) async {
    await _sb.rpc('set_user_offline_room', params: {
      'room_id_input': roomId,
      'user_id_input': userId,
    });
  }
}
