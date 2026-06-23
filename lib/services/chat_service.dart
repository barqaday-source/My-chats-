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
  Future<bool> isBlockingPeer(String peerId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final res = await _supabase
     .from('blocked_users')
     .select('blocker_id')
     .eq('blocker_id', uid)
     .eq('blocked_id', peerId)
     .maybeSingle();
      return res!= null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBlockedByPeer(String peerId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final res = await _supabase
     .from('blocked_users')
     .select('blocker_id')
     .eq('blocker_id', peerId)
     .eq('blocked_id', uid)
     .maybeSingle();
      return res!= null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEitherBlocked(String userId, String peerId) async {
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

  Future<bool> isBlocked(String userId, String peerId) => isEitherBlocked(userId, peerId);

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

  Future<String> blockUser(String peerId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('not_authenticated');
    if (await isBlockingPeer(peerId)) {
      return 'already_blocked';
    }
    try {
      await _supabase.from('blocked_users').insert({
        'blocker_id': user.id,
        'blocked_id': peerId,
      });
      return 'blocked';
    } on PostgrestException catch (e) {
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

  // ====== Report - مصلح ======
  Future<void> reportUser(String peerId, String reason) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('not_authenticated');
    await _supabase.from(SupabaseConfig.tReports).insert({
      'reporter_id': user.id,
      'reported_id': peerId,
      'reason': reason,
      'status': 'new',
    }).select();
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
    if (await isBlockingPeer(peerId)) {
      throw Exception('blocking_peer');
    }
    if (await isBlockedByPeer(peerId)) {
      throw Exception('blocked_by_peer');
    }
    final payload = {
      'chat_id': chatId,
      'sender_id': user.id,
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
    final blocked = await _supabase
   .from('blocked_users')
   .select('blocker_id')
   .or('and(blocker_id.eq.$sender,blocked_id.eq.$receiver),and(blocker_id.eq.$receiver,blocked_id.eq.$sender)')
   .maybeSingle();
    if (blocked!= null) {
      final blockerId = blocked['blocker_id'] as String;
      if (blockerId == receiver) {
        throw Exception('blocked_by_peer');
      } else {
        throw Exception('blocking_peer');
      }
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
      'content': content
