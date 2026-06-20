import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/app_snackbar.dart';

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
    if (text.trim().isEmpty && imageFile == null && audioFile == null) return;
    try {
      await _chat.sendPrivateMessageEx(
        chatId: widget.chatId,
        peerId: widget.peer.id,
        content: text,
        imageFile: imageFile,
        audioFile: audioFile,
        replyTo: _replyToId,
      );
      if (mounted) showAppSnack(context, 'تم الإرسال', success: true);
      setState(() { _replyToId = null; _replyText = null; });
      _scrollToBottom();
    } catch (e) {
      final isOffline = e.toString().contains('offline');
      if (mounted) {
        showAppSnack(context,
          isOffline? 'تم الحفظ، سترسل تلقائيا عند عودة النت' : 'فشل الإرسال',
          success: isOffline,
        );
      }
      setState(() { _replyToId = null; _replyText = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser!.id;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.white),
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: widget.peer.avatarUrl!= null? NetworkImage(widget.peer.avatarUrl!) : null,
            child: widget.peer.avatarUrl == null? Text(widget.peer.username[0].toUpperCase()) : null,
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.peer.username, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            Text(widget.peer.isOnline? 'متصل الآن' : 'غير متصل',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: widget.peer.isOnline? AppColors.success : AppColors.textSub)),
          ]),
        ]),
      ),
      body: Column(children: [
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _chat.getPrivateMessagesStream(widget.peer.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: AppColors.danger, fontFamily: 'Tajawal')));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            final messages = snapshot.data?? [];
            if (messages.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AppColors.textSub.withOpacity(0.5)),
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
            IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.textSub), onPressed: () => setState(() { _replyToId = null; _replyText = null; }))
          ]),
        ),
        ChatInputBar(onSend: _sendMessage),
      ]),
    );
  }

  @override
  void dispose() { _scrollController.dispose(); super.dispose(); }
}
