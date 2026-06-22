import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_snackbar.dart';
import 'private_chat_screen.dart';
import '../users_grid_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final _chatService = ChatService();
  List<ChatModel> _chats = [];
  bool _loading = true;

  // للانميشن عند الحذف
  final Set<String> _removingIds = {};

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _loading = true);
    try {
      final user = context.read<AuthProvider>().user!;
      final chats = await _chatService.getUserChats(user.id);
      if (!mounted) return;
      setState(() {
        _chats = chats.map((c) => ChatModel.fromJson(c)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAppSnack(context, 'فشل تحميل المحادثات', success: false);
      }
    }
  }

  void _openChat(ChatModel chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          chatId: chat.id,
          peer: chat.peer,
        ),
      ),
    ).then((_) => _loadChats());
  }

  // --- Bottom Sheet حذف احترافي ---
  Future<bool?> _showDeleteSheet(BuildContext context, String peerName) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(
                color: AppColors.textSub.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              )),
              const SizedBox(height: 20),
              const Icon(Icons.delete_outline_rounded, size: 44, color: AppColors.danger),
              const SizedBox(height: 12),
              Text('حذف دردشة $peerName؟',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.white)),
              const SizedBox(height: 6),
              const Text('سيتم حذف المحادثة من جهازك فقط',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppColors.textSub)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.white,
                    side: const BorderSide(color: AppColors.glassBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
                )),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('حذف', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // حذف دردشة - مع انميشن
  Future<void> _deleteChat(ChatModel chat) async {
    final ok = await _showDeleteSheet(context, chat.peer.username);
    if (ok!= true) return;

    // 1. انميشن خروج
    setState(() => _removingIds.add(chat.id));
    await Future.delayed(const Duration(milliseconds: 220));

    try {
      await _chatService.clearChat(chat.id, isRoom: false);
      if (!mounted) return;
      setState(() {
        _chats.removeWhere((c) => c.id == chat.id);
        _removingIds.remove(chat.id);
      });
      showAppSnack(context, 'تم حذف الدردشة', success: true);
    } catch (e) {
      // رجعها لو فشل
      if (mounted) {
        setState(() => _removingIds.remove(chat.id));
        showAppSnack(context, 'فشل الحذف: $e', success: false);
      }
    }
  }

  void _openUsersSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UsersGridScreen()),
    ).then((_) => _loadChats());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title: const Text(
          'المحادثات',
          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
        ),
      ),
      body: Column(
        children: [
          _buildUsersSearchButton(),
          Expanded(
            child: _loading
      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _chats.isEmpty
         ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadChats,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _chats.length,
                          itemBuilder: (context, index) {
                            final chat = _chats[index];
                            return _buildChatTile(chat);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersSearchButton() {
    return InkWell(
      onTap: _openUsersSearch,
      splashColor: Colors.transparent,
      highlightColor: AppColors.primary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: const Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(Icons.person_search_rounded, color: AppColors.primary),
            SizedBox(width: 12),
            Text(
              'ابحث عن أشخاص للدردشة...',
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: AppColors.textSub,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppColors.textSub),
          const SizedBox(height: 16),
          const Text(
            'لا توجد محادثات',
            style: TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.textSub,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _openUsersSearch,
            icon: const Icon(Icons.person_search_outlined),
            label: const Text('ابحث عن أشخاص', style: TextStyle(fontFamily: 'Tajawal')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(ChatModel chat) {
    final isRemoving = _removingIds.contains(chat.id);

    return AnimatedOpacity(
      opacity: isRemoving? 0.0 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: isRemoving
        ? const SizedBox(height: 0)
          : Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _openChat(chat),
                  onLongPress: () => _deleteChat(chat),
                  splashColor: Colors.transparent,
                  highlightColor: AppColors.primary.withOpacity(0.06),
                  hoverColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          url: chat.peer.avatarUrl,
                          name: chat.peer.username,
                          isOnline: chat.peer.isOnline,
                          size: 50,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      chat.peer.username,
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        color: AppColors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatTime(chat.lastMessageTime),
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      color: AppColors.textSub,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      chat.lastMessage?? 'لا توجد رسائل',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        color: chat.unreadCount > 0? AppColors.white : AppColors.textSub,
                                        fontSize: 13,
                                        fontWeight: chat.unreadCount > 0? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (chat.unreadCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        chat.unreadCount.toString(),
                                        style: const TextStyle(
                                          fontFamily: 'Tajawal',
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) {
      return '${time.day}/${time.month}';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}س';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}د';
    } else {
      return 'الآن';
    }
  }
}
