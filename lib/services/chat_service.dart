import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ======= Private Chats =======

  Stream<List<MessageModel>> getPrivateMessages(String chatId) {
    return _supabase
     .from('messages')
     .stream(primaryKey: ['id'])
     .eq('chat_id', chatId)
     .order('created_at', ascending: true)
     .map((data) => data.map((json) => MessageModel.fromJson(json)).toList());
  }

  Future<void> sendPrivateMessage(String peerId, MessageModel msg) async {
    await _supabase.from('messages').insert(msg.toJson());

    await _supabase.from('chats').upsert({
      'id': msg.chatId,
      'last_message': msg.content,
      'last_message_time': msg.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _supabase.from('messages').delete().eq('id', messageId).eq('chat_id', chatId);
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

  // ======= Rooms =======

  Stream<List<RoomModel>> getRooms() {
    return _supabase
     .from('rooms')
     .stream(primaryKey: ['id'])
     .order('updated_at', ascending: false)
     .map((data) => data.map((json) => RoomModel.fromJson(json)).toList());
  }

  Stream<List<MessageModel>> roomMessages(String roomId) {
    return _supabase
     .from('messages')
     .stream(primaryKey: ['id'])
     .eq('chat_id', roomId)
     .order('created_at', ascending: true)
     .map((data) => data.map((json) => MessageModel.fromJson(json)).toList());
  }

  Future<void> sendRoomMessage(MessageModel msg) async {
    await _supabase.from('messages').insert(msg.toJson());

    await _supabase.from('rooms').update({
      'last_message': msg.content,
      'last_message_time': msg.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', msg.chatId);
  }

  Future<void> joinRoom(String roomId, String userId) async {
    await _supabase.from('room_members').upsert({
      'room_id': roomId,
      'user_id': userId,
      'joined_at': DateTime.now().toIso8601String(),
      'is_online': true,
    });

    await _supabase.rpc('increment_member_count', params: {'room_id': roomId});
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    await _supabase.from('room_members').update({
      'is_online': false,
      'last_seen': DateTime.now().toIso8601String(),
    }).eq('room_id', roomId).eq('user_id', userId);
  }

  Stream<List<UserModel>> getRoomMembers(String roomId) {
    return _supabase
     .from('room_members')
     .stream(primaryKey: ['id'])
     .eq('room_id', roomId)
     .asyncMap((members) async {
        List<UserModel> users = [];
        for (var member in members) {
          final userData = await _supabase.from('users').select().eq('id', member['user_id']).single();
          userData['is_online'] = member['is_online']?? false;
          users.add(UserModel.fromJson(userData));
        }
        return users;
      });
  }

  Stream<int> roomOnlineCount(String roomId) {
    return _supabase
      .from('room_members')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .map((data) => data.where((m) => m['is_online'] == true).length);
  }

  Future<void> updateRoom(RoomModel room) async {
    try {
      await _supabase.from('rooms').update(room.toJson()).eq('id', room.id);
    } catch (e) {
      debugPrint('Update room error: $e');
      rethrow;
    }
  }

  Future<void> removeRoomMember(String roomId, String userId) async {
    try {
      await _supabase.from('room_members').delete().eq('room_id', roomId).eq('user_id', userId);
      await _supabase.rpc('decrement_member_count', params: {'room_id': roomId});
    } catch (e) {
      debugPrint('Remove member error: $e');
      rethrow;
    }
  }

  Future<void> deleteRoom(String roomId) async {
    try {
      await _supabase.from('messages').delete().eq('chat_id', roomId);
      await _supabase.from('room_members').delete().eq('room_id', roomId);
      await _supabase.from('rooms').delete().eq('id', roomId);
    } catch (e) {
      debugPrint('Delete room error: $e');
      rethrow;
    }
  }
}
