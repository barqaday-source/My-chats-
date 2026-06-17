import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_config.dart';
import '../models/room_model.dart';
import '../models/message_model.dart';

class RoomService {
  final _sb = Supabase.instance.client;

  Future<List<RoomModel>> getRooms() async {
    try {
      // RLS بيخلي اليوزر العادي يشوف بس is_approved = true
      final data = await _sb.from(SupabaseConfig.tRooms).select()
        .order('is_official', ascending: false)
        .order('online_count', ascending: false)
        .order('member_count', ascending: false);
      return (data as List).map((e) => RoomModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('getRooms error: $e');
      return [];
    }
  }

  Future<RoomModel?> getRoom(String id) async {
    try {
      final data = await _sb.from(SupabaseConfig.tRooms).select().eq('id', id).maybeSingle();
      return data!= null? RoomModel.fromJson(data) : null;
    } catch (e) {
      debugPrint('getRoom error: $e');
      return null;
    }
  }

  // التعديل الرئيسي: الغرفة تنزل معلقة is_approved = false
  Future<void> createRoom(RoomModel room, String userId) async {
    try {
      final data = room.toJson();
      data['created_by'] = userId;
      data['created_at'] = DateTime.now().toIso8601String();
      data['member_count'] = 1;
      data['online_count'] = 1;
      data['is_approved'] = false; // أهم سطر

      await _sb.from(SupabaseConfig.tRooms).insert(data);
      await joinRoom(room.id, userId);
    } catch (e) {
      debugPrint('createRoom error: $e');
      rethrow;
    }
  }

  Future<void> joinRoom(String roomId, String userId) async {
    try {
      await _sb.from(SupabaseConfig.tRoomMembers).upsert({
        'room_id': roomId,
        'user_id': userId,
        'joined_at': DateTime.now().toIso8601String()
      });
      await _sb.rpc('increment_room_member', params: {'room_id': roomId});
    } catch (e) {
      debugPrint('joinRoom error: $e');
    }
  }

  Future<bool> isMember(String roomId, String userId) async {
    try {
      final data = await _sb.from(SupabaseConfig.tRoomMembers)
        .select().eq('room_id', roomId).eq('user_id', userId).maybeSingle();
      return data!= null;
    } catch (e) {
      debugPrint('isMember error: $e');
      return false;
    }
  }

  Future<void> updateRoomImage(String roomId, String imageUrl) async {
    try {
      await _sb.from(SupabaseConfig.tRooms).update({'image_url': imageUrl}).eq('id', roomId);
    } catch (e) {
      debugPrint('updateRoomImage error: $e');
    }
  }

  // دالة جديدة: الآدمن يقدر يوافق على الغرفة
  Future<void> approveRoom(String roomId) async {
    try {
      await _sb.from(SupabaseConfig.tRooms)
        .update({'is_approved': true})
        .eq('id', roomId);
    } catch (e) {
      debugPrint('approveRoom error: $e');
      rethrow;
    }
  }

  // ======= دوال الرسائل المضافة =======

  Future<void> sendRoomMessage(String roomId, MessageModel message) async {
    await _sb.from('room_messages').insert(message.toJson());
  }

  Stream<List<MessageModel>> getRoomMessages(String roomId) {
    return _sb
      .from('room_messages')
      .stream(primaryKey: ['id'])
      .eq('chat_id', roomId)
      .order('created_at', ascending: false)
      .map((maps) => maps.map((map) => MessageModel.fromJson(map)).toList());
  }
}
