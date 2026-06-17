import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import '../core/constants/supabase_config.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ======= Private Chats =======
  Stream<List<MessageModel>> getPrivateMessages(String chatId) {
    return _supabase
   .from(SupabaseConfig.tMessages)
   .stream(primaryKey: ['id'])
   .eq('chat_id', chatId)
   .order('created_at', ascending: true)
   .map((data) => data.map((json) => MessageModel.fromJson(json)).toList());
  }

  Future<void> sendPrivateMessage(String peerId, MessageModel msg) async {
    try {
      await _supabase.from(SupabaseConfig.tMessages).insert(msg.toJson());
      await _supabase.from(SupabaseConfig.tPrivateChats).upsert({
        'id': msg.chatId,
        'last_message': msg.content,
        'last_message_time': msg.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e, s) {
      debugPrint('''
      ❌ Supabase Error - sendPrivateMessage
      Code: ${e.code}
      Message: ${e.message}
      Details: ${e.details}
      Hint: ${e.hint}
      $s
      ''');
      rethrow;
    }
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _supabase.from(SupabaseConfig.tMessages).delete().eq('id', messageId).eq('chat_id', chatId);
  }

  String getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  Future<void> sendMessage(MessageModel message) async {
    await sendPrivateMessage('', message);
  }

  Stream<List<MessageModel>> privateMessages(String chatId) {
    return getPrivateMessages(chatId);
  }

  // ======= Rooms - التعديل: توحيد على room_messages =======
  Stream<List<RoomModel>> getRooms() {
    return _supabase
   .from(SupabaseConfig.tRooms)
   .stream(primaryKey: ['id'])
   .order('updated_at', ascending: false)
   .map((data) => data.map((json) => RoomModel.fromJson(json)).toList());
  }

  Stream<List<MessageModel>> roomMessages(String roomId) {
    return _supabase
   .from(SupabaseConfig.tRoomMessages) // مو messages
   .stream(primaryKey: ['id'])
   .eq('chat_id', roomId)
   .order('created_at', ascending: true)
   .map((data) => data.map((json) => MessageModel.fromJson(json)).toList());
  }

  Future<void> sendRoomMessage(MessageModel msg) async {
    try {
      await _supabase.from(SupabaseConfig.tRoomMessages).insert(msg.toJson());
      await _supabase.from(SupabaseConfig.tRooms).update({
        'last_message': msg.content,
        'last_message_time': msg.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', msg.chatId);
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

  Future<void> joinRoom(String roomId, String userId) async {
    try {
      await _supabase.from(SupabaseConfig.tRoomMembers).upsert({
        'room_id': roomId,
        'user_id': userId,
        'joined_at': DateTime.now().toIso8601String(),
        'is_online': true,
      });
      await _supabase.rpc('increment_member_count', params: {'room_id': roomId});
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
    await _supabase.from(SupabaseConfig.tRoomMembers).update({
      'is_online': false,
      'last_seen': DateTime.now().toIso8601String(),
    }).eq('room_id', roomId).eq('user_id', userId);
  }

  Stream<List<UserModel>> getRoomMembers(String roomId) {
    return _supabase
   .from(SupabaseConfig.tRoomMembers)
   .stream(primaryKey: ['id'])
   .eq('room_id', roomId)
   .asyncMap((members) async {
        List<UserModel> users = [];
        for (var member in members) {
          final userData = await _supabase.from(SupabaseConfig.tUsers).select().eq('id', member['user_id']).single();
          userData['is_online'] = member['is_online']?? false;
          users.add(UserModel.fromJson(userData));
        }
        return users;
      });
  }

  Stream<int> roomOnlineCount(String roomId) {
    return _supabase
    .from(SupabaseConfig.tRoomMembers)
    .stream(primaryKey: ['id'])
    .eq('room_id', roomId)
    .map((data) => data.where((m) => m['is_online'] == true).length);
  }

  Future<void> updateRoom(RoomModel room) async {
    try {
      await _supabase.from(SupabaseConfig.tRooms).update(room.toJson()).eq('id', room.id);
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

  Future<void> removeRoomMember(String roomId, String userId) async {
    try {
      await _supabase.from(SupabaseConfig.tRoomMembers).delete().eq('room_id', roomId).eq('user_id', userId);
      await _supabase.rpc('decrement_member_count', params: {'room_id': roomId});
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

  Future<void> deleteRoom(String roomId) async {
    try {
      await _supabase.from(SupabaseConfig.tRoomMessages).delete().eq('chat_id', roomId);
      await _supabase.from(SupabaseConfig.tRoomMembers).delete().eq('room_id', roomId);
      await _supabase.from(SupabaseConfig.tRooms).delete().eq('id', roomId);
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
}
