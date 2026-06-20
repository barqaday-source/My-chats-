import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_config.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_snackbar.dart';
import '../chat/private_chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final supabase = Supabase.instance.client;
  bool _isFollowing = false;
  bool _followChecked = false;

  Stream<UserModel?> getUserStream() {
    return supabase
        .from(SupabaseConfig.tUsers)
        .stream(primaryKey: ['id'])
        .eq('id', widget.userId)
        .map((list) => list.isEmpty ? null : UserModel.fromJson(list.first));
  }

  Future<void> _checkFollowStatus() async {
    if (_followChecked) return;
    try {
      final me = context.read<AuthProvider>().user;
      if (me == null) return;
      final follow = await supabase
          .from('follows')
          .select()
          .eq('follower_id', me.id)
          .eq('following_id', widget.userId)
          .maybeSingle();
      if (mounted) setState(() {
        _isFollowing = follow != null;
        _followChecked = true;
      });
    } catch (_) {
      _followChecked = true;
    }
  }

  Future<void> _toggleFollow(String targetUserId) async {
    final meId = supabase.auth.currentUser!.id;
    final newState = !_isFollowing;
    setState(() => _isFollowing = newState);
    try {
      if (newState) {
        await supabase.from('follows').insert({
          'follower_id': meId,
          'following_id': targetUserId,
        });
      } else {
        await supabase.from('follows').delete()
          .eq('follower_id', meId)
          .eq('following_id', targetUserId);
      }
    } catch (e) {
      setState(() => _isFollowing = !newState);
      if (mounted) showAppSnack(context, 'فشل العملية', success: false);
    }
  }

  void _startChat(UserModel user) {
    final meId = supabase.auth.currentUser!.id;
    final ids = [meId, user.id]..sort();
    final chatId = ids.join('_');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          chatId: chatId,
          peer: user,
        ),
      ),
    );
  }

  Future<String?> _askReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('سبب البلاغ',
            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
          decoration: const InputDecoration(
            hintText: 'اكتب السبب...',
            hintStyle: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('إرسال',
                  style: TextStyle(fontFamily: 'Tajawal', color: AppColors.primary))),
        ],
      ),
    );
  }

  Future<void> _reportUser() async {
    final reason = await _askReason();
    if (reason == null || reason.isEmpty) return;
    try {
      final meId = supabase.auth.currentUser!.id;
      await supabase.from(SupabaseConfig.tReports).insert({
        'reporter_id': meId,
        'reported_id': widget.userId,
        'reason': reason,
      });
      if (mounted) showAppSnack(context, 'تم إرسال البلاغ للإدارة', success: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل البلاغ', success: false);
    }
  }

  Future<void> _blockUser() async {
    try {
      final meId = supabase.auth.currentUser!.id;
      await supabase.from(SupabaseConfig.tBlockedUsers).insert({
        'blocker_id': meId,
        'blocked_id': widget.userId,
      });
      if (mounted) showAppSnack(context, 'تم حظر المستخدم', success: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل الحظر', success: false);
    }
  }

  Future<void> _banEmail() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('حظر نهائي',
            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
        content: const Text('هل أنت متأكد من حظر هذا الحساب نهائيا؟',
            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حظر', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await supabase.from(SupabaseConfig.tUsers).update({
        'is_blocked': true,
        'blocked_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.userId);
      if (mounted) showAppSnack(context, 'تم الحظر النهائي', success: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل الحظر', success: false);
    }
  }

  void _showUserActions(UserModel user) {
    final auth = context.read<AuthProvider>();
    final isAdmin = auth.userProfile?['role'] == 'admin';
    final isMe = supabase.auth.currentUser?.id == widget.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!isMe)...[
            ListTile(
              leading: const Icon(Icons.message_rounded, color: AppColors.primary),
              title: const Text('مراسلة خاصة',
                  style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
              onTap: () { Navigator.pop(context); _startChat(user); },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: AppColors.danger),
              title: const Text('حظر المستخدم',
                  style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
              onTap: () { Navigator.pop(context); _blockUser(); },
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: AppColors.warning),
              title: const Text('تبليغ للإدارة',
                  style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
              onTap: () { Navigator.pop(context); _reportUser(); },
            ),
          ],
          if (isAdmin && !isMe)...[
            const Divider(color: AppColors.glassBorder, height: 1),
            ListTile(
              leading: const Icon(Icons.gpp_bad_rounded, color: AppColors.danger),
              title: const Text('حظر نهائي',
                  style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger)),
              onTap: () { Navigator.pop(context); _banEmail(); },
            ),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meId = supabase.auth.currentUser?.id;
    final isOwnProfile = meId == widget.userId;

    if (!_followChecked && !isOwnProfile) {
      _checkFollowStatus();
    }

    return StreamBuilder<UserModel?>(
      stream: getUserStream(),
      builder: (context, snap) {
        final user = snap.data;
        final loading = snap.connectionState == ConnectionState.waiting;

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bgCard,
            title: Text(
              user?.username ?? 'الملف الشخصي',
              style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
            ),
            actions: [
              if (user != null && !isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.white),
                  onPressed: () => _showUserActions(user),
                ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(gradient: AppColors.bgGrad),
            child: loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : user == null
                ? const Center(
                      child: Text(
                        'المستخدم غير موجود',
                        style: TextStyle(
                            fontFamily: 'Tajawal', color: AppColors.textSub),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildHeader(user),
                        const SizedBox(height: 24),
                        _buildStats(user),
                        const SizedBox(height: 24),
                        _buildActions(user),
                        const SizedBox(height: 24),
                        _buildInfo(user),
                      ],
                    ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(UserModel user) {
    return Column(
      children: [
        UserAvatar(
          url: user.avatarUrl,
          name: user.username,
          isOnline: user.isOnline,
          size: 90,
        ),
        const SizedBox(height: 12),
        Text(
          user.username,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.bio ?? 'لا يوجد نبذة',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.textSub,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStats(UserModel user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('المتابعون', user.followersCount.toString()),
        _buildStatItem('يتابع', user.followingCount.toString()),
        _buildStatItem('المنشورات', user.postsCount.toString()),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.textSub,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(UserModel user) {
    final meId = supabase.auth.currentUser!.id;
    if (meId == user.id) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _toggleFollow(user.id),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isFollowing ? AppColors.bgCard : AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
            icon: Icon(
              _isFollowing
                ? Icons.person_remove_rounded
                  : Icons.person_add_rounded,
              color: _isFollowing ? AppColors.primary : Colors.white,
            ),
            label: Text(
              _isFollowing ? 'إلغاء المتابعة' : 'متابعة',
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: _isFollowing ? AppColors.primary : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () => _startChat(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.bgCard,
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.glassBorder),
            ),
          ),
          child: const Icon(Icons.message_rounded, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildInfo(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.email_rounded, 'البريد', user.email ?? 'مخفي'),
          const Divider(color: AppColors.glassBorder),
          _buildInfoRow(
              Icons.calendar_today_rounded,
              'تاريخ الانضمام',
              '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.textSub,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
