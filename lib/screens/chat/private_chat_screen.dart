import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../widgets/chat_input.dart';
import '../../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final bool isOfficial;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.isOfficial = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  late final RealtimeChannel _roomChannel;
  int _onlineCount = 0;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ar', timeago.ArMessages());

    _messagesStream = supabase
     .from('messages')
     .stream(primaryKey: ['id'])
     .eq('room_id', widget.roomId)
     .order('created_at', ascending: true)
     .map((maps) => maps.toList());

    _setupPresence();
  }

  void _setupPresence() {
    _roomChannel = supabase.channel('room_${widget.roomId}');

    _roomChannel
     .onPresenceSync((payload) {
          final presenceState = _roomChannel.presenceState();
          if (mounted) setState(() => _onlineCount = presenceState.length);
        })
     .subscribe((status, _) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            final userId = supabase.auth.currentUser!.id;
            final profile = await supabase
             .from('profiles')
             .select('username, avatar_url')
             .eq('id', userId)
             .single();

            await _roomChannel.track({
              'user_id': userId,
              'username': profile['username'],
              'online_at': DateTime.now().toIso8601String(),
            });
          }
        });
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
      final profile = await supabase
       .from('profiles')
       .select('username, avatar_url')
       .eq('id', user.id)
       .single();

      await supabase.from('messages').insert({
        'room_id': widget.roomId,
        'user_id': user.id,
        'username': profile['username']?? 'مجهول',
        'avatar_url': profile['avatar_url'],
        'content': text.isEmpty? null : text,
        'image_url': imageUrl,
        'voice_url': voiceUrl,
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

  void _showRoomInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (widget.isOfficial)
                  const Icon(Icons.verified, color: Colors.blue, size: 24),
                if (widget.isOfficial) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.roomName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.circle, color: Colors.green[400], size: 12),
                const SizedBox(width: 8),
                Text(
                  '$_onlineCount متصل الآن',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser!.id;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: GestureDetector(
          onTap: _showRoomInfo,
          child: Row(
            children: [
              if (widget.isOfficial)
                const Icon(Icons.verified, color: Colors.blue, size: 20),
              if (widget.isOfficial) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.roomName,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '$_onlineCount متصل',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        color: Colors.green[400],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showRoomInfo,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'خطأ: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد رسائل بعد',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontFamily: 'Tajawal',
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'كن أول من يبدأ المحادثة',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontFamily: 'Tajawal',
                            fontSize: 14,
                          ),
                        ),
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
                    final isMe = msg['user_id'] == currentUserId;
                    final showAvatar = index == 0 || messages[index - 1]['user_id']!= msg['user_id'];

                    return MessageBubble(
                      message: msg,
                      isMe: isMe,
                      showAvatar: showAvatar,
                    );
                  },
                );
              },
            ),
          ),
          ChatInput(onSend: _sendMessage),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    supabase.removeChannel(_roomChannel);
    super.dispose();
  }
}
