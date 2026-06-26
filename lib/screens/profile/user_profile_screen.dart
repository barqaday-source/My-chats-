import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/follow_service.dart';
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
  final _chat = ChatService();
  final _follow = FollowService();

  bool _iBlockedPeer = false;
  bool _peerBlockedMe = false;
  bool get _isBlocked => _iBlockedPeer || _peerBlockedMe;
  bool _checkingBlock = true;

  int _followers = 0;
  int _following = 0;
  bool _isFollowing = false;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    _logVisit();
    _checkBlock();
    _loadFollowStats();
  }

  Future<void> _logVisit() async {
    final meId = supabase.auth.currentUser?.id;
    if (meId == null || meId == widget.userId) return;
    try {
      await supabase.rpc('log_profile_visit', params: {'p_profile_id': widget.userId});
    } catch (_) {}
  }

  Future<void> _checkBlock() async {
    final meId = supabase.auth.currentUser?.id;
    if (meId == null || meId == widget.userId) {
      setState(() { _iBlockedPeer = false; _peerBlockedMe = false; _checkingBlock = false; });
      return;
    }
    try {
      final blocking = await supabase.from('blocked_users').select().eq('blocker_id', meId).eq('blocked_id', widget.userId).maybeSingle();
      final blockedBy = await supabase.from('blocked_users').select().eq('blocker_id', widget.userId).eq('blocked_id', meId).maybeSingle();
      if (mounted) setState(() {
        _iBlockedPeer = blocking != null;
        _peerBlockedMe = blockedBy != null;
        _checkingBlock = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingBlock = false);
    }
  }

  Future<void> _loadFollowStats() async {
    try {
      final followersRes = await supabase.from('follows').select().eq('following_id', widget.userId).count();
      final followingRes = await supabase.from('follows').select().eq('follower_id', widget.userId).count();
      final isFollowing = await _follow.isFollowing(widget.userId);
      if (mounted) setState(() {
        _followers = followersRes.count;
        _following = followingRes.count;
        _isFollowing = isFollowing;
      });
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    if (_followLoading) return;
    setState(() => _followLoading = true);
    try {
      await _follow.toggleFollow(widget.userId);
      await _loadFollowStats();
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل: $e', success: false);
    }
    if (mounted) setState(() => _followLoading = false);
  }

  Stream<UserModel?> getUserStream() {
    return supabase.from('profiles').stream(primaryKey: ['id']).eq('id', widget.userId)
      .map((list) => list.isEmpty ? null : UserModel.fromJson(list.first));
  }

  void _startChat(UserModel user) {
    if (_peerBlockedMe) {
      showAppSnack(context, 'فشل الإرسال لأنك محظور من قبل هذا المستخدم', success: false);
      return;
    }
    if (_iBlockedPeer) {
      showAppSnack(context, 'لا يمكنك المراسلة، هذا المستخدم محظور', success: false);
      return;
    }
    final meId = supabase.auth.currentUser!.id;
    final ids = [meId, user.id]..sort();
    final chatId = ids.join('_');
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PrivateChatScreen(chatId: chatId, peer: user),
    )).then((_) => _checkBlock());
  }

  Future<String?> _askReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AlertDialog(
            backgroundColor: AppColors.glassBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('سبب البلاغ', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
            content: TextField(
              controller: ctrl,
              style: const TextStyle(fontFamily: 'Tajawal'),
              decoration: const InputDecoration(hintText: 'اكتب السبب...', hintStyle: TextStyle(fontFamily: 'Tajawal')),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal'))),
              TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('إرسال', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reportUser() async {
    final reason = await _askReason();
    if (reason == null || reason.isEmpty) return;
    try {
      await _chat.reportUser(widget.userId, reason);
      if (mounted) showAppSnack(context, 'تم إرسال البلاغ للإدارة', success: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل البلاغ: $e', success: false);
    }
  }

  Future<void> _blockUser() async {
    try {
      final result = await _chat.blockUser(widget.userId);
      if (!mounted) return;
      showAppSnack(context, result == 'already_blocked' ? 'هذا المستخدم محظور بالفعل' : 'تم حظر المستخدم', success: result != 'already_blocked');
      await _checkBlock();
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل الحظر: $e', success: false);
    }
  }

  Future<void> _unblockUser() async {
    try {
      await _chat.unblockUser(widget.userId);
      if (mounted) {
        showAppSnack(context, 'تم إلغاء الحظر', success: true);
        await _checkBlock();
      }
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل إلغاء الحظر: $e', success: false);
    }
  }

  void _showUserActions(UserModel user) {
    final isMe = supabase.auth.currentUser?.id == widget.userId;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(color: AppColors.glassBg, border: Border(top: BorderSide(color: AppColors.glassBorder))),
            child: SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 8),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                if (!isMe) ...[
                  if (!_peerBlockedMe)
                    _actionTile(
                      icon: _iBlockedPeer ? Icons.lock_open_rounded : Icons.block_rounded,
                      label: _iBlockedPeer ? 'إلغاء الحظر' : 'حظر المستخدم',
                      color: _iBlockedPeer ? AppColors.primary : AppColors.danger,
                      onTap: () { Navigator.pop(context); _iBlockedPeer ? _unblockUser() : _blockUser(); },
                    ),
                  _actionTile(
                    icon: Icons.flag_rounded,
                    label: 'تبليغ للإدارة',
                    color: AppColors.warning,
                    onTap: () { Navigator.pop(context); _reportUser(); },
                  ),
                ],
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionTile({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(fontFamily: 'Tajawal', color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }

  Widget _activityBadge(UserModel user) {
    final now = DateTime.now();
    final days = now.difference(user.createdAt).inDays;
    final minutesAgo = user.lastSeen == null ? 999999 : now.difference(user.lastSeen!).inMinutes;

    String label; IconData icon; Color color;
    if (days < 7) { label = 'جديد'; icon = Icons.auto_awesome_rounded; color = AppColors.success; }
    else if (days > 365) { label = 'أسطوري'; icon = Icons.diamond_rounded; color = const Color(0xFFFFD700); }
    else if (minutesAgo < 5) { label = 'نشط جداً'; icon = Icons.flash_on_rounded; color = AppColors.online; }
    else if (minutesAgo < 60) { label = 'نشط'; icon = Icons.circle; color = AppColors.online; }
    else if (days < 90) { label = 'متوسط'; icon = Icons.trending_up_rounded; color = AppColors.primary; }
    else { label = 'قليل التواجد'; icon = Icons.schedule_rounded; color = AppColors.textSub; }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color, width: 0.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontFamily: 'Tajawal', color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.5)))),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _iconAction(IconData icon, VoidCallback onTap, {bool active = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.15) : AppColors.glassBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppColors.primary : AppColors.glassBorder),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
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
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent, elevation: 0,
            leading: IconButton(
              icon: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20)),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (user != null && !isOwnProfile)
                IconButton(
                  icon: Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                    child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20)),
                  onPressed: () => _showUserActions(user),
                ),
            ],
          ),
          body: loading ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : user == null ? const Center(child: Text('المستخدم غير موجود', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)))
            : Container(
              decoration: const BoxDecoration(gradient: AppColors.bgGrad),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // غلاف + أفاتار
                  Stack(clipBehavior: Clip.none, children: [
                    Container(height: 200, width: double.infinity,
                      decoration: BoxDecoration(gradient: LinearGradient(
                        colors: [AppColors.primary.withOpacity(0.4), AppColors.primaryDark.withOpacity(0.2)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      )),
                    ),
                    Positioned(
                      bottom: -50, left: 0, right: 0,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.bg, width: 4)),
                          child: UserAvatar(url: user.avatarUrl, name: user.username, isOnline: user.isOnline && !_isBlocked, size: 100),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 60),

                  // الاسم + الحالة
                  Center(child: Column(children: [
                    Text(user.username, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const SizedBox(height: 4),
                    Text('@${user.username}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, color: AppColors.textSub)),
                    if (user.status != null && user.status!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(user.status!, textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppColors.textSub, height: 1.4),
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ],
                    _activityBadge(user),
                    if (_isBlocked) ...[
                      const SizedBox(height: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(_peerBlockedMe ? 'تم حظرك' : 'محظور',
                          style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Tajawal'))),
                    ],
                  ])),

                  const SizedBox(height: 16),

                  // عداد المتابعين
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _countCol('$_followers', 'المتابعون'),
                    Container(width: 1, height: 28, color: AppColors.divider, margin: const EdgeInsets.symmetric(horizontal: 24)),
                    _countCol('$_following', 'يتابع'),
                  ]),

                  const SizedBox(height: 18),

                  // أزرار الإجراءات - أيقونات نعناعية فقط
                  if (!_checkingBlock && !isOwnProfile)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _iconAction(Icons.chat_bubble_outline_rounded, () => _startChat(user)),
                      const SizedBox(width: 14),
                      _iconAction(
                        _isFollowing ? Icons.person_remove_outlined : Icons.person_add_alt_1_outlined,
                        _followLoading ? () {} : _toggleFollow,
                        active: _isFollowing,
                      ),
                    ]),

                  const SizedBox(height: 24),

                  // معلومات: عمر / برج / دولة
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(color: AppColors.glassBg, borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.glassBorder, width: 0.5)),
                          child: Column(children: [
                            if (user.age != null) _infoRow(Icons.cake_rounded, 'العمر', '${user.age} سنة'),
                            if (user.zodiacResolved != null && user.zodiacResolved!.isNotEmpty)
                              _infoRow(Icons.auto_awesome_rounded, 'البرج', user.zodiacResolved!),
                            _infoRow(Icons.location_on_rounded, 'الدولة', user.country ?? 'غير محدد', isLast: true),
                          ]),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // البايو
                  if (user.bio != null && user.bio!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.glassBg, borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.glassBorder, width: 0.5)),
                            child: Text(user.bio!, textAlign: TextAlign.center,
                              style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, height: 1.5)),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
        );
      },
    );
  }

  Widget _countCol(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub)),
    ]);
  }
}
