import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/user_model.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_bubble.dart';

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
  final supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ar', timeago.ArMessages());

    _messagesStream = supabase
       .from('messages')
       .stream(primaryKey: ['id'])
       .eq('chat_id', widget.chatId)
       .order('created_at', ascending: true);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage(String text, String? imageUrl, String? voiceUrl) async {
    try {
      final user = supabase.auth.currentUser!;
      await supabase.from('messages').insert({
        'chat_id': widget.chatId,
        'sender_id': user.id,
        'receiver_id': widget.peer.id,
        'content': text.isEmpty? null : text,
        'media_url': imageUrl,
        'audio_url': voiceUrl,
        'type': voiceUrl!= null? 'audio' : imageUrl!= null? 'image' : 'text',
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإرسال: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser!.id;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.peer.username,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              widget.peer.isOnline? 'متصل الآن' : 'غير متصل',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                color: widget.peer.isOnline? Colors.green[400] : Colors.white54,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('خطأ: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('لا توجد رسائل بعد',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontFamily: 'Tajawal', fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('كن أول من يبدأ المحادثة',
                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Tajawal', fontSize: 14)),
                      ],
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
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
          ChatInputBar(onSend: _sendMessage),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
