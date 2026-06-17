import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_colors.dart';
import 'private_chat_screen.dart';
import '../profile/user_profile_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _subscribeToChats();
  }

  Future<void> _loadChats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
         .from('private_messages')
         .select()
         .or('sender_id.eq.$userId,receiver_id.eq.$userId')
         .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> chatMap = {};

      for (var msg in response) {
        final otherUserId = msg['sender_id'] == userId? msg['receiver_id'] : msg['sender_id'];
        final chatKey = otherUserId;

        if (!chatMap.containsKey(chatKey)) {
          final otherUser = await _supabase
             .from('users')
             .select()
             .eq('id', otherUserId)
             .single();

          chatMap[chatKey] = {
            'peerId': otherUserId,
            'peerName': otherUser['username']?? 'مجهول',
            'peerAvatar': otherUser['avatar_url'],
            'isOnline': otherUser['is_online']?? false,
            'lastMessage': msg['content']?? '',
            'lastMessageType': msg['type']?? 'text',
            'lastMessageTime': msg['created_at'],
            'unreadCount': 0,
          };
        }
      }

      setState(() {
        _chats = chatMap.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الدردشات: $e')),
        );
      }
    }
  }

  void _subscribeToChats() {
    _supabase
       .channel('public:private_messages')
       .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'private_messages',
          callback: (payload) {
            _loadChats();
          },
        )
       .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title: const Text(
          'المحادثات',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
      ),
      body: _isLoading
   ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
             ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 80,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد محادثات بعد',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    return ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PrivateChatScreen(
                              peerId: chat['peerId'],
                              peerName: chat['peerName'],
                              peerAvatar: chat['peerAvatar'],
                            ),
                          ),
                        );
                      },
                      leading: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(userId: chat['peerId']),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.bgCard2,
                              backgroundImage: chat['peerAvatar']!= null
                   ? CachedNetworkImageProvider(chat['peerAvatar'])
                                  : null,
                              child: chat['peerAvatar'] == null
                   ? Text(
                                      chat['peerName'][0].toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        color: AppColors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            if (chat['isOnline'])
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: AppColors.online,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.bgCard,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      title: Text(
                        chat['peerName'],
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        chat['lastMessageType'] == 'image'
            ? '📷 صورة'
                            : chat['lastMessageType'] == 'voice'
                               ? '🎤 رسالة صوتية'
                                : chat['lastMessage'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            timeago.format(
                              DateTime.parse(chat['lastMessageTime']),
                              locale: 'ar',
                            ),
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (chat['unreadCount'] > 0)...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${chat['unreadCount']}',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: AppColors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
