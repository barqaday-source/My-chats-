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
    try {
      await _supabase.from('messages').insert(msg.toJson());
      await _supabase.from('chats').upsert({
        'id': msg.chatId,
        'last_message': msg.content,
        'last_message_time': msg.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e, s) {
      debugPrint('❌ Supabase Error - sendPrivateMessage\nCode: ${e.code}\nMessage: ${e.message}\nDetails: ${e.details}\nHint: ${e.hint}\n$s');
      rethrow;
    }
  }

  // ======= Rooms - التعديل 9: توحيد على room_messages =======
  Stream<List<RoomModel>> getRooms() {
    return _supabase
    .from('rooms')
    .stream(primaryKey: ['id'])
    .order('updated_at', ascending: false)
    .map((data) => data.map((json) => RoomModel.fromJson(json)).toList());
  }

  Stream<List<MessageModel>> roomMessages(String roomId) {
    return _supabase
    .from('room_messages') // مو messages
    .stream(primaryKey: ['id'])
    .eq('chat_id', roomId)
    .order('created_at', ascending: true)
    .map((data) => data.map((json) => MessageModel.fromJson(json)).toList());
  }

  Future<void> sendRoomMessage(MessageModel msg) async {
    try {
      await _supabase.from('room_messages').insert(msg.toJson());
      await _supabase.from('rooms').update({
        'last_message': msg.content,
        'last_message_time': msg.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', msg.chatId);
    } on PostgrestException catch (e, s) {
      debugPrint('❌ Supabase Error - sendRoomMessage\nCode: ${e.code}\nMessage: ${e.message}\nDetails: ${e.details}\nHint: ${e.hint}\n$s');
      rethrow;
    }
  }

  Future<void> joinRoom(String roomId, String userId) async {
    try {
      await _supabase.from('room_members').upsert({
        'room_id': roomId,
        'user_id': userId,
        'joined_at': DateTime.now().toIso8601String(),
        'is_online': true,
      });
      await _supabase.rpc('increment_room_member', params: {'room_id': roomId});
    } on PostgrestException catch (e, s) {
      debugPrint('❌ Supabase Error - joinRoom\nCode: ${e.code}\nMessage: ${e.message}\nDetails: ${e.details}\nHint: ${e.hint}\n$s');
    }
  }

  // باقي الدوال نفسها بس ضيفلها try-catch Logging اذا تحب
}
