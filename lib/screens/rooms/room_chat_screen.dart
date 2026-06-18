import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../models/message_model.dart';
import '../../models/room_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/room_service.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_bubble.dart';
import 'room_members_screen.dart';

class RoomChatScreen extends StatefulWidget {
  final RoomModel room;
  const RoomChatScreen({super.key, required this.room});

  @override
  State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen> {
  final _chatService = ChatService();
  final _roomService = RoomService();
  final _supabase = Supabase.instance.client;
  final _textFocusNode = FocusNode();
  final _scrollController = ScrollController();

  Stream<List<Map<String, dynamic>>>? _messagesStream;
  String? _replyToId;
  String? _replyToContent;
  List<Map<String, dynamic>> _onlineMembers = [];

  @override
  void initState() {
    super.initState();
    final me = context.read<AuthProvider>().user!;
    _messagesStream = _chatService.getRoomMessagesStream(widget.room.id);
    _chatService.setUserOnlineInRoom(me.id, widget.room.id);
    _loadOnlineMembers();
  }

  @override
  void dispose() {
    final me = context.read<AuthProvider>().user!;
    _chatService.setUserOfflineInRoom(me.id, widget.room.id);
    _textFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOnlineMembers() async {
    final members = await _roomService.getRoomMembers(widget.room.id);
    if (mounted) {
      setState(() {
        _onlineMembers = members.where((m) => m['is_online'] == true).toList();
      });
    }
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
                builder: (_) => RoomMembersScreen(room: widget.room),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.room.name,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${_onlineMembers.length} متصل من ${widget.room.memberCount}',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textSub,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoomMembersScreen(room: widget.room),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGrad),
        child: Column(
          children: [
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
                        isRoom: true,
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
            ChatInputBar(
              replyToId: _replyToId,
              replyToContent: _replyToContent,
              onCancelReply: () => setState(() {
                _replyToId = null;
                _replyToContent = null;
              }),
              onSendText: (text, replyId) async {
                final msg = MessageModel(
                  id: const Uuid().v4(),
                  chatId: widget.room.id,
                  senderId: me.id,
                  receiverId: '',
                  content: text,
                  type: 'text',
                  createdAt: DateTime.now(),
                  replyToId: replyId,
                );
                await _chatService.sendMessageToRoom(widget.room.id, msg);
              },
              onSendImage: (file, replyId) async {
                final fileName = '${const Uuid().v4()}.jpg';
                await _supabase.storage.from('chat-images').upload(fileName, file);
                final url = _supabase.storage.from('chat-images').getPublicUrl(fileName);

                final msg = MessageModel(
                  id: const Uuid().v4(),
                  chatId: widget.room.id,
                  senderId: me.id,
                  receiverId: '',
                  content: '',
                  type: 'image',
                  mediaUrl: url,
                  createdAt: DateTime.now(),
                  replyToId: replyId,
                );
                await _chatService.sendMessageToRoom(widget.room.id, msg);
              },
              onSendVoice: (file, duration, replyId) async {
                final fileName = '${const Uuid().v4()}.aac';
                await _supabase.storage.from('chat-audio').upload(fileName, file);
                final url = _supabase.storage.from('chat-audio').getPublicUrl(fileName);

                final msg = MessageModel(
                  id: const Uuid().v4(),
                  chatId: widget.room.id,
                  senderId: me.id,
                  receiverId: '',
                  content: '',
                  type: 'voice',
                  audioUrl: url,
                  duration: duration,
                  createdAt: DateTime.now(),
                  replyToId: replyId,
                );
                await _chatService.sendMessageToRoom(widget.room.id, msg);
              },
            ),
          ],
        ),
      ),
    );
  }
}
