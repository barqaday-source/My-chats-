import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/user_avatar.dart';
import '../profile/user_profile_screen.dart';

class PrivateChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String? peerAvatar;

  const PrivateChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _chatService = ChatService();
  final _supabase = Supabase.instance.client;
  final _textFocusNode = FocusNode();
  final _scrollController = ScrollController();

  Stream<List<Map<String, dynamic>>>? _messagesStream;
  UserModel? _peerUser;
  String? _replyToId;
  String? _replyToContent;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    final me = context.read<AuthProvider>().user!;
    _messagesStream = _chatService.getPrivateMessagesStream(me.id, widget.peerId);
    _loadPeerUser();
    _markMessagesAsRead();
    _checkIfBlocked();
  }

  @override
  void dispose() {
    _textFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPeerUser() async {
    try {
      final res = await _supabase
          .from('users')
          .select()
          .eq('id', widget.peerId)
          .single();
      if (mounted) setState(() => _peerUser = UserModel.fromJson(res));
    } catch (e) {
      debugPrint('Load peer error: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    final me = context.read<AuthProvider>().user!;
    await _chatService.markAsRead(me.id, widget.peerId);
  }

  Future<void> _checkIfBlocked() async {
    final me = context.read<AuthProvider>().user!;
    final res = await _supabase
        .from('blocked_users')
        .select()
        .eq('blocker_id', me.id)
        .eq('blocked_id', widget.peerId)
        .maybeSingle();
    if (mounted) setState(() => _isBlocked = res != null);
  }

  String _getChatId(String id1, String id2) {
    final sorted = [id1, id2]..sort();
    return sorted.join('_');
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: widget.peerId),
              ),
            );
          },
          child: Row(
            children: [
              UserAvatar(
                url: _peerUser?.avatarUrl ?? widget.peerAvatar,
                name: widget.peerName,
                size: 36,
                isOnline: _peerUser?.isOnline ?? false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.peerName,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_peerUser != null)
                      Text(
                        _peerUser!.isOnline ? 'متصل الآن' : 'غير متصل',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: _peerUser!.isOnline
                              ? AppColors.online
                              : AppColors.textSub,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGrad),
        child: Column(
          children: [
            if (_isBlocked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppColors.danger.withOpacity(0.2),
                child: const Text(
                  'لقد قمت بحظر هذا المستخدم. لا يمكنك المراسلة.',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.danger,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا توجد رسائل',
                        style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                      ),
                    );
                  }

                  final messages = snapshot.data!;
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final replyMsg = messages.firstWhere(
                        (m) => m['id'] == msg['reply_to_id'],
                        orElse: () => {},
                      );

                      return MessageBubble(
                        message: msg,
                        isMe: msg['sender_id'] == me.id,
                        isRoom: false,
                        replyToContent: replyMsg['content'],
                        onReply: () {
                          setState(() {
                            _replyToId = msg['id'];
                            _replyToContent = msg['content'];
                          });
                          _textFocusNode.requestFocus();
                        },
                      );
                    },
                  );
                },
              ),
            ),
            if (!_isBlocked)
              ChatInputBar(
                replyToId: _replyToId,
                replyToContent: _replyToContent,
                onCancelReply: () => setState(() {
                  _replyToId = null;
                  _replyToContent = null;
                }),
                onSendText: (text, replyId) async {
                  final chatId = _getChatId(me.id, widget.peerId);
                  final msg = MessageModel(
                    id: const Uuid().v4(),
                    chatId: chatId,
                    senderId: me.id,
                    receiverId: widget.peerId,
                    content: text,
                    type: 'text',
                    createdAt: DateTime.now(),
                    replyToId: replyId,
                  );
                  await _chatService.sendPrivateMessage(widget.peerId, msg);
                },
                onSendImage: (file, replyId) async {
                  final chatId = _getChatId(me.id, widget.peerId);
                  final fileName = '${const Uuid().v4()}.jpg';
                  await _supabase.storage.from('chat-images').upload(fileName, file);
                  final url = _supabase.storage.from('chat-images').getPublicUrl(fileName);

                  final msg = MessageModel(
                    id: const Uuid().v4(),
                    chatId: chatId,
                    senderId: me.id,
                    receiverId: widget.peerId,
                    content: '',
                    type: 'image',
                    mediaUrl: url,
                    createdAt: DateTime.now(),
                    replyToId: replyId,
                  );
                  await _chatService.sendPrivateMessage(widget.peerId, msg);
                },
                onSendVoice: (file, duration, replyId) async {
                  final chatId = _getChatId(me.id, widget.peerId);
                  final fileName = '${const Uuid().v4()}.aac';
                  await _supabase.storage.from('chat-audio').upload(fileName, file);
                  final url = _supabase.storage.from('chat-audio').getPublicUrl(fileName);

                  final msg = MessageModel(
                    id: const Uuid().v4(),
                    chatId: chatId,
                    senderId: me.id,
                    receiverId: widget.peerId,
                    content: '',
                    type: 'voice',
                    audioUrl: url,
                    duration: duration,
                    createdAt: DateTime.now(),
                    replyToId: replyId,
                  );
                  await _chatService.sendPrivateMessage(widget.peerId, msg);
                },
              ),
          ],
        ),
      ),
    );
  }
}
