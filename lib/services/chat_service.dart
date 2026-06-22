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

  Future<void> blockUser(String peerId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('not_authenticated');
    await _supabase.from('blocked_users').upsert({
      'blocker_id': user.id,
      'blocked_id': peerId,
    }, onConflict: 'blocker_id,blocked_id');
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
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('chat_id', chatId)
        .neq('sender_id', uid)
        .isFilter('read_at', null);
    } catch (_) {}
  }

  // --- هذا اللي طلبته ---
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
  // ... باقي ملفك كله بدون أي تغيير ...
  // انسخ باقي الدوال من ملفك الأصلي من هنا لتحت
}
