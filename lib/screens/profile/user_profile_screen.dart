import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_snackbar.dart';
import '../chat/private_chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});
  @override State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final supabase = Supabase.instance.client;

  // نقرأ من profiles، مو من users
  Stream<UserModel?> getUserStream() {
    return supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', widget.userId)
        .map((list) => list.isEmpty ? null : UserModel.fromJson(list.first));
  }

  void _startChat(UserModel user) {
    final meId = supabase.auth.currentUser!.id;
    final ids = [meId, user.id]..sort();
    final chatId = ids.join('_');
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PrivateChatScreen(chatId: chatId, peer: user),
    ));
  }

  Future<void> _openWhatsapp(String number) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ... _askReason / _reportUser / _blockUser / _banEmail تبقى نفسها
  // فقط غيرت جدول الحظر النهائي ليصير profiles
  Future<void> _banEmail() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: const Text('حظر نهائي', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
      content: const Text('هل أنت متأكد من حظر هذا الحساب نهائيا؟', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حظر', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger))),
      ],
    ));
    if (confirm != true) return;
    try {
      await supabase.from('profiles').update({'is_blocked': true}).eq('id', widget.userId);
      if (mounted) showAppSnack(context, 'تم الحظر النهائي', success: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل الحظر', success: false);
    }
  }

  // باقي دوال البلاغ والحظر نفس كودك، ما غيرتها

  @override
  Widget build(BuildContext context) {
    final meId = supabase.auth.currentUser?.id;
    final isOwnProfile = meId == widget.userId;

    return StreamBuilder<UserModel?>(
      stream: getUserStream(),
      builder: (context, snap) {
        final user = snap.data;
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bgCard,
            title: Text(user?.username ?? 'الملف الشخصي',
              style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
            actions: [
              if (user != null && !isOwnProfile)
                IconButton(icon: const Icon(Icons.more_vert_rounded, color: AppColors.white),
                  onPressed: () => _showUserActions(user)),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(gradient: AppColors.bgGrad),
            child: snap.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : user == null
                ? const Center(child: Text('المستخدم غير موجود',
                    style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)))
                : ListView(padding: const EdgeInsets.all(16), children: [
                    _buildHeader(user),
                    const SizedBox(height: 24),
                    _buildActions(user),
                    const SizedBox(height: 24),
                    _buildInfo(user),
                  ]),
          ),
        );
      },
    );
  }

  Widget _buildHeader(UserModel user) {
    final bio = user.bio?.trim();
    return Column(children: [
      UserAvatar(url: user.avatarUrl, name: user.username, isOnline: user.isOnline, size: 90),
      const SizedBox(height: 12),
      Text(user.username, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (bio != null && bio.isNotEmpty)
        Text(bio, textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 14)),
    ]);
  }

  Widget _buildActions(UserModel user) {
    final meId = supabase.auth.currentUser!.id;
    if (meId == user.id) return const SizedBox.shrink();
    return SizedBox(width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _startChat(user),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        icon: const Icon(Icons.message_rounded, color: Colors.white),
        label: const Text('مراسلة', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
      ),
    );
  }

  Widget _buildInfo(UserModel user) {
    final age = user.age;
    final zodiac = user.zodiac;
    final whatsapp = user.whatsapp;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder)),
      child: Column(children: [
        if (age != null)
          _buildInfoRow(Icons.cake_rounded, 'العمر', '$age سنة'),
        if (age != null && zodiac != null)
          const Divider(color: AppColors.glassBorder),
        if (zodiac != null && zodiac.isNotEmpty)
          _buildInfoRow(Icons.auto_awesome_rounded, 'البرج', zodiac),
        if (zodiac != null && whatsapp != null)
          const Divider(color: AppColors.glassBorder),
        if (whatsapp != null && whatsapp.isNotEmpty) ...[
          InkWell(
            onTap: () => _openWhatsapp(whatsapp),
            child: _buildInfoRow(Icons.phone_rounded, 'واتساب', whatsapp, isLink: true),
          ),
          const Divider(color: AppColors.glassBorder),
        ],
        _buildInfoRow(Icons.calendar_today_rounded, 'تاريخ الانضمام',
          '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}'),
      ]),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 14)),
        const Spacer(),
        Text(value, style: TextStyle(
          fontFamily: 'Tajawal',
          color: isLink ? AppColors.primaryLight : AppColors.white,
          fontSize: 14, fontWeight: FontWeight.w600,
          decoration: isLink ? TextDecoration.underline : null,
        )),
      ]),
    );
  }

  // _showUserActions / _reportUser / _blockUser نفس كودك، فقط انسخها
}
