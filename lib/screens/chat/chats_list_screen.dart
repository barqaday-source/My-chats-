import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_helper.dart';
import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/user_avatar.dart';
import 'private_chat_screen.dart';
import '../profile/user_profile_screen.dart';

class ChatPreview {
  final UserModel user;
  final MessageModel? lastMessage;
  final int unreadCount;

  ChatPreview({
    required this.user,
    this.lastMessage,
    this.unreadCount = 0,
  });
}

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});
  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final _authSvc = AuthService();
  final _supabase = Supabase.instance.client;
  List<ChatPreview> _chats = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
    _listenToMessages();
  }

  void _listenToMessages() {
    final me = context.read<AuthProvider>().user!;
    _supabase
     .channel('public:messages')
     .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final msg = MessageModel.fromMap(payload.newRecord);
            if (msg.senderId == me.id || msg.receiverId == me.id) {
              _load(); // حدث القائمة لو وصلت رسالة جديدة
            }
          },
        )
     .subscribe();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final me = context.read<AuthProvider>().user!;
      final rawUsers = await _authSvc.getAllUsers();
      final users = rawUsers.map((json) => UserModel.fromMap(json)).toList();

      List<ChatPreview> previews = [];
      for (final user in users) {
        if (user.id == me.id) continue;

        final chatId = _getChatId(me.id, user.id);

        // جيب آخر رسالة
        final lastMsgRes = await _supabase
         .from('messages')
         .select()
         .eq('chat_id', chatId)
         .order('created_at', ascending: false)
         .limit(1)
         .maybeSingle();

        MessageModel? lastMsg;
        if (lastMsgRes!= null) {
          lastMsg = MessageModel.fromMap(lastMsgRes);
        }

        // جيب عدد الغير مقروءة
        final unreadRes = await _supabase
         .from('messages')
         .select()
         .eq('chat_id', chatId)
         .eq('receiver_id', me.id)
         .eq('is_read', false);

        final unreadCount = (unreadRes as List).length;

        previews.add(ChatPreview(
          user: user,
          lastMessage: lastMsg,
          unreadCount: unreadCount,
        ));
      }

      // رتب حسب آخر رسالة
      previews.sort((a, b) {
        if (a.lastMessage == null) return 1;
        if (b.lastMessage == null) return -1;
        return b.lastMessage!.createdAt.compareTo(a.lastMessage!.createdAt);
      });

      _chats = previews;
    } catch (e) {
      debugPrint('_load chats error: $e');
      _chats = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  String _getChatId(String id1, String id2) {
    final ids = [id1, id2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  String _getLastMessageText(MessageModel msg) {
    switch (msg.type) {
      case MsgType.image:
        return '📷 صورة';
      case MsgType.audio:
        return '🎤 رسالة صوتية ${_fmtDur(msg.duration?? 0)}';
      case MsgType.text:
      default:
        return msg.content;
    }
  }

  String _fmtDur(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _chats
     .where((c) => c.user.username.contains(_search))
     .toList();

    return Container(
      decoration: BoxDecoration(gradient: AppColors.bgGrad),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              const Expanded(
                child: Text(
                  'الدردشات',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSub),
                hintText: 'ابحث عن مستخدم...',
                hintStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                filled: true,
                fillColor: AppColors.bgCard2.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.glassBorder.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
             ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: filtered.isEmpty
                     ? const Center(
                            child: Text(
                              'لا توجد محادثات',
                              style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _ChatTile(
                              preview: filtered[i],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PrivateChatScreen(
                                    peerId: filtered[i].user.id,
                                    peerName: filtered[i].user.username?? 'مجهول',
                                    peerAvatar: filtered[i].user.avatarUrl,
                                  ),
                                ),
                              ).then((_) => _load()),
                            ),
                          ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatPreview preview;
  final VoidCallback onTap;
  const _ChatTile({required this.preview, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = preview.user;
    final lastMsg = preview.lastMessage;
    final unread = preview.unreadCount;

    return ListTile(
      leading: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: user.id),
            ),
          );
        },
        child: UserAvatar(
          url: user.avatarUrl,
          name: user.username,
          size: 50,
          isOnline: user.isOnline,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              user.username,
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: AppColors.white,
                fontWeight: unread > 0? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          if (lastMsg!= null)
            Text(
              formatMessageTime(lastMsg.createdAt),
              style: const TextStyle(
                fontFamily: 'Tajawal',
                color: AppColors.textSub,
                fontSize: 12,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              lastMsg!= null
               ? _getLastMessageText(lastMsg)
                  : user.isOnline
                   ? 'متصل الآن'
                      : 'غير متصل',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: unread > 0? AppColors.white : AppColors.textSub,
                fontSize: 13,
                fontWeight: unread > 0? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unread.toString(),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  String _getLastMessageText(MessageModel msg) {
    switch (msg.type) {
      case MsgType.image:
        return '📷 صورة';
      case MsgType.audio:
        final m = (msg.duration?? 0) ~/ 60;
        final s = (msg.duration?? 0) % 60;
        return '🎤 ${m}:${s.toString().padLeft(2, '0')}';
      case MsgType.text:
      default:
        return msg.content;
    }
  }
}
