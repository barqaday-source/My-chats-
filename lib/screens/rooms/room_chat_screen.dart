import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/room_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/room_service.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/user_avatar.dart';
import 'room_members_screen.dart';

class RoomChatScreen extends StatefulWidget {
  final RoomModel room;
  const RoomChatScreen({super.key, required this.room});

  @override
  State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen> with WidgetsBindingObserver {
  final _roomService = RoomService();
  final _supabase = Supabase.instance.client;
  final _scrollController = ScrollController();

  List<UserModel> _onlineMembers = [];
  StreamSubscription? _membersSub;
  late String _userId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final user = context.read<AuthProvider>().user!;
    _userId = user.id;
    _joinRoom();
    _subscribeToMembers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _leaveRoom();
    _membersSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _joinRoom();
    } else if (state == AppLifecycleState.paused) {
      _leaveRoom();
    }
  }

  Future<void> _joinRoom() async {
    await _roomService.joinRoom(widget.room.id, _userId);
  }

  Future<void> _leaveRoom() async {
    try {
      await _roomService.leaveRoom?.call(widget.room.id, _userId);
    } catch (_) {}
  }

  void _subscribeToMembers() {
    _membersSub = _supabase
      .from('room_members')
      .stream(primaryKey: ['id'])
      .eq('room_id', widget.room.id)
      .listen((data) async {
      final members = await _roomService.getRoomMembers(widget.room.id);
      if (!mounted) return;
      final onlineData = members.where((m) => m['is_online'] == true).toList();
      setState(() {
        _onlineMembers = onlineData.map((m) => UserModel.fromJson(m)).toList();
      });
    });
  }

  Future<void> _sendMessage(String text, String? imageUrl, String? voiceUrl) async {
    try {
      final auth = context.read<AuthProvider>();
      final user = _supabase.auth.currentUser!;
      final profile = auth.userProfile;

      await _supabase.from('room_messages').insert({
        'chat_id': widget.room.id,
        'sender_id': user.id,
        'sender_name': profile?['username']?? 'مستخدم',
        'sender_avatar': profile?['avatar_url'],
        'content': text.isEmpty? null : text,
        'media_url': imageUrl,
        'audio_url': voiceUrl,
        'type': voiceUrl!= null? 'audio' : imageUrl!= null? 'image' : 'text',
        'is_read': false,
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإرسال: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title: Column(
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
              '${_onlineMembers.length} متصل',
              style: const TextStyle(
                fontFamily: 'Tajawal',
                color: AppColors.online,
                fontSize: 11,
              ),
            ),
          ],
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
            _buildOnlineBar(),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _supabase
                   .from('room_messages')
                   .stream(primaryKey: ['id'])
                   .eq('chat_id', widget.room.id)
                   .order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  final messages = snapshot.data?? [];
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'ابدأ المحادثة الآن',
                        style: TextStyle(
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
                      final msg = messages[index];
                      final isMe = msg['sender_id'] == _userId;
                      return MessageBubble(
                        message: msg,
                        isMe: isMe,
                      );
                    },
                  );
                },
              ),
            ),
            ChatInputBar(
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineBar() {
    if (_onlineMembers.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _onlineMembers.length,
        itemBuilder: (context, index) {
          final member = _onlineMembers[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                UserAvatar(
                  url: member.avatarUrl,
                  name: member.username,
                  isOnline: true,
                  size: 32,
                ),
                const SizedBox(height: 2),
                Text(
                  member.username.length > 6
                    ? '${member.username.substring(0, 6)}...'
                      : member.username,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.white,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
