import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import 'edit_profile_screen.dart';

/// الشاشات الجاية - placeholders لحد ما نبنيها
class WalletScreen extends StatelessWidget { const WalletScreen({super.key}); @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('محفظتي', style: TextStyle(fontFamily: 'Tajawal'))), body: const Center(child: Text('رصيدك هنا', style: TextStyle(fontFamily: 'Tajawal')))); }
class TopUpScreen extends StatelessWidget { const TopUpScreen({super.key}); @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('اشحن رصيدك', style: TextStyle(fontFamily: 'Tajawal'))), body: const Center(child: Text('شحن عبر الوكيل - واتساب', style: TextStyle(fontFamily: 'Tajawal')))); }
class OffersScreen extends StatelessWidget { const OffersScreen({super.key}); @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('العروض المميزة', style: TextStyle(fontFamily: 'Tajawal'))), body: const Center(child: Text('ثيمات / بوست', style: TextStyle(fontFamily: 'Tajawal')))); }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  int _visits = 0;
  int _chats = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final me = supabase.auth.currentUser?.id;
    if (me == null) return;
    try {
      final visits = await supabase.from('profile_visits').select().eq('profile_id', me).count();
      final chats = await supabase.from('private_messages').select().or('sender_id.eq.$me,receiver_id.eq.$me').count();
      if (mounted) setState(() {
        _visits = visits.count;
        _chats = chats.count;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGrad),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // الهيدر - أفاتار + اسم + حالة
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                      child: UserAvatar(
                        url: user.avatarUrl,
                        name: user.username,
                        size: 88,
                        showBorder: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.username,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email ?? '@${user.username}',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppColors.textSub),
                    ),
                    if (user.status != null && user.status!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        user.status!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppColors.textSub),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3 مربعات: محفظتي / اشحن / عروض
              Row(
                children: [
                  _statCard('محفظتي', '${user.coins ?? 0} 🪙', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
                  }),
                  const SizedBox(width: 12),
                  _statCard('اشحن', 'رصيد', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpScreen()));
                  }),
                  const SizedBox(width: 12),
                  _statCard('عروض', 'مميز', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OffersScreen()));
                  }),
                ],
              ),
              const SizedBox(height: 20),

              // قائمة الإعدادات
              _menuTile(Icons.person_outline_rounded, 'تعديل الملف الشخصي', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _loadStats());
              }),
              _menuTile(Icons.visibility_outlined, 'زوار ملفي', () {}, badge: _visits > 0 ? '$_visits' : null),
              _menuTile(Icons.block_rounded, 'المحظورون', () {}),
              _menuTile(Icons.settings_outlined, 'الإعدادات', () {}),
              _menuTile(Icons.logout_rounded, 'تسجيل الخروج', () async {
                await supabase.auth.signOut();
              }, danger: true),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.glassBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: Column(
                children: [
                  Text(value, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuTile(IconData icon, String label, VoidCallback onTap, {bool danger = false, String? badge}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: AppColors.glassBg,
            child: ListTile(
              leading: Icon(icon, color: danger ? AppColors.danger : AppColors.primary),
              title: Text(label, style: TextStyle(fontFamily: 'Tajawal', color: danger ? AppColors.danger : AppColors.text, fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                      child: Text(badge, style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_left_rounded, color: AppColors.textSub),
                ],
              ),
              onTap: onTap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppColors.glassBorder, width: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
