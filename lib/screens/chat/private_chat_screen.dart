import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/user_avatar.dart';

class PrivateChatScreen extends StatefulWidget {
  final UserModel otherUser;
  const PrivateChatScreen({super.key, required this.otherUser});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _chatService = ChatService();
  final _scrollController = ScrollController();
  late String _userId;
  MessageModel? _replyToMessage;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _userId = user.id;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String content, {String? audioPath, int? duration, String? imagePath}) async {
    final user = context.read<AuthProvider>().user!;
    final username = user.userMetadata?['username'] as String?? 'مستخدم';
    final avatarUrl = user.userMetadata?['avatar_url'] as String?;
    final chatId = '${[_userId, widget.otherUser.id]..sort()}'.replaceAll(RegExp(r'[\[\], ]'), '');

    final message = MessageModel(
      id: '',
      chatId: chatId,
      senderId: user.id,
      receiverId: widget.otherUser.id,
      senderName: username,
      senderAvatar: avatarUrl,
      content: content,
      type: audioPath!= null
  ? 'voice'
          : imagePath!= null
   ? 'image'
            : 'text',
      audioUrl: audioPath,
      fileUrl: imagePath,
      duration: duration,
      replyToId: _replyToMessage?.id,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await _chatService.sendPrivateMessage(widget.otherUser.id, message);
    setState(() => _replyToMessage = null);

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _setReply(MessageModel message) {
    setState(() => _replyToMessage = message);
  }

  void _cancelReply() {
    setState(() => _replyToMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title: Row(
          children: [
            UserAvatar(
              url: widget.otherUser.avatarUrl,
              name: widget.otherUser.username,
              isOnline: widget.otherUser.isOnline,
              size: 36,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUser.username,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.otherUser.isOnline? 'متصل الآن' : 'غير متصل',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: widget.otherUser.isOnline? AppColors.online : AppColors.textSub,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGrad),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _chatService.getPrivateMessagesStream(_userId, widget.otherUser.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  final messages = snapshot.data?? [];
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'ابدأ المحادثة مع ${widget.otherUser.username}',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.textSub,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = MessageModel.fromJson(messages[index]);
                      final isMe = msg.senderId == _userId;
                      return GestureDetector(
                        onLongPress: () => _setReply(msg),
                        child: MessageBubble(
                          message: msg.toJson(),
                          isMe: isMe,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            ChatInputBar(
              onSendText: (text, replyId) => _sendMessage(text),
              onSendAudio: (path, dur, replyId) => _sendMessage('', audioPath: path, duration: dur),
              onSendImage: (path, replyId) => _sendMessage('', imagePath: path),
              replyToId: _replyToMessage?.id,
              replyToMessage: _replyToMessage,
              onCancelReply: _cancelReply,
            ),
          ],
        ),
      ),
    );
  }
}
