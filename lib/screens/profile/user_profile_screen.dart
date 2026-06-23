import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
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

  bool _iBlockedPeer = false;
  bool _peerBlockedMe = false;
  bool get _isBlocked => _iBlockedPeer || _peerBlockedMe;
  bool _checkingBlock = true;

  @override
  void initState() {
    super.initState();
    _checkBlock();
  }

  Future<void> _checkBlock() async {
    final meId = supabase.auth.currentUser?.id;
    if (meId == null || meId == widget.userId) {
      setState(() { _iBlockedPeer = false; _peerBlockedMe = false; _checkingBlock = false; });
      return;
    }
    try {
      final blocking = await supabase
        .from('blocked_users')
        .select('blocker_id')
        .eq('blocker_id', meId)
        .eq('blocked_id', widget.userId)
        .maybeSingle();
      final blockedBy = await supabase
        .from('blocked_users')
        .select('blocker_id')
        .eq('blocker_id', widget.userId)
        .eq('blocked_id', meId)
        .maybeSingle();
      if (mounted) setState(() {
        _iBlockedPeer = blocking!= null;
        _peerBlockedMe = blockedBy!= null;
        _checkingBlock = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingBlock = false);
    }
  }

  Stream<UserModel?> getUserStream() {
    return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', widget.userId)
      .map((list) => list.isEmpty? null : UserModel.fromJson(list.first));
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          chatId: chatId,
          peer: user,
        ),
      ),
    ).then((_) => _checkBlock());
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

  Future<void> _reportUser(UserModel reportedUser) async {
    final reason = await _askReason();
    if (reason == null || reason.isEmpty) return;
    try {
      await _chat.reportUser(widget.userId, reason);
      if (mounted) showAppSnack(context, 'تم إرسال البلاغ للإدارة', success: true);
    } catch (e) {
      debugPrint('REPORT ERROR: $e');
      if (mounted) showAppSnack(context, 'فشل البلاغ: $e', success: false);
    }
  }

  Future<void> _blockUser() async {
    try {
      final result = await _chat.blockUser(widget.userId);
      if (!mounted) return;
      if (result == 'already_blocked') {
        showAppSnack(context, 'هذا المستخدم محظور بالفعل', success: false);
      } else {
        showAppSnack(context, 'تم حظر المستخدم', success: true);
      }
      await _checkBlock();
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل الحظر: $e', success: false);
    }
  }

  Future<void> _unblockUser() async {
    if (!_iBlockedPeer) {
      showAppSnack(context, 'فشل الإرسال لأنك محظور من قبل هذا المستخدم', success: false);
      return;
    }
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

  Future<void> _openWhatsapp(String number) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showUserActions(UserModel user) {
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
              leading: Icon(
                _iBlockedPeer? Icons.lock_open_rounded : Icons.message_rounded,
                color: _iBlockedPeer? AppColors.warning : AppColors.primary,
              ),
              title: Text(
                _peerBlockedMe? 'محظور' : _iBlockedPeer? 'إلغاء الحظر والمراسلة' : 'مراسلة خاصة',
                style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
              onTap: () {
                Navigator.pop(context);
                if (_peerBlockedMe) {
                  showAppSnack(context, 'فشل الإرسال لأنك محظور من قبل هذا المستخدم', success: false);
                  return;
                }
                if (_iBlockedPeer) {
                  _unblockUser();
                } else {
                  _startChat(user);
                }
              },
            ),
            if (!_peerBlockedMe)
            ListTile(
              leading: Icon(
                _iBlockedPeer? Icons.lock_open_rounded : Icons.block_rounded,
                color: _iBlockedPeer? AppColors.primary : AppColors.danger,
              ),
              title: Text(
                _iBlockedPeer? 'إلغاء الحظر' : 'حظر المستخدم',
                style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
              onTap: () {
                Navigator.pop(context);
                _iBlockedPeer? _unblockUser() : _blockUser();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: AppColors.warning),
              title: const Text('تبليغ للإدارة',
                  style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
              onTap: () { Navigator.pop(context); _reportUser(user); },
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
              user?.username?? 'الملف الشخصي',
              style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
            ),
            actions: [
              if (user!= null &&!isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.white),
                  onPressed: () => _showUserActions(user),
                ),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(gradient: AppColors.bgGrad),
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
          isOnline: user.isOnline &&!_isBlocked,
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
        if (bio!= null && bio.isNotEmpty)
          Text(
            bio,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.textSub,
              fontSize: 14,
            ),
          ),
        if (_isBlocked)...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _peerBlockedMe? 'تم حظرك' : 'محظور',
              style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.danger, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(UserModel user) {
    final meId = supabase.auth.currentUser!.id;
    if (meId == user.id) return const SizedBox.shrink();
    if (_checkingBlock) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_peerBlockedMe) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => showAppSnack(context, 'فشل الإرسال لأنك محظور من قبل هذا المستخدم', success: false),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.bgCard,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.block_rounded, color: AppColors.textSub),
          label: const Text(
            'محظور',
            style: TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.textSub,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      );
    }
    if (_iBlockedPeer) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _unblockUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
          label: const Text(
            'إلغاء الحظر',
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
    final age = user.age;
    final zodiac = user.zodiacResolved;
    final whatsapp = user.whatsapp;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          if (age!= null)...[
            _buildInfoRow(Icons.cake_rounded, 'العمر', '$age سنة'),
            const Divider(color: AppColors.glassBorder),
          ],
          if (zodiac!= null && zodiac.isNotEmpty)...[
            _buildInfoRow(Icons.auto_awesome_rounded, 'البرج', zodiac),
            const Divider(color: AppColors.glassBorder),
          ],
          if (whatsapp!= null && whatsapp.isNotEmpty &&!_isBlocked)...[
            InkWell(
              onTap: () => _openWhatsapp(whatsapp),
              child: _buildInfoRow(Icons.phone_rounded, 'واتساب', whatsapp, isLink: true),
            ),
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

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isLink = false}) {
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
            style: TextStyle(
              fontFamily: 'Tajawal',
              color: isLink? AppColors.primary : AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: isLink? TextDecoration.underline : null,
            ),
          ),
        ],
      ),
    );
  }
}
