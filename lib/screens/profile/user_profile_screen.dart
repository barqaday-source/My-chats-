import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_snackbar.dart';
import '../chat/private_chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final supabase = Supabase.instance.client;
  final _chat = ChatService();

  bool _iBlockedPeer = false;
  bool _peerBlockedMe = false;
  bool get _isBlocked => _iBlockedPeer || _peerBlockedMe;
  bool _checkingBlock = true;

  @override
  void initState() {
    super.initState();
    _checkBlock();
  }

  Future<void> _checkBlock() async {
    final meId = supabase.auth.currentUser?.id;
    if (meId == null || meId == widget.userId) {
      setState(() { _iBlockedPeer = false; _peerBlockedMe = false; _checkingBlock = false; });
      return;
    }
    try {
      final blocking = await supabase
        .from('blocked_users')
        .select('blocker_id')
        .eq('blocker_id', meId)
        .eq('blocked_id', widget.userId)
        .maybeSingle();
      final blockedBy = await supabase
        .from('blocked_users')
        .select('blocker_id')
        .eq('blocker_id', widget.userId)
        .eq('blocked_id', meId)
        .maybeSingle();
      if (mounted) setState(() {
        _iBlockedPeer = blocking != null;
        _peerBlockedMe = blockedBy != null;
        _checkingBlock = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingBlock = false);
    }
  }

  Stream<UserModel?> getUserStream() {
    return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', widget.userId)
      .map((list) => list.isEmpty ? null : UserModel.fromJson(list.first));
  }

  void _startChat(UserModel user) {
    if (_peerBlockedMe) {
      showAppSnack(context, 'فشل الإرسال لأنك محظور من قبل هذا المستخدم', success: false);
      return;
    }
    if (_iBlockedPeer) {
      showAppSnack(context, 'لا يمكنك المراسلة، هذا المستخدم محظور', success: false);
      return;
    }
    final meId = supabase.auth.currentUser!.id;
    final ids = [meId, user.id]..sort();
    final chatId = ids.join('_');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          chatId: chatId,
          peer: user,
        ),
      ),
    ).then((_) => _checkBlock());
  }

  Future<String?> _askReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('سبب البلاغ'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'اكتب السبب...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('إرسال')),
        ],
      ),
    );
  }

  Future<void> _reportUser(UserModel reportedUser) async {
    final reason = await _askReason();
    if (reason == null || reason.isEmpty) return;
    try {
      await _chat.reportUser(widget
