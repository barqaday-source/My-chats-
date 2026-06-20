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

  Stream<UserModel?> getUserStream() {
    return supabase
        .from(SupabaseConfig.tUsers)
        .stream(primaryKey: ['id'])
        .eq('id', widget.userId)
        .map((list) => list.isEmpty ? null : UserModel.fromJson(list.first));
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

  // === البلاغ - مطابق لجدول reports الفعلي ===
  Future<void> _reportUser(UserModel reportedUser) async {
    final reason = await _askReason();
    if (reason == null || reason.isEmpty) return;
    try {
      final auth = context.read<AuthProvider>();
      final meId = supabase.auth.currentUser!.id;
      final myName = auth.userProfile?['username'] as String? ?? 'مستخدم';

      await supabase.from(SupabaseConfig.tReports).insert({
        'reporter_id': meId,
        'reporter_name': myName,
        'reported_id': widget.userId,
        'user_id': widget.userId,
        'reason': reason,
        'status': 'pending',
      });
      if (mounted) showAppSnack(context, 'تم إرسال البلاغ للإدارة', success: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل البلاغ', success: false);
    }
  }

  // === الحظر - ما لمسته ===
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
              onTap: () { Navigator.pop(context); _reportUser(user); },
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
    final bio = user.bio?.trim();
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
        const SizedBox(height: 8),
        if (bio != null && bio.isNotEmpty)
          Text(
            bio,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.textSub,
              fontSize: 14,
            ),
          )
        else
          const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActions(UserModel user) {
    final meId = supabase.auth.currentUser!.id;
    if (meId == user.id) return const SizedBox.shrink();
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _startChat(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.message_rounded, color: Colors.white),
        label: const Text(
          'مراسلة',
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(UserModel user) {
    // استخدم الـ getters من UserModel مباشرة
    final age = user.age;
    final zodiac = user.zodiacResolved;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          if (age != null)
            _buildInfoRow(Icons.cake_rounded, 'العمر', '$age سنة'),
          if (age != null && zodiac != null)
            const Divider(color: AppColors.glassBorder),
          if (zodiac != null)
            _buildInfoRow(Icons.auto_awesome_rounded, 'البرج', zodiac),
          if (zodiac != null)
            const Divider(color: AppColors.glassBorder),
          if (user.whatsapp != null && user.whatsapp!.isNotEmpty) ...[
            _buildInfoRow(Icons.phone_rounded, 'واتساب', user.whatsapp!),
            const Divider(color: AppColors.glassBorder),
          ],
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
