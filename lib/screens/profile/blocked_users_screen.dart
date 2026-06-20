import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_config.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_snackbar.dart';
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
      final meId = _supabase.auth.currentUser!.id;

      final blockRes = await _supabase
      .from(SupabaseConfig.tBlockedUsers)
      .select('blocked_id')
      .eq('blocker_id', meId);

      final blockedIds = (blockRes as List)
      .map((e) => e['blocked_id'] as String)
      .toList();

      if (blockedIds.isEmpty) {
        if (mounted) setState(() {
          _blockedUsers = [];
          _loading = false;
        });
        return;
      }

      final usersRes = await _supabase
      .from(SupabaseConfig.tUsers)
      .select()
      .inFilter('id', blockedIds);

      if (mounted) {
        setState(() {
          _blockedUsers = (usersRes as List).map((e) => UserModel.fromJson(e)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAppSnack(context, 'فشل تحميل المحظورين', success: false);
      }
    }
  }

  Future<void> _unblockUser(String userId) async {
    try {
      await _supabase
       .from(SupabaseConfig.tBlockedUsers)
       .delete()
       .eq('blocker_id', _supabase.auth.currentUser!.id)
       .eq('blocked_id', userId);

      setState(() {
        _blockedUsers.removeWhere((u) => u.id == userId);
      });

      if (mounted) showAppSnack(context, 'تم إلغاء الحظر', success: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل إلغاء الحظر', success: false);
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
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadBlockedUsers,
            child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _blockedUsers.isEmpty
              ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text('لا يوجد مستخدمين محظورين',
                          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub))
                      )
                    ],
                  )
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
      ),
    );
  }
}
