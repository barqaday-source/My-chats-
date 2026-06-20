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

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final _chatService = ChatService();
  final _searchController = TextEditingController();
  List<ChatModel> _chats = [];
  List<ChatModel> _filteredChats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() => _loading = true);
    try {
      final user = context.read<AuthProvider>().user!;
      final chats = await _chatService.getUserChats(user.id);
      if (!mounted) return;
      setState(() {
        _chats = chats.map((c) => ChatModel.fromJson(c)).toList();
        _filteredChats = _chats;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAppSnack(context, 'فشل تحميل المحادثات', success: false);
      }
    }
  }

  void _filterChats(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredChats = _chats;
      } else {
        _filteredChats = _chats
          .where((chat) => chat.peer.username.toLowerCase().contains(query.toLowerCase()))
          .toList();
      }
    });
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
          _buildSearchBar(),
          Expanded(
            child: _loading
         ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredChats.isEmpty
            ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadChats,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _filteredChats.length,
                          itemBuilder: (context, index) {
                            final chat = _filteredChats[index];
                            return _buildChatTile(chat);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
        decoration: const InputDecoration(
          icon: Icon(Icons.search_rounded, color: AppColors.textSub),
          hintText: 'ابحث عن محادثة...',
          hintStyle: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
          border: InputBorder.none,
        ),
        onChanged: _filterChats,
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
        ],
      ),
    );
  }

  Widget _buildChatTile(ChatModel chat) {
    return InkWell(
      onTap: () => _openChat(chat),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
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
