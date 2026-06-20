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
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });
    }
  }

  Future<void> _send(String text, File? image, File? audio) async {
    if (text.trim().isEmpty && image == null && audio == null) return;
    try {
      await _chat.sendPrivateMessageEx(
        chatId: _chatId,
        peerId: widget.peer.id,
        content: text,
        imageFile: image,
        audioFile: audio,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final err = e.toString();
      if (err.contains('blocked')) {
        showAppSnack(context, 'لا يمكن المراسلة، يوجد حظر', success: false);
      } else if (err.contains('offline')) {
        showAppSnack(context, 'تم حفظ الرسالة، سترسل عند عودة النت', success: true);
      } else {
        showAppSnack(context, 'فشل الإرسال: $e', success: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser!.id;

    if (_creatingChat) {
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
        title: Row(
          children: [
            UserAvatar(
              url: widget.peer.avatarUrl,
              name: widget.peer.username,
              isOnline: widget.peer.isOnline,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.peer.username,
                    style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(widget.peer.isOnline? 'متصل' : 'غير متصل',
                    style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
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
                if (messages.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AppColors.textSub.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text('ابدأ المحادثة مع ${widget.peer.username}',
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
                      message: msg,
                      isMe: isMe,
                      showAvatar: false,
                    );
                  },
                );
              },
            ),
          ),
          ChatInputBar(
            onSend: _send,
          ),
        ],
      ),
    );
  }
}
