import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_bubble.dart';

class PrivateChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel peer;
  const PrivateChatScreen({super.key, required this.chatId, required this.peer});

  @override State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final supabase = Supabase.instance.client;
  final _chat = ChatService();
  final ScrollController _scrollController = ScrollController();
  String? _replyToId;
  String? _replyText;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ar', timeago.ArMessages());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    }
  }

  Future<void> _sendMessage(String text, File? imageFile, File? audioFile) async {
    try {
      await _chat.sendPrivateMessageEx(
        peerId: widget.peer.id,
        text: text,
        imageFile: imageFile,
        audioFile: audioFile,
        replyTo: _replyToId,
      );
      setState(() { _replyToId = null; _replyText = null; });
      _scrollToBottom();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الرسالة، سترسل تلقائيا عند عودة النت', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppColors.warning),
      );
      setState(() { _replyToId = null; _replyText = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser!.id;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.peer.username, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 16)),
          Text(widget.peer.isOnline? 'متصل الآن' : 'غير متصل',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: widget.peer.isOnline? AppColors.success : AppColors.textSub)),
        ]),
      ),
      body: Column(children: [
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _chat.getPrivateMessagesStream(currentUserId, widget.peer.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: AppColors.danger, fontFamily: 'Tajawal')));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            final messages = snapshot.data?? [];
            if (messages.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AppColors.navy.withOpacity(0.5)),
              const SizedBox(height: 12),
              const Text('لا توجد رسائل بعد', style: TextStyle(color: AppColors.textSub, fontFamily: 'Tajawal', fontSize: 15)),
              const SizedBox(height: 4),
              const Text('كن أول من يبدأ المحادثة', style: TextStyle(color: AppColors.textSub, fontFamily: 'Tajawal', fontSize: 13)),
            ]));
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg['sender_id'] == currentUserId;
                return MessageBubble(
                  message: msg,
                  isMe: isMe,
                  showAvatar: false,
                  onReply: () => setState(() {
                    _replyToId = msg['id'].toString();
                    _replyText = msg['content']?? 'صورة / صوت';
                  }),
                );
              },
            );
          },
        )),
        if (_replyText!= null) Container(
          color: AppColors.bgCard2,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Expanded(child: Text('رد على: $_replyText', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub))),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() { _replyToId = null; _replyText = null; }))
          ]),
        ),
        ChatInputBar(onSend: _sendMessage),
      ]),
    );
  }

  @override
  void dispose() { _scrollController.dispose(); super.dispose(); }
}
