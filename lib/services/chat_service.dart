import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as p;
import '../core/constants/supabase_config.dart';

class ChatService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  static const String _bucket = 'chat_media';

  Box? get _outboxChat => Hive.isBoxOpen('outbox_chat')? Hive.box('outbox_chat') : null;
  Box? get _outboxRoom => Hive.isBoxOpen('outbox_room')? Hive.box('outbox_room') : null;

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

  String? get _uid => _supabase.auth.currentUser?.id;

  bool _isDeletedForMe(Map<String, dynamic> m) {
    final uid = _uid;
    if (uid == null) return false;
    final deletedFor = (m['deleted_for'] as List?)?.cast<String>()?? const [];
    return deletedFor.contains(uid);
  }

  // ====== Block system ======
  Future<bool> isBlocked(String userId, String peerId) async {
    try {
      final res = await _supabase
        .from('blocked_users')
        .select('blocker_id')
        .or('and(blocker_id.eq.$userId,blocked_id.eq.$peerId),and(blocker_id.eq.$peerId,blocked_id.eq.$userId)')
        .limit(1)
        .maybeSingle();
      return res!= null;
    } catch (_) {
      return false;
    }
  }

  Future<Set<String>> _getBlockedIds(String uid) async {
    try {
      final blocked = await _supabase
        .from('blocked_users')
        .select('blocker_id, blocked_id')
        .or('blocker_id.eq.$uid,blocked_id.eq.$uid');
      return blocked.map<String>((b) =>
          b['blocker_id'] == uid? b['blocked_id'] as String : b['blocker_id'] as String
      ).toSet();
    } catch (_) {
      return {};
    }
  }

  // يرجع 'blocked' أو 'already_blocked'
  Future<String> blockUser(String peerId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('not_authenticated');

    // إذا محظور أصلا
    if (await isBlocked(user.id, peerId)) {
      return 'already_blocked';
    }

    try {
      await _supabase.from('blocked_users').insert({
        'blocker_id': user.id,
        'blocked_id': peerId,
      });
      return 'blocked';
    } on PostgrestException catch (e) {
      // 23505 = unique violation
      if (e.code == '23505') return 'already_blocked';
      rethrow;
    }
  }

  Future<void> unblockUser(String peerId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('not_authenticated');
    await _supabase.from('blocked_users')
      .delete()
      .eq('blocker_id', user.id)
      .eq('blocked_id', peerId);
  }

  Future<void> reportUser(String peerId, String reason) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('not_authenticated');
    await _supabase.from('reports').insert({
      'reporter_id': user.id,
      'reported_id': peerId,
      'reason': reason,
    });
  }

  // ====== Read receipts ======
  Future<void> markPrivateMessagesRead(String chatId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _supabase.from('private_messages')
        .update({
            'is_read': true,
            'is_delivered': true,
            'read_at': DateTime.now().toIso8601String(),
          })
        .eq('chat_id', chatId)
        .neq('sender_id', uid);
    } catch (_) {}
  }

  Future<void> markRoomMessagesRead(String roomId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _supabase.from('room_messages')
        .update({'is_read': true, 'is_delivered': true})
        .eq('room_id', roomId)
        .neq('sender_id', uid);
    } catch (_) {}
  }

  // ====== Private messages ======
  Stream<List<Map<String, dynamic>>> getPrivateMessagesStream(String chatId) async* {
    final uid = _uid;
    final blockedIds = uid!= null? await _getBlockedIds(uid) : <String>{};

    yield* _supabase
      .from('private_messages')
      .stream(primaryKey: ['id'])
      .eq('chat_id', chatId)
      .order('created_at', ascending: true)
      .map((maps) {
      final seen = <String>{};
      return maps.where((m) =>
          m['deleted_at'] == null &&
        !_isDeletedForMe(m) &&
        !blockedIds.contains(m['sender_id']) &&
          seen.add(m['id'].toString())
      ).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getPrivateMessagesStreamByUsers(String userId, String peerId) {
    final chatId = _getChatId(userId, peerId);
    return getPrivateMessagesStream(chatId);
  }

  Future<void> sendPrivateMessageEx({
    required String chatId,
    required String peerId,
    String content = '',
    String? mediaUrl,
    String? audioUrl,
    File? imageFile,
    File? audioFile,
    int audioDuration = 0,
    Map<String, dynamic>? replyMessage,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('not_authenticated');
    final userId = user.id;

    if (await isBlocked(userId, peerId)) {
      throw Exception('blocked');
    }

    final payload = {
      'chat_id': chatId,
      'sender_id': userId,
      'receiver_id': peerId,
      'content': content,
      'media_url': mediaUrl,
      'audio_url': audioUrl,
      'audio_duration': audioDuration,
      'image_path': imageFile?.path,
      'audio_path': audioFile?.path,
      'reply_message': replyMessage,
    };

    final conn = await Connectivity().checkConnectivity();
    if (conn.contains(ConnectivityResult.none)) {
      await _outboxChat?.add(payload);
      throw Exception('offline');
    }
    await _sendPrivateOnline(payload);
  }

  Future<void> _sendPrivateOnline(Map payload) async {
    final sender = payload['sender_id'] as String;
    final receiver = payload['receiver_id'] as String;

    if (await isBlocked(sender, receiver)) {
      throw Exception('blocked');
    }

    String? imageUrl = payload['media_url'];
    String? audioUrl = payload['audio_url'];

    if (imageUrl == null && payload['image_path']!= null) {
      imageUrl = await _upload(File(payload['image_path']));
    }
    if (audioUrl == null && payload['audio_path']!= null) {
      audioUrl = await _upload(File(payload['audio_path']));
    }

    final Map<String, dynamic>? reply = payload['reply_message'] as Map<String, dynamic>?;
    final replyId = reply?['id'];
    String? replyContent = reply?['content'] as String?;
    String replyType = reply?['type']?? (reply?['audio_url']!= null? 'audio' : reply?['image_url']!= null || reply?['media_url']!= null? 'image' : 'text');
    if (replyType == 'image' && (replyContent == null || replyContent.isEmpty)) replyContent = '📷 صورة';
    if ((replyType == 'audio' || replyType == 'voice') && (replyContent == null || replyContent.isEmpty)) replyContent = '🎤 رسالة صوتية';
    final replySenderName = reply?['sender_name']?? reply?['senderName'];

    final insertData = {
      'chat_id': payload['chat_id'],
      'sender_id': sender,
      'receiver_id': receiver,
      'content': payload['content']?? '',
      'type': audioUrl!= null? 'voice' : imageUrl!= null? 'image' : 'text',
      'image_url': imageUrl,
      'media_url': imageUrl,
      'audio_url': audioUrl,
      'audio_duration': payload['audio_duration']?? 0,
      'duration': payload['audio_duration']?? 0,
      'reply_to': replyId,
      'reply_sender_name': replySenderName,
      'reply_content': replyContent,
      'reply_type': replyType,
      'delivered_at': DateTime.now().toIso8601String(),
      'is_delivered': false,
      'is_read': false,
    }..removeWhere((k, v) => v == null);

    await _supabase.from('private_messages').insert(insertData);
  }

  // ====== Room messages ======
  Stream<List<Map<String, dynamic>>> getRoomMessagesStream(String roomId) {
    return _supabase
      .from('room_messages')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at', ascending: true)
      .map((maps) {
      final seen = <String>{};
      return maps.where((m) =>
          m['deleted_at'] == null &&
        !_isDeletedForMe(m) &&
          seen.add(m['id'].toString())
      ).toList();
    });
  }

  Future<void> sendMessageToRoomEx({
    required String roomId,
    String content = '',
    String? mediaUrl,
    String? audioUrl,
    File? imageFile,
    File? audioFile,
    int audioDuration = 0,
    Map<String, dynamic>? replyMessage,
  }) async {
    final senderId = _supabase.auth.currentUser?.id;
    if (senderId == null) throw Exception('not_authenticated');

    final payload = {
      'room_id': roomId,
      'sender_id': senderId,
      'content': content,
      'media_url': mediaUrl,
      'audio_url': audioUrl,
      'audio_duration': audioDuration,
      'image_path': imageFile?.path,
      'audio_path': audioFile?.path,
      'reply_message': replyMessage,
    };

    final conn = await Connectivity().checkConnectivity();
    if (conn.contains(ConnectivityResult.none)) {
      await _outboxRoom?.add(payload);
      throw Exception('offline');
    }
    await _sendRoomOnline(payload);
  }

  Future<void> _sendRoomOnline(Map payload) async {
    String? imageUrl = payload['media_url'];
    String? audioUrl = payload['audio_url'];

    if (imageUrl == null && payload['image_path']!= null) {
      imageUrl = await _upload(File(payload['image_path']));
    }
    if (audioUrl == null && payload['audio_path']!= null) {
      audioUrl = await _upload(File(payload['audio_path']));
    }

    final Map<String, dynamic>? reply = payload['reply_message'] as Map<String, dynamic>?;
    final replyId = reply?['id'];
    String? replyContent = reply?['content'] as String?;
    String replyType = reply?['type']?? (reply?['audio_url']!= null? 'audio' : reply?['image_url']!= null || reply?['media_url']!= null? 'image' : 'text');
    if (replyType == 'image' && (replyContent == null || replyContent.isEmpty)) replyContent = '📷 صورة';
    if ((replyType == 'audio' || replyType == 'voice') && (replyContent == null || replyContent.isEmpty)) replyContent = '🎤 رسالة صوتية';
    final replySenderName = reply?['sender_name']?? reply?['senderName'];

    final insertData = {
      'room_id': payload['room_id'],
      'sender_id': payload['sender_id'],
      'content': payload['content']?? '',
      'type': audioUrl!= null? 'voice' : imageUrl!= null? 'image' : 'text',
      'image_url': imageUrl,
      'media_url': imageUrl,
      'audio_url': audioUrl,
      'audio_duration': payload['audio_duration']?? 0,
      'duration': payload['audio_duration']?? 0,
      'reply_to_id': replyId,
      'reply_sender_name': replySenderName,
      'reply_content': replyContent,
      'reply_type': replyType,
      'is_delivered': false,
      'is_read': false,
    }..removeWhere((k, v) => v == null);

    await _supabase.from('room_messages').insert(insertData);
  }

  // ====== Upload ======
  Future<String> _upload(File file) async {
    final ext = p.extension(file.path);
    final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final path = '${_supabase.auth.currentUser!.id}/$name';
    await _supabase.storage.from(_bucket).upload(path, file,
        fileOptions: const FileOptions(upsert: false));
    return _supabase.storage.from(_bucket).getPublicUrl(path);
  }

  Future<String> uploadChatMedia(File file, String folder) async {
    return _upload(file);
  }

  // ====== Delete message ======
  Future<bool> deleteMessage(String messageId, {
    bool isRoom = false,
    String? imageUrl,
    String? audioUrl,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final urls = [imageUrl, audioUrl].where((u) => u!= null && u!.isNotEmpty);
    for (final url in urls) {
      try {
        final uri = Uri.parse(url!);
        final idx = uri.pathSegments.indexOf(_bucket);
        if (idx!= -1 && idx + 1 < uri.pathSegments.length) {
          final filePath = uri.pathSegments.sublist(idx + 1).join('/');
          await _supabase.storage.from(_bucket).remove([filePath]);
        }
      } catch (e) {
        debugPrint('storage delete skip: $e');
      }
    }

    final table = isRoom? 'room_messages' : 'private_messages';
    final res = await _supabase.from(table)
      .update({'deleted_at': DateTime.now().toIso8601String()})
      .eq('id', messageId)
      .eq('sender_id', user.id)
      .select();

    return res.isNotEmpty;
  }

  // ====== Clear chat / Delete chat ======
  Future<void> clearChat(String chatId, {bool isRoom = false}) async {
    final userId = _uid;
    if (userId == null) throw Exception('not_authenticated');

    final table = isRoom? 'room_messages' : 'private_messages';
    final col = isRoom? 'room_id' : 'chat_id';

    final msgs = await _supabase
      .from(table)
      .select('id, deleted_for')
      .eq(col, chatId)
      .isFilter('deleted_at', null);

    for (final m in msgs as List) {
      final id = m['id'];
      final deletedFor = (m['deleted_for'] as List?)?.cast<String>()?? [];
      if (deletedFor.contains(userId)) continue;

      final newDeletedFor = [...deletedFor, userId];
      await _supabase
        .from(table)
        .update({'deleted_for': newDeletedFor})
        .eq('id', id);
    }
  }

  Future<bool> deletePrivateChat(String chatId) async {
    final uid = _uid;
    if (uid == null) return false;
    await clearChat(chatId, isRoom: false);
    try {
      await _supabase.from('private_chats').delete().eq('id', chatId);
    } catch (_) {}
    return true;
  }

  // ====== Outbox flush ======
  Future<void> _flushOutbox(String kind) async {
    final box = kind == 'room'? _outboxRoom : _outboxChat;
    if (box == null || box.isEmpty) return;
    final keys = box.keys.toList();
    for (final k in keys) {
      try {
        final data = Map<String, dynamic>.from(box.get(k));
        if (kind!= 'room') {
          final sender = data['sender_id'] as String;
          final receiver = data['receiver_id'] as String;
          if (await isBlocked(sender, receiver)) {
            await box.delete(k);
            continue;
          }
        }
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

  // ====== Chats list ======
  Future<List<Map<String, dynamic>>> getUserChats(String userId) async {
    final response = await _supabase.from('private_messages')
      .select('chat_id, sender_id, receiver_id, content, created_at, deleted_at, deleted_for')
      .or('sender_id.eq.$userId,receiver_id.eq.$userId')
      .isFilter('deleted_at', null)
      .order('created_at', ascending: false);

    final Map<String, Map<String, dynamic>> chats = {};
    for (var msg in response) {
      final deletedFor = (msg['deleted_for'] as List?)?.cast<String>()?? [];
      if (deletedFor.contains(userId)) continue;

      final chatId = msg['chat_id'];
      if (chats.containsKey(chatId)) continue;

      final peerId = msg['sender_id'] == userId? msg['receiver_id'] : msg['sender_id'];
      if (await isBlocked(userId, peerId)) continue;

      final peerData = await _supabase.from(SupabaseConfig.tUsers)
        .select('id, username, avatar_url, is_online')
        .eq('id', peerId)
        .maybeSingle();

      if (peerData!= null) {
        chats[chatId] = {
          'chat_id': chatId,
          'id': chatId,
          'peer_id': peerData['id'],
          'peer': {
            'id': peerData['id'],
            'username': peerData['username']?? 'مستخدم',
            'avatar_url': peerData['avatar_url'],
            'is_online': peerData['is_online']?? false,
          },
          'peer_name': peerData['username']?? 'مستخدم',
          'peer_avatar': peerData['avatar_url'],
          'is_online': peerData['is_online']?? false,
          'last_message': msg['content'],
          'last_message_time': msg['created_at'],
          'unread_count': 0,
        };
      }
    }
    return chats.values.toList();
  }

  Future<int> getUnreadCount(String userId, String peerId) async {
    final chatId = _getChatId(userId, peerId);
    final res = await _supabase.from('private_messages').select('id')
      .eq('chat_id', chatId).eq('receiver_id', userId).isFilter('read_at', null);
    return (res as List).length;
  }

  Future<Map<String, dynamic>?> getLastPrivateMessage(String userId, String peerId) async {
    final chatId = _getChatId(userId, peerId);
    return await _supabase.from('private_messages').select()
      .eq('chat_id', chatId).order('created_at', ascending: false).limit(1).maybeSingle();
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
