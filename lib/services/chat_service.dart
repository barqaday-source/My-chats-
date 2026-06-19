import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as p;
import '../models/message_model.dart';

class ChatService {
  final _supabase = Supabase.instance.client;
  Box? get _outboxChat => Hive.isBoxOpen('outbox_chat')? Hive.box('outbox_chat') : null;
  Box? get _outboxRoom => Hive.isBoxOpen('outbox_room')? Hive.box('outbox_room') : null;

  static const String _bucket = 'chat_media';

  ChatService() {
    Connectivity().onConnectivityChanged.listen((r) {
      if (r!= ConnectivityResult.none) {
        _flushOutbox('private');
        _flushOutbox('room');
      }
    });
    _flushOutbox('private');
    _flushOutbox('room');
  }

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
    .order('created_at', ascending: true)
    .map((maps) => maps.where((m) => m['deleted_at'] == null).toList());
  }

  Future<void> sendPrivateMessage(String peerId, MessageModel message) async {
    await _supabase.from('private_messages').insert(message.toJson());
  }

  Future<void> sendPrivateMessageEx({
    required String peerId,
    required String text,
    File? imageFile,
    File? audioFile,
    String? replyTo,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final chatId = _getChatId(userId, peerId);

    final payload = {
      'chat_id': chatId,
      'sender_id': userId,
      'receiver_id': peerId,
      'content': text,
      'image_path': imageFile?.path,
      'audio_path': audioFile?.path,
      'reply_to': replyTo,
    };

    final conn = await Connectivity().checkConnectivity();
    final offline = conn.contains(ConnectivityResult.none);
    if (offline) {
      await _outboxChat?.add(payload);
      throw Exception('offline');
    }
    await _sendPrivateOnline(payload);
  }

  Future<String> _upload(File file) async {
    final ext = p.extension(file.path);
    final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final path = '${_supabase.auth.currentUser!.id}/$name';
    await _supabase.storage.from(_bucket).upload(path, file,
        fileOptions: const FileOptions(upsert: false));
    return _supabase.storage.from(_bucket).getPublicUrl(path);
  }

  Future<void> _sendPrivateOnline(Map payload) async {
    String? imageUrl;
    String? audioUrl;
    if (payload['image_path']!= null) {
      imageUrl = await _upload(File(payload['image_path']));
    }
    if (payload['audio_path']!= null) {
      audioUrl = await _upload(File(payload['audio_path']));
    }

    final me = await _supabase.from('profiles')
      .select('username, avatar_url')
      .eq('id', payload['sender_id'])
      .maybeSingle();

    await _supabase.from('private_messages').insert({
      'chat_id': payload['chat_id'],
      'sender_id': payload['sender_id'],
      'receiver_id': payload['receiver_id'],
      'sender_name': me?['username']?? '',
      'sender_avatar': me?['avatar_url'],
      'content': payload['content']?? '',
      'media_url': imageUrl,
      'audio_url': audioUrl,
      'type': audioUrl!= null? 'audio' : imageUrl!= null? 'image' : 'text',
      'reply_to': payload['reply_to'],
    });
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

  Stream<List<Map<String, dynamic>>> getRoomMessagesStream(String roomId) {
    return _supabase
    .from('room_messages')
    .stream(primaryKey: ['id'])
    .eq('room_id', roomId)
    .order('created_at', ascending: true)
    .map((maps) => maps.where((m) => m['deleted_at'] == null).toList());
  }

  Future<void> sendMessageToRoom(String roomId, MessageModel message) async {
    await _supabase.from('room_messages').insert(message.toJson());
  }

  Future<void> sendMessageToRoomEx({
    required String roomId,
    String text = '',
    File? imageFile,
    File? audioFile,
    String? replyTo,
  }) async {
    final senderId = _supabase.auth.currentUser!.id;
    final payload = {
      'room_id': roomId,
      'sender_id': senderId,
      'content': text,
      'image_path': imageFile?.path,
      'audio_path': audioFile?.path,
      'reply_to': replyTo,
    };

    final conn = await Connectivity().checkConnectivity();
    final offline = conn.contains(ConnectivityResult.none);
    if (offline) {
      await _outboxRoom?.add(payload);
      throw Exception('offline');
    }
    await _sendRoomOnline(payload);
  }

  Future<void> _sendRoomOnline(Map payload) async {
    String? imageUrl;
    String? audioUrl;
    if (payload['image_path']!= null) {
      imageUrl = await _upload(File(payload['image_path']));
    }
    if (payload['audio_path']!= null) {
      audioUrl = await _upload(File(payload['audio_path']));
    }
    await _supabase.from('room_messages').insert({
      'room_id': payload['room_id'],
      'sender_id': payload['sender_id'],
      'content': payload['content']?? '',
      'media_url': imageUrl,
      'audio_url': audioUrl,
      'reply_to': payload['reply_to'],
    });
  }

  Future<void> _flushOutbox(String kind) async {
    final box = kind == 'room'? _outboxRoom : _outboxChat;
    if (box == null || box.isEmpty) return;
    final keys = box.keys.toList();
    for (final k in keys) {
      try {
        final data = Map<String, dynamic>.from(box.get(k));
        if (kind == 'room') {
          await _sendRoomOnline(data);
        } else {
          await _sendPrivateOnline(data);
        }
        await box.delete(k);
      } catch (_) {
        break;
      }
    }
  }

  Future<void> setUserOnlineInRoom(String userId, String roomId) async {
    await _supabase.from('room_members').update({
      'is_online': true, 'last_seen': DateTime.now().toIso8601String()
    }).eq('user_id', userId).eq('room_id', roomId);
  }

  Future<void> setUserOfflineInRoom(String userId, String roomId) async {
    await _supabase.from('room_members').update({
      'is_online': false, 'last_seen': DateTime.now().toIso8601String()
    }).eq('user_id', userId).eq('room_id', roomId);
  }

  Future<void> deleteMessage(String messageId, {bool isRoom = false}) async {
    final table = isRoom? 'room_messages' : 'private_messages';
    await _supabase.from(table)
   .update({'deleted_at': DateTime.now().toIso8601String()})
   .eq('id', messageId)
   .eq('sender_id', _supabase.auth.currentUser!.id);
  }

  Future<void> reportUser(String reportedId, String reason) async {
    await _supabase.from('reports').insert({
      'reporter_id': _supabase.auth.currentUser!.id,
      'reported_id': reportedId,
      'reason': reason,
    });
  }

  Future<Map<String, dynamic>?> getLastPrivateMessage(String userId, String peerId) async {
    final chatId = _getChatId(userId, peerId);
    final res = await _supabase.from('private_messages').select()
   .eq('chat_id', chatId).order('created_at', ascending: false).limit(1).maybeSingle();
    return res;
  }

  Future<Map<String, dynamic>?> getLastRoomMessage(String roomId) async {
    final res = await _supabase.from('room_messages').select()
   .eq('room_id', roomId).order('created_at', ascending: false).limit(1).maybeSingle();
    return res;
  }

  Future<int> getUnreadCount(String userId, String peerId) async {
    final chatId = _getChatId(userId, peerId);
    final res = await _supabase.from('private_messages').select('id')
   .eq('chat_id', chatId).eq('receiver_id', userId).eq('is_read', false);
    return res.length;
  }

  Future<List<Map<String, dynamic>>> getUserChats(String userId) async {
    final response = await _supabase.from('private_messages')
   .select('chat_id, sender_id, receiver_id, content, created_at, is_read')
   .or('sender_id.eq.$userId,receiver_id.eq.$userId')
   .order('created_at', ascending: false);

    final Map<String, Map<String, dynamic>> chats = {};
    for (var msg in response) {
      final chatId = msg['chat_id'];
      if (!chats.containsKey(chatId)) {
        final peerId = msg['sender_id'] == userId? msg['receiver_id'] : msg['sender_id'];
        final peerData = await _supabase.from('profiles').select().eq('id', peerId).maybeSingle();
        if (peerData!= null) {
          chats[chatId] = {
            'id': chatId,
            'peer': peerData,
            'last_message': msg['content'],
            'last_message_time': msg['created_at'],
            'unread_count': await getUnreadCount(userId, peerId),
          };
        }
      }
    }
    return chats.values.toList();
  }
}
