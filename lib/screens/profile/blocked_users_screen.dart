import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import 'user_profile_screen.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _supabase = Supabase.instance.client;
  List<UserModel> _blockedUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _loading = true);
    try {
      final me = context.read<AuthProvider>().user!;

      final blockRes = await _supabase
         .from('blocks')
         .select('blocked_id')
         .eq('blocker_id', me.id);

      final blockedIds = (blockRes as List)
         .map((e) => e['blocked_id'] as String)
         .toList();

      if (blockedIds.isEmpty) {
        setState(() {
          _blockedUsers = [];
          _loading = false;
        });
        return;
      }

      final usersRes = await _supabase
         .from('users')
         .select()
         .inFilter('id', blockedIds);

      _blockedUsers =
          (usersRes as List).map((e) => UserModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Load blocked users error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تحميل المحظورين', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _unblockUser(String userId) async {
    final me = context.read<AuthProvider>().user!;
    try {
      await _supabase
         .from('blocks')
         .delete()
         .eq('blocker_id', me.id)
         .eq('blocked_id', userId);

      setState(() {
        _blockedUsers.removeWhere((u) => u.id == userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الحظر', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل إلغاء الحظر', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('المحظورين',
            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGrad),
        child: SafeArea(
          child: _loading
             ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _blockedUsers.isEmpty
                 ? const Center(
                      child: Text('لا يوجد مستخدمين محظورين',
                          style: TextStyle(
                              fontFamily: 'Tajawal', color: AppColors.textSub)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _blockedUsers.length,
                      itemBuilder: (_, i) {
                        final user = _blockedUsers[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.glassBorder, width: 0.8),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserProfileScreen(userId: user.id),
                                ),
                              ),
                              child: UserAvatar(
                                url: user.avatarUrl,
                                name: user.username,
                                size: 44,
                                isOnline: user.isOnline,
                              ),
                            ),
                            title: Text(user.username,
                                style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              user.bio?? 'لا توجد نبذة',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: AppColors.textSub,
                                  fontSize: 12),
                            ),
                            trailing: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.danger.withOpacity(0.15),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _unblockUser(user.id),
                              child: const Text('إلغاء الحظر',
                                  style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      color: AppColors.danger,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
