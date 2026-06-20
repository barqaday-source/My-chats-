import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as p;

class ChatService {
  final _supabase = Supabase.instance.client;
  static const String _bucket = 'chat_media';

  Box? get _outboxChat => Hive.isBoxOpen('outbox_chat') ? Hive.box('outbox_chat') : null;
  Box? get _outboxRoom => Hive.isBoxOpen('outbox_room') ? Hive.box('outbox_room') : null;

  ChatService() {
    Connectivity().onConnectivityChanged.listen((r) {
      if (r != ConnectivityResult.none) {
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

  // ===== الخاص =====
  Stream<List<Map<String, dynamic>>> getPrivateMessagesStream(String userId, String peerId) {
    final chatId = _getChatId(userId, peerId);
    return _supabase
        .from('private_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: true)
        .map((maps) => maps.where((m) => m['deleted_at'] == null).toList());
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
    if (conn.contains(ConnectivityResult.none)) {
      await _outboxChat?.add(payload);
      throw Exception('offline');
    }
    await _sendPrivateOnline(payload);
  }

  Future<void> _sendPrivateOnline(Map payload) async {
    String? imageUrl;
    String? audioUrl;
    if (payload['image_path'] != null) {
      imageUrl = await _upload(File(payload['image_path']));
    }
    if (payload['audio_path'] != null) {
      audioUrl = await _upload(File(payload['audio_path']));
    }

    await _supabase.from('private_messages').insert({
      'chat_id': payload['chat_id'],
      'sender_id': payload['sender_id'],
      'receiver_id': payload['receiver_id'],
      'content': payload['content'] ?? '',
      'media_url': imageUrl,
      'audio_url': audioUrl,
      'reply_to': payload['reply_to'],
    });
  }

  // ===== الغرف =====
  Stream<List<Map<String, dynamic>>> getRoomMessagesStream(String roomId) {
    return _supabase
        .from('room_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .map((maps) => maps.where((m) => m['deleted_at'] == null).toList());
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
    if (conn.contains(ConnectivityResult.none)) {
      await _outboxRoom?.add(payload);
      throw Exception('offline');
    }
    await _sendRoomOnline(payload);
  }

  Future<void> _sendRoomOnline(Map payload) async {
    String? imageUrl;
    String? audioUrl;
    if (payload['image_path'] != null) {
      imageUrl = await _upload(File(payload['image_path']));
    }
    if (payload['audio_path'] != null) {
      audioUrl = await _upload(File(payload['audio_path']));
    }
    await _supabase.from('room_messages').insert({
      'room_id': payload['room_id'],
      'sender_id': payload['sender_id'],
      'content': payload['content'] ?? '',
      'media_url': imageUrl,
      'audio_url': audioUrl,
      'reply_to': payload['reply_to'],
    });
  }

  // ===== مشترك =====
  Future<String> _upload(File file) async {
    final ext = p.extension(file.path);
    final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final path = '${_supabase.auth.currentUser!.id}/$name';
    await _supabase.storage.from(_bucket).upload(path, file,
        fileOptions: const FileOptions(upsert: false));
    return _supabase.storage.from(_bucket).getPublicUrl(path);
  }

  Future<void> deleteMessage(String messageId, {bool isRoom = false}) async {
    final table = isRoom ? 'room_messages' : 'private_messages';
    await _supabase.from(table)
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', messageId)
        .eq('sender_id', _supabase.auth.currentUser!.id);
  }

  Future<void> _flushOutbox(String kind) async {
    final box = kind == 'room' ? _outboxRoom : _outboxChat;
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
    await _supabase.from('room_members').upsert({
      'user_id': userId,
      'room_id': roomId,
      'is_online': true,
      'last_seen': DateTime.now().toIso8601String()
    }, onConflict: 'user_id,room_id');
  }

  Future<void> setUserOfflineInRoom(String userId, String roomId) async {
    await _supabase.from('room_members').update({
      'is_online': false,
      'last_seen': DateTime.now().toIso8601String()
    }).eq('user_id', userId).eq('room_id', roomId);
  }
}
