import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import '../models/room_model.dart';

class ChatService {
  final _supabase = Supabase.instance.client;

  // ====== Private Chat ======

  String _getChatId(String id1, String id2) {
    final sorted = [id1, id2]..sort();
    return sorted.join('_');
  }

  Stream<List<Map<String, dynamic>>> getPrivateMessagesStream(String userId, String peerId) {
    final chatId = _getChatId(userId, peerId);
    return _supabase
       .from('private_messages')
       .stream(primaryKey: ['id'])
       .eq('chat_id', chatId)
       .order('created_at', ascending: false);
  }

  Future<void> sendPrivateMessage(String peerId, MessageModel message) async {
    await _supabase.from('private_messages').insert(message.toJson());
  }

  Future<void> markAsRead(String userId, String peerId) async {
    final chatId = _getChatId(userId, peerId);
    await _supabase
       .from('private_messages')
       .update({'is_read': true})
       .eq('chat_id', chatId)
       .eq('receiver_id', userId)
       .eq('is_read', false);
  }

  // ====== Room Chat ======

  Stream<List<Map<String, dynamic>>> getRoomMessagesStream(String roomId) {
    return _supabase
       .from('room_messages')
       .stream(primaryKey: ['id'])
       .eq('chat_id', roomId)
       .order('created_at', ascending: false);
  }

  Future<void> sendMessageToRoom(String roomId, MessageModel message) async {
    await _supabase.from('room_messages').insert(message.toJson());
  }

  Future<void> setUserOnlineInRoom(String userId, String roomId) async {
    await _supabase
       .from('room_members')
       .update({
          'is_online': true,
          'last_seen': DateTime.now().toIso8601String()
        })
       .eq('user_id', userId)
       .eq('room_id', roomId);
  }

  Future<void> setUserOfflineInRoom(String userId, String roomId) async {
    await _supabase
       .from('room_members')
       .update({
          'is_online': false,
          'last_seen': DateTime.now().toIso8601String()
        })
       .eq('user_id', userId)
       .eq('room_id', roomId);
  }

  // ====== حذف الرسائل ======

  Future<void> deleteMessage(String messageId, bool isRoom) async {
    final table = isRoom? 'room_messages' : 'private_messages';
    await _supabase.from(table).delete().eq('id', messageId);
  }

  // ====== جلب آخر رسالة ======

  Future<Map<String, dynamic>?> getLastPrivateMessage(String userId, String peerId) async {
    final chatId = _getChatId(userId, peerId);
    final res = await _supabase
       .from('private_messages')
       .select()
       .eq('chat_id', chatId)
       .order('created_at', ascending: false)
       .limit(1)
       .maybeSingle();
    return res;
  }

  Future<Map<String, dynamic>?> getLastRoomMessage(String roomId) async {
    final res = await _supabase
       .from('room_messages')
       .select()
       .eq('chat_id', roomId)
       .order('created_at', ascending: false)
       .limit(1)
       .maybeSingle();
    return res;
  }

  // ====== عدد غير المقروءة ======

  Future<int> getUnreadCount(String userId, String peerId) async {
    final chatId = _getChatId(userId, peerId);
    final res = await _supabase
       .from('private_messages')
       .select('id')
       .eq('chat_id', chatId)
       .eq('receiver_id', userId)
       .eq('is_read', false);
    return res.length;
  }

  // ====== قائمة الشاتات ======

  Future<List<Map<String, dynamic>>> getUserChats(String userId) async {
    final response = await _supabase
       .from('private_messages')
       .select('chat_id, sender_id, receiver_id, content, created_at, is_read')
       .or('sender_id.eq.$userId,receiver_id.eq.$userId')
       .order('created_at', ascending: false);

    final Map<String, Map<String, dynamic>> chats = {};
    for (var msg in response) {
      final chatId = msg['chat_id'];
      if (!chats.containsKey(chatId)) {
        final peerId = msg['sender_id'] == userId? msg['receiver_id'] : msg['sender_id'];
        final peerData = await _supabase.from('profiles').select().eq('id', peerId).single();
        chats[chatId] = {
          'id': chatId,
          'peer': peerData,
          'last_message': msg['content'],
          'last_message_time': msg['created_at'],
          'unread_count': await getUnreadCount(userId, peerId),
        };
      }
    }
    return chats.values.toList();
  }
}
