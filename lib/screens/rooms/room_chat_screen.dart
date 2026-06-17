import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/room_service.dart';
import '../../models/room_model.dart';
import '../../models/message_model.dart';

class RoomChatScreen extends StatefulWidget {
  final RoomModel room;

  const RoomChatScreen({super.key, required this.room});

  @override
  State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen> {
  final _roomSvc = RoomService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    _msgCtrl.clear();

    final message = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: widget.room.id,
      senderId: user.id,
      receiverId: '', // فاضي للغرف
      senderName: auth.userProfile?['username']?? user.email?.split('@')[0]?? 'مجهول',
      senderAvatar: auth.userProfile?['avatar_url'],
      content: text,
      createdAt: DateTime.now(),
    );

    await _roomSvc.sendRoomMessage(widget.room.id, message);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user!.id;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room.name, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
            Text(
              '${widget.room.memberCount} عضو',
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGrad),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _roomSvc.getRoomMessages(widget.room.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data!;
                  return ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      final isMe = msg.senderId == currentUserId;
                      return Align(
                        alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe? AppColors.primary : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Text(
                                  msg.senderName?? 'مجهول', // ضفنا??
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              Text(
                                msg.content,
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: isMe? AppColors.white : AppColors.text,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة...',
                        hintStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                        filled: true,
                        fillColor: AppColors.bgCard2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
