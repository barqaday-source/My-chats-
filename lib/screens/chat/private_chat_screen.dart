import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
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

  Future<bool?> _showDeleteSheet(BuildContext context, String peerName) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              border: Border(top: BorderSide(color: AppColors.glassBorder, width: 0.5)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(
                    color: AppColors.divider, borderRadius: BorderRadius.circular(2),
                  )),
                  const SizedBox(height: 20),
                  const Icon(Icons.delete_outline_rounded, size: 44, color: AppColors.danger),
                  const SizedBox(height: 12),
                  Text('حذف دردشة $peerName؟',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
                  const SizedBox(height: 6),
                  const Text('سيتم حذف المحادثة من جهازك فقط',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppColors.textSub)),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        side: BorderSide(color: AppColors.glassBorder),
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
        ),
      ),
    );
  }

  Future<void> _deleteChat(ChatModel chat) async {
    final ok = await _showDeleteSheet(context, chat.peer.username);
    if (ok!= true) return;

    setState(() => _removingIds.add(chat.id));
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      await _chatService.clearChat(chat.id, isRoom: false);
      if (!mounted) return;
      setState(() {
        _chats.removeWhere((c) => c.id == chat.id);
        _removingIds.remove(chat.id);
      });
      showAppSnack(context, 'تم حذف الدردشة', success: true);
    } catch (e) {
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('المحادثات', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGrad),
        child: Column(
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
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _chats.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final chat = _chats[index];
                              return _buildChatTile(chat);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersSearchButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: _openUsersSearch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.glassBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: const Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(Icons.person_search_outlined, color: AppColors.primary, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'ابحث عن أشخاص للدردشة...',
                    style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppColors.textSub.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('لا توجد محادثات', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 16)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _openUsersSearch,
            icon: const Icon(Icons.person_search_outlined, size: 18),
            label: const Text('ابحث عن أشخاص', style: TextStyle(fontFamily: 'Tajawal')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          : Dismissible(
              key: Key(chat.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                await _deleteChat(chat);
                return false;
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.white),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openChat(chat),
                  onLongPress: () => _deleteChat(chat),
                  splashColor: Colors.transparent,
                  highlightColor: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        // الصورة + نقطة أونلاين
                        UserAvatar(
                          url: chat.peer.avatarUrl,
                          name: chat.peer.username,
                          isOnline: chat.peer.isOnline,
                          size: 52,
                        ),
                        const SizedBox(width: 12),
                        // الاسم + آخر رسالة
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
                                        color: AppColors.text,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      chat.lastMessage?? 'لا توجد رسائل',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        color: chat.unreadCount > 0? AppColors.text : AppColors.textSub,
                                        fontSize: 13,
                                        fontWeight: chat.unreadCount > 0? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  // عداد أحمر فقط
                                  if (chat.unreadCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: const BoxDecoration(
                                        color: AppColors.danger,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        chat.unreadCount > 99? '99+' : chat.unreadCount.toString(),
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
