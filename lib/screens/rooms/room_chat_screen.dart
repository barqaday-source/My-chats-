import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_colors.dart';
import '../../models/room_model.dart';
import '../../services/chat_service.dart';
import '../../services/room_service.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/message_bubble.dart';

class RoomChatScreen extends StatefulWidget {
  final RoomModel room;
  const RoomChatScreen({super.key, required this.room});
  @override State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen> {
  final supabase = Supabase.instance.client;
  final _chat = ChatService();
  final _roomSvc = RoomService();
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
      await _chat.sendMessageToRoomEx(
        roomId: widget.room.id,
        text: text,
        imageFile: imageFile,
        audioFile: audioFile,
        replyTo: _replyToId,
      );
      setState(() { _replyToId = null; _replyText = null; });
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الرسالة، سترسل تلقائيا عند عودة النت', style: TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: AppColors.warning),
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
          Text(widget.room.name, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 16), overflow: TextOverflow.ellipsis),
          Text(widget.room.onlineCount > 0? '${widget.room.onlineCount} متصل' : 'غرفة عامة',
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.people_alt_outlined, color: AppColors.navy),
            onPressed: () async {
              final members = await _roomSvc.getRoomMembers(widget.room.id);
              if (!context.mounted) return;
              showModalBottomSheet(context: context, builder: (_) => ListView(
                children: members.map((m) => ListTile(
                  leading: CircleAvatar(backgroundImage: m['avatar_url']!= null? NetworkImage(m['avatar_url']) : null),
                  title: Text(m['username']?? 'مستخدم', style: const TextStyle(fontFamily: 'Tajawal')),
                  subtitle: Text(m['is_online']? 'متصل' : 'غير متصل', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                )).toList(),
              ));
            }),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _chat.getRoomMessagesStream(widget.room.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: AppColors.danger, fontFamily: 'Tajawal')));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              final messages = snapshot.data?? [];
              if (messages.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.forum_outlined, size: 56, color: AppColors.navy.withOpacity(0.5)),
                const SizedBox(height: 12),
                const Text('لا توجد رسائل بعد', style: TextStyle(color: AppColors.textSub, fontFamily: 'Tajawal', fontSize: 15)),
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
                    showAvatar: true,
                    isRoom: true,
                    onReply: () => setState(() {
                      _replyToId = msg['id'].toString();
                      _replyText = msg['content']?? 'صورة / صوت';
                    }),
                  );
                },
              );
            },
          ),
        ),
        if (_replyText!= null) Container(
          color: AppColors.bgCard2,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Expanded(child: Text('رد على: $_replyText', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub))),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() { _replyToId = null; _replyText = null; }))
          ]),
        ),
        ChatInputBar(
          onSend: _sendMessage,
        ),
      ]),
    );
  }

  @override
  void dispose() { _scrollController.dispose(); super.dispose(); }
}
