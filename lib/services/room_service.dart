import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/supabase_config.dart';
import '../models/room_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart'; // ✅ أضف هذا

class RoomService {
  final _sb = Supabase.instance.client;

  Future<List<RoomModel>> getRooms() async {
    try {
      final data = await _sb.from(SupabaseConfig.tRooms).select()
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

  Future<void> joinRoom(String roomId, String userId) async {
    try {
      await _sb.from(SupabaseConfig.tRoomMembers).upsert({
        'room_id': roomId,
        'user_id': userId,
        'joined_at': DateTime.now().toIso8601String()
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
  } // ✅ هذا القوس يقفل getRoomMessages هنا

  // ✅ الدالة بره - المكان الصحيح
  Stream<List<UserModel>> getRoomMembers(String roomId) {
    return _sb
       .from(SupabaseConfig.tRoomMembers)
       .stream(primaryKey: ['id'])
       .eq('room_id', roomId)
       .asyncMap((members) async {
          List<UserModel> users = [];
          for (var member in members) {
            final userData = await _sb.from(SupabaseConfig.tUsers).select().eq('id', member['user_id']).single();
            users.add(UserModel.fromJson(userData));
          }
          return users;
        });
  }
} // ✅ هذا قوس الكلاس
