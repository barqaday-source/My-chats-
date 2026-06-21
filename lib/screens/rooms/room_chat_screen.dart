import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_colors.dart';
import '../../models/room_model.dart';
import '../../services/chat_service.dart';
import '../../services/room_service.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/app_snackbar.dart';

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

  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    final uid = supabase.auth.currentUser?.id;
    if (uid!= null) {
      _chat.setUserOnlineInRoom(uid, widget.room.id);
    }
  }

  @override
  void dispose() {
    final uid = supabase.auth.currentUser?.id;
    if (uid!= null) {
      _chat.setUserOfflineInRoom(uid, widget.room.id);
    }
    _scrollController.dispose();
    super.dispose();
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

  // كان: Future<void> _sendMessage(String text, File? imageFile, String? audioPath, int audioDuration)
  // صار: File? audioFile بدل String? audioPath
  Future<void> _sendMessage(String text, File? imageFile, File? audioFile, int audioDuration) async {
    if (text.trim().isEmpty && imageFile == null && audioFile == null) return;
    try {
      await _chat.sendMessageToRoomEx(
        roomId: widget.room.id,
        content: text,
        imageFile: imageFile,
        audioFile: audioFile,
        audioDuration: audioDuration,
        replyMessage: _replyingTo,
      );
      if (mounted) {
        showAppSnack(context, 'تم الإرسال', success: true);
        setState(() => _replyingTo = null);
      }
      _scrollToBottom();
    } catch (e) {
      final isOffline = e.toString().contains('offline');
      if (mounted) {
        showAppSnack(context,
          isOffline? 'تم الحفظ، سترسل تلقائيا عند عودة النت' : 'فشل الإرسال',
          success: isOffline,
        );
        setState(() => _replyingTo = null);
      }
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
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.room.name, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontWeight: FontWeight.w700, fontSize: 16), overflow: TextOverflow.ellipsis),
          Text(widget.room.onlineCount > 0? '${widget.room.onlineCount} متصل' : 'غرفة عامة',
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.people_alt_outlined, color: AppColors.white),
            onPressed: () async {
              final members = await _roomSvc.getRoomMembers(widget.room.id);
              if (!context.mounted) return;
              showModalBottomSheet(context: context, backgroundColor: AppColors.bgCard,
                builder: (_) => ListView(
                padding: const EdgeInsets.all(12),
                children: members.map((m) => ListTile(
                  leading: CircleAvatar(backgroundImage: m['avatar_url']!= null? NetworkImage(m['avatar_url']) : null,
                    child: m['avatar_url'] == null? Text((m['username']?? 'U')[0].toUpperCase()) : null),
                  title: Text(m['username']?? 'مستخدم', style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
                  subtitle: Text(m['is_online'] == true? 'متصل' : 'غير متصل', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub)),
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
                Icon(Icons.forum_outlined, size: 56, color: AppColors.textSub.withOpacity(0.5)),
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
                    onReply: () => setState(() => _replyingTo = msg),
                    onDelete: (_) => setState(() {}),
                  );
                },
              );
            },
          ),
        ),
        ChatInputBar(
          onSend: _sendMessage,
          replyTo: _replyingTo,
          onCancelReply: () => setState(() => _replyingTo = null),
        ),
      ]),
    );
  }
}
