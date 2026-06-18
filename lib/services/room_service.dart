import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/supabase_config.dart';
import '../models/room_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class RoomService {
  final _sb = Supabase.instance.client;

  Future<List<RoomModel>> getRooms() async {
    try {
      final data = await _sb.from(SupabaseConfig.tRooms).select()
   .eq('is_approved', true)
   .order('is_official', ascending: false)
   .order('online_count', ascending: false)
   .order('member_count', ascending: false);
      return (data as List).map((e) => RoomModel.fromJson(e as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - getRooms
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
      return [];
    } catch (e, s) {
      debugPrint('❌ Unknown Error - getRooms: $e\n$s');
      return [];
    }
  }

  Future<RoomModel?> getRoom(String id) async {
    try {
      final data = await _sb.from(SupabaseConfig.tRooms).select().eq('id', id).maybeSingle();
      return data!= null? RoomModel.fromJson(data) : null;
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - getRoom
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
      return null;
    }
  }

  Future<RoomModel> createRoom(RoomModel room, String userId) async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    if (user.id!= userId) throw Exception('userId mismatch with auth.uid()');

    try {
      final data = room.toJson();
      data['owner_id'] = userId;
      data['created_by'] = userId;
      data['members'] = [userId];

      final response = await _sb.from(SupabaseConfig.tRooms).insert(data).select().single();
      final newRoom = RoomModel.fromJson(response);

      await joinRoom(newRoom.id, userId);
      return newRoom;
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - createRoom
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
      rethrow;
    } catch (e, s) {
      debugPrint('❌ Unknown Error - createRoom: $e\n$s');
      rethrow;
    }
  }

  Future<void> updateRoom(RoomModel room) async {
    try {
      await _sb
         .from(SupabaseConfig.tRooms)
         .update(room.toJson())
         .eq('id', room.id);
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - updateRoom
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
      rethrow;
    }
  }

  Future<void> deleteRoom(String roomId) async {
    try {
      await _sb.from(SupabaseConfig.tRooms).delete().eq('id', roomId);
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - deleteRoom
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
      rethrow;
    }
  }

  Future<void> joinRoom(String roomId, String userId) async {
    try {
      await _sb.from(SupabaseConfig.tRoomMembers).upsert({
        'room_id': roomId,
        'user_id': userId,
        'joined_at': DateTime.now().toIso8601String(),
        'is_online': true,
      });
      await _sb.rpc('increment_room_member', params: {'room_id': roomId});
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - joinRoom
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
    }
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    try {
      await _sb
         .from(SupabaseConfig.tRoomMembers)
         .delete()
         .eq('room_id', roomId)
         .eq('user_id', userId);
      await _sb.rpc('decrement_room_member', params: {'room_id': roomId});
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - leaveRoom
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
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

  Future<List<Map<String, dynamic>>> getRoomMembers(String roomId) async {
    try {
      final res = await _sb
         .from(SupabaseConfig.tRoomMembers)
         .select('*, users(*)')
         .eq('room_id', roomId)
         .order('is_online', ascending: false);

      return res.map((m) => {
       ...m['users'] as Map<String, dynamic>,
        'is_online': m['is_online']?? false,
        'last_seen': m['last_seen'],
      }).toList();
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - getRoomMembers
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
      return [];
    }
  }

  Future<void> removeRoomMember(String roomId, String userId) async {
    try {
      await _sb
         .from(SupabaseConfig.tRoomMembers)
         .delete()
         .eq('room_id', roomId)
         .eq('user_id', userId);
      await _sb.rpc('decrement_room_member', params: {'room_id': roomId});
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - removeRoomMember
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
      rethrow;
    }
  }

  Future<void> updateRoomImage(String roomId, String imageUrl) async {
    try {
      await _sb.from(SupabaseConfig.tRooms).update({'image_url': imageUrl}).eq('id', roomId);
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - updateRoomImage
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
      rethrow;
    }
  }

  Future<void> approveRoom(String roomId) async {
    try {
      await _sb.from(SupabaseConfig.tRooms)
   .update({'is_approved': true})
   .eq('id', roomId);
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - approveRoom
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
      rethrow;
    }
  }

  Future<void> sendRoomMessage(String roomId, MessageModel message) async {
    try {
      await _sb.from(SupabaseConfig.tRoomMessages).insert(message.toJson());
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - sendRoomMessage
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
      rethrow;
    }
  }

  Stream<List<MessageModel>> getRoomMessages(String roomId) {
    return _sb
 .from(SupabaseConfig.tRoomMessages)
 .stream(primaryKey: ['id'])
 .eq('chat_id', roomId)
 .order('created_at', ascending: false)
 .map((maps) => maps.map((map) => MessageModel.fromJson(map)).toList());
  }

  // دوال الأونلاين
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
