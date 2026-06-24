import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/user_avatar.dart';

class PrivateChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel peer;

  const PrivateChatScreen({
    super.key,
    required this.chatId,
    required this.peer,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _chatService = ChatService();
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final msgs = await _chatService.getMessages(widget.chatId);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAppSnack(context, 'فشل تحميل الرسائل', success: false);
      }
    }
  }

  Future<void> _markAsRead() async {
    final user = context.read<AuthProvider>().user!;
    await _chatService.markAsRead(widget.chatId, user.id);
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    final user = context.read<AuthProvider>().user!;
    setState(() => _sending = true);
    _messageCtrl.clear();

    try {
      await _chatService.sendMessage(
        chatId: widget.chatId,
        senderId: user.id,
        content: text,
      );
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'فشل الإرسال', success: false);
        _messageCtrl.text = text;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthProvider>().user!;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title: Row(
          children: [
            UserAvatar(
              url: widget.peer.avatarUrl,
              name: widget.peer.username,
              isOnline: widget.peer.isOnline,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.peer.username,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                  Text(
                    widget.peer.isOnline? 'متصل الآن' : 'غير متصل',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      color: widget.peer.isOnline? AppColors.success : AppColors.textSub,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGrad),
        child: Column(
          children: [
            Expanded(
              child: _loading
           ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _messages.isEmpty
             ? const Center(
                        child: Text(
                          'ابدأ المحادثة',
                          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['sender_id'] == me.id;
                          return _buildMessageBubble(msg, isMe);
                        },
                      ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final content = msg['content'] as String;
    final time = DateTime.parse(msg['created_at'] as String);

    return Align(
      alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe? AppColors.primary : AppColors.glassBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe? 16 : 4),
            bottomRight: Radius.circular(isMe? 4 : 16),
          ),
          border: isMe? null : Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 15,
                color: isMe? Colors.white : AppColors.text,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(time),
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                color: isMe? Colors.white70 : AppColors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 12, 12, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: const Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glassBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: TextField(
                controller: _messageCtrl,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text),
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالة...',
                  hintStyle: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _sending? null : _sendMessage,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _sending? AppColors.textSub : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: _sending
         ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) {
      return '${time.day}/${time.month}';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}س';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}د';
    } else {
      return 'الآن';
    }
  }
}
