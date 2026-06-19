import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../widgets/user_avatar.dart';
import '../chat/private_chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final supabase = Supabase.instance.client;
  final _chat = ChatService();
  UserModel? _user;
  bool _loading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
        .from('profiles')
        .select()
        .eq('id', widget.userId)
        .maybeSingle();

      if (data == null && mounted) {
        setState(() => _loading = false);
        return;
      }

      if (mounted) {
        setState(() {
          _user = UserModel.fromJson(data!);
          _loading = false;
        });
      }

      try {
        final me = context.read<AuthProvider>().user!;
        final follow = await supabase
          .from('follows')
          .select()
          .eq('follower_id', me.id)
          .eq('following_id', widget.userId)
          .maybeSingle();
        if (mounted) setState(() => _isFollowing = follow!= null);
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل الملف: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_user == null) return;
    final meId = supabase.auth.currentUser!.id;
    final newState =!_isFollowing;
    setState(() => _isFollowing = newState);
    try {
      if (newState) {
        await supabase.from('follows').insert({
          'follower_id': meId,
          'following_id': _user!.id,
        });
      } else {
        await supabase.from('follows').delete()
        .eq('follower_id', meId)
        .eq('following_id', _user!.id);
      }
    } catch (e) {
      setState(() => _isFollowing =!newState);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _startChat() {
    if (_user == null) return;
    final meId = supabase.auth.currentUser!.id;
    final ids = [meId, _user!.id]..sort();
    final chatId = ids.join('_');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          chatId: chatId,
          peer: _user!,
        ),
      ),
    );
  }

  // ====== إجراءات المستخدم / الإدارة ======
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
      await _chat.reportUser(widget.userId, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم إرسال البلاغ للإدارة',
                style: TextStyle(fontFamily: 'Tajawal'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('فشل البلاغ: $e',
                style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _blockUser() async {
    try {
      final meId = supabase.auth.currentUser!.id;
      await supabase.from('blocked_users').insert({
        'blocker_id': meId,
        'blocked_id': widget.userId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم حظر المستخدم',
                style: TextStyle(fontFamily: 'Tajawal'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('فشل الحظر: $e',
                style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _changeRole(String role) async {
    try {
      await supabase.from('profiles').update({'role': role}).eq('id', widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(role == 'admin'? 'تم ترقية المستخدم لمدير' : 'تم إزالة الإدارة',
                style: const TextStyle(fontFamily: 'Tajawal'))));
      }
      _loadUser();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('فشل تغيير الصلاحية: $e',
                style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _banEmail() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('حظر نهائي',
            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
        content: const Text('هل أنت متأكد من حظر هذا الحساب نهائيا بالإيميل؟',
            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حظر', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger))),
        ],
      ),
    );
    if (confirm!= true) return;
    try {
      await supabase.from('profiles').update({
        'is_blocked': true,
        'blocked_at': DateTime.now().toIso8601String(),
        'role': 'user'
      }).eq('id', widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم الحظر النهائي',
                style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger));
      }
      _loadUser();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('فشل الحظر: $e',
                style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger));
      }
    }
  }

  void _showUserActions() {
    final auth = context.read<AuthProvider>();
    final isAdmin = auth.user?.role == 'admin';
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
              onTap: () { Navigator.pop(context); _startChat(); },
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
          if (isAdmin &&!isMe)...[
            const Divider(color: AppColors.glassBorder, height: 1),
            ListTile(
              leading: const Icon(Icons.verified_user_rounded, color: AppColors.primary),
              title: const Text('ترقية لمدير',
                  style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
              onTap: () { Navigator.pop(context); _changeRole('admin'); },
            ),
            ListTile(
              leading: const Icon(Icons.person_off_rounded, color: AppColors.textSub),
              title: const Text('إزالة الإدارة',
                  style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
              onTap: () { Navigator.pop(context); _changeRole('user'); },
            ),
            ListTile(
              leading: const Icon(Icons.gpp_bad_rounded, color: AppColors.danger),
              title: const Text('حظر نهائي بالإيميل',
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title: Text(
          _user?.username?? 'الملف الشخصي',
          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
        ),
        actions: [
          if (_user!= null &&!isOwnProfile)
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.white),
              onPressed: _showUserActions,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGrad),
        child: _loading
          ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _user == null
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
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildStats(),
                      const SizedBox(height: 24),
                      _buildActions(),
                      const SizedBox(height: 24),
                      _buildInfo(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        UserAvatar(
          url: _user!.avatarUrl,
          name: _user!.username,
          isOnline: _user!.isOnline,
          size: 90,
        ),
        const SizedBox(height: 12),
        Text(
          _user!.username,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _user!.bio?? 'لا يوجد نبذة',
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

  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('المتابعون', _user!.followersCount.toString()),
        _buildStatItem('يتابع', _user!.followingCount.toString()),
        _buildStatItem('المنشورات', _user!.postsCount.toString()),
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

  Widget _buildActions() {
    final meId = supabase.auth.currentUser!.id;
    if (meId == _user!.id) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _toggleFollow,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isFollowing? AppColors.bgCard : AppColors.primary,
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
              color: _isFollowing? AppColors.primary : Colors.white,
            ),
            label: Text(
              _isFollowing? 'إلغاء المتابعة' : 'متابعة',
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: _isFollowing? AppColors.primary : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _startChat,
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

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.email_rounded, 'البريد', _user!.email?? 'مخفي'),
          const Divider(color: AppColors.glassBorder),
          _buildInfoRow(
              Icons.calendar_today_rounded,
              'تاريخ الانضمام',
              '${_user!.createdAt.day}/${_user!.createdAt.month}/${_user!.createdAt.year}'),
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
