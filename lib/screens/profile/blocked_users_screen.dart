import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_snackbar.dart';
import '../../services/chat_service.dart';
import 'user_profile_screen.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});
  @override State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final supabase = Supabase.instance.client;
  final _chat = ChatService();

  Future<List<Map<String, dynamic>>> _load() async {
    final me = supabase.auth.currentUser!.id;
    final res = await supabase
     .from('blocked_users')
     .select('blocked_id, profiles!blocked_users_blocked_id_fkey(id, username, avatar_url, status)')
     .eq('blocker_id', me)
     .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> _unblock(String userId) async {
    try {
      await _chat.unblockUser(userId);
      if (mounted) {
        showAppSnack(context, 'تم إلغاء الحظر', success: true);
        setState(() {});
      }
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل: $e', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('المحظورون', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGrad),
        child: FutureBuilder(
          future: _load(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return const Center(
                child: Text('لا يوجد مستخدمون محظورون', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final u = items[i]['profiles'] as Map<String, dynamic>;
                final userId = u['id'] as String;
                final name = u['username']?? 'مستخدم';
                final status = u['status'] as String?;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => UserProfileScreen(userId: userId)
                        )),
                        child: UserAvatar(url: u['avatar_url'], name: name, size: 52),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, color: AppColors.text)),
                            if (status!= null && status.isNotEmpty)
                              Text(status, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub)),
                          ],
                        ),
                      ),
                      // أيقونة إلغاء حظر نعناعية مفرغة فقط
                      IconButton(
                        icon: const Icon(Icons.lock_open_rounded),
                        color: AppColors.primary,
                        tooltip: 'إلغاء الحظر',
                        onPressed: () => _unblock(userId),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
