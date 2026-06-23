import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/status_chip.dart';

class PrivateChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel peer;
  const PrivateChatScreen({super.key, required this.chatId, required this.peer});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final supabase = Supabase.instance.client;
  final _chat = ChatService();
  final ScrollController _scroll = ScrollController();

  late String _chatId;
  bool _creatingChat = true;
  Map<String, dynamic>? _replyingTo;

  // الحظر
  bool _iBlockedPeer = false;
  bool _peerBlockedMe = false;
  bool get _isBlocked => _iBlockedPeer || _peerBlockedMe;
  bool _checkingBlock = true;

  // لمنع سبام القراءة
  DateTime _lastReadMark = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    var cid = widget.chatId;
    if (cid.isEmpty || cid == 'new') {
      final meId = supabase.auth.currentUser!.id;
      final ids = [meId, widget.peer.id]..sort();
      cid = ids.join('_');
    }
    if (mounted) setState(() {
      _chatId = cid;
      _creatingChat = false;
    });

    await _checkBlock();
    // علّم مقروء أول ما تفتح
    if (!_isBlocked) _markReadThrottled();
  }

  Future<void> _checkBlock() async {
    setState(() => _checkingBlock = true);
    try {
      final meId = supabase.auth.currentUser!.id;
      final blocking = await supabase
        .from('blocked_users')
        .select('blocker_id')
        .eq('blocker_id', meId)
        .eq('blocked_id', widget.peer.id)
        .maybeSingle();

      final blockedBy = await supabase
        .from('blocked_users')
        .select('blocker_id')
        .eq('blocker_id', widget.peer.id)
        .eq('blocked_id', meId)
        .maybeSingle();

      if (mounted) setState(() {
        _iBlockedPeer = blocking!= null;
        _peerBlockedMe = blockedBy!= null;
      });
    } finally {
      if (mounted) setState(() => _checkingBlock = false);
    }
  }

  Future<void> _unblock() async {
    if (!_iBlockedPeer) {
      showAppSnack(context, 'فشل الإرسال لأنك محظور من قبل هذا المستخدم', success: false);
      return;
    }
    try {
      await _chat.unblockUser(widget.peer.id);
      if (mounted) {
        setState(() {
          _iBlockedPeer = false;
          _peerBlockedMe = false;
        });
        showAppSnack(context, 'تم إلغاء الحظر', success: true);
      }
    } catch (e) {
      showAppSnack(context, 'فشل إلغاء الحظر: $e', success: false);
    }
  }

  void _markReadThrottled() {
    if (_isBlocked) return;
    final now = DateTime.now();
    if (now.difference(_lastReadMark).inSeconds < 2) return;
    _lastReadMark = now;
    _chat.markPrivateMessagesRead(_chatId);
  }

  void _scrollToBottom({bool force = false}) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final current = _scroll.position.pixels;
    // لا تقفز بوجهه إذا صاعد يقرأ قديم
    if (!force && max - current > 200) return;

    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text, File? image, File? audioFile, int audioDuration) async {
    if (_peerBlockedMe) {
      showAppSnack(context, 'فشل الإرسال لأنك محظور من قبل هذا المستخدم', success: false);
      return;
    }
    if (_iBlockedPeer) {
      showAppSnack(context, 'لا يمكنك المراسلة، هذا المستخدم محظور', success: false);
      return;
    }
    if (text.trim().isEmpty && image == null && audioFile == null) return;

    try {
      await _chat.sendPrivateMessageEx(
        chatId: _chatId,
        peerId: widget.peer.id,
        content: text,
        imageFile: image,
        audioFile: audioFile,
        audioDuration: audioDuration,
        replyMessage: _replyingTo,
      );
      if (mounted) setState(() => _replyingTo = null);
      _scrollToBottom(force: true);
    } catch (e) {
      if (!mounted) return;
      final err = e.toString().toLowerCase();
      if (err.contains('blocked')) {
        await _checkBlock();
        showAppSnack(context, _peerBlockedMe
        ? 'فشل الإرسال لأنك محظور من قبل هذا المستخدم'
          : 'لا يمكنك المراسلة، يوجد حظر', success: false);
      } else if (err.contains('offline')) {
        showAppSnack(context, 'تم حفظ الرسالة، سترسل عند عودة النت', success: true);
      } else {
        showAppSnack(context, 'فشل الإرسال: $e', success: false);
      }
    }
  }

  Widget _buildBlockedBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _peerBlockedMe
              ? 'تم حظرك من قبل هذا المستخدم'
                : 'لا يمكنك مراسلة هذا المستخدم',
              style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 14),
            ),
          ),
          if (_iBlockedPeer)
          TextButton(
            onPressed: _unblock,
            child: const Text(
              'إلغاء الحظر',
              style: TextStyle(fontFamily: 'Tajawal', color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser!.id;

    if (_creatingChat || _checkingBlock) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        iconTheme: const IconThemeData(color: AppColors.white),
        title: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
       .from('profiles')
       .stream(primaryKey: ['id'])
       .eq('id', widget.peer.id),
          builder: (context, snap) {
            final data = snap.data?.isNotEmpty == true? snap.data!.first : null;
            final isOnline = data?['is_online']?? widget.peer.isOnline;
            final avatarUrl = data?['avatar_url']?? widget.peer.avatarUrl;
            final username = data?['username']?? widget.peer.username;
            final statusText = (data?['status_text']?? widget.peer.statusText?? '').toString();

            return Row(
              children: [
                UserAvatar(
                  url: avatarUrl,
                  name: username,
                  isOnline: isOnline &&!_isBlocked,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username,
                        style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // NEW: الحالة اليومية، إذا فاضية نرجع للحالة القديمة
                      if (_peerBlockedMe)...[
                        const Text('تم حظرك',
                          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger, fontSize: 12),
                        ),
                      ] else if (_iBlockedPeer)...[
                        const Text('محظور',
                          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger, fontSize: 12),
                        ),
                      ] else if (statusText.isNotEmpty)...[
                        StatusChip(statusText),
                      ] else...[
                        Text(isOnline? 'متصل' : 'غير متصل',
                          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chat.getPrivateMessagesStream(_chatId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('خطأ: ${snap.error}', style: const TextStyle(color: AppColors.danger, fontFamily: 'Tajawal')));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                final messages = snap.data!;

                // علّم مقروء بس إذا أكو رسائل جديدة من الطرف الثاني
                if (messages.isNotEmpty &&!_isBlocked) {
                  final hasUnread = messages.any((m) =>
                    m['sender_id']!= currentUserId &&
                    m['is_read']!= true && m['read_at'] == null
                  );
                  if (hasUnread) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _markReadThrottled());
                  }
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AppColors.textSub.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text(_isBlocked
                     ? (_peerBlockedMe? 'تم حظرك من قبل هذا المستخدم' : 'لا يمكن عرض الرسائل أثناء الحظر')
                        : 'ابدأ المحادثة مع ${widget.peer.username}',
                        style: const TextStyle(color: AppColors.textSub, fontFamily: 'Tajawal')),
                    ]),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe = msg['sender_id'] == currentUserId;
                    return MessageBubble(
                      key: ValueKey(msg['id']),
                      message: msg,
                      isMe: isMe,
                      showAvatar: false,
                      isRoom: false,
                      onReply: _isBlocked? null : () => setState(() => _replyingTo = msg),
                      onDelete: (_) {},
                    );
                  },
                );
              },
            ),
          ),
          if (_isBlocked)
            _buildBlockedBar()
          else
            ChatInputBar(
              onSend: _send,
              replyTo: _replyingTo,
              onCancelReply: () => setState(() => _replyingTo = null),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}
