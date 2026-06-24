import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart'; // NEW: للثيم
import '../screens/pages/privacy_screen.dart';
import '../screens/pages/contact_screen.dart';
import '../screens/admin/admin_panel_screen.dart';
import '../screens/profile/blocked_users_screen.dart';
import '../screens/profile/profile_screen.dart'; // NEW: لوحتي
import '../services/chat_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/app_snackbar.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});
  @override State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _chat = ChatService();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _blocked = [];
  bool _blockedOpen = false;
  bool _blockedLoading = false;

  Future<void> _loadBlocked() async {
    if (_blockedLoading) return;
    setState(() => _blockedLoading = true);
    try {
      final meId = _supabase.auth.currentUser!.id;
      final res = await _supabase.from('blocked_users')
        .select('blocked_id, profiles!blocked_users_blocked_id_fkey(id, username, avatar_url)')
        .eq('blocker_id', meId);
      if (mounted) setState(() => _blocked = List<Map<String, dynamic>>.from(res));
    } catch (_) {}
    if (mounted) setState(() => _blockedLoading = false);
  }

  Future<void> _unblock(String peerId) async {
    try {
      await _chat.unblockUser(peerId);
      setState(() => _blocked.removeWhere((b) => b['blocked_id'] == peerId));
      if (mounted) showAppSnack(context, 'تم إلغاء الحظر', success: true);
    } catch (_) {
      if (mounted) showAppSnack(context, 'فشل إلغاء الحظر', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProv = context.watch<ThemeProvider>(); // NEW
    final profile = auth.userProfile;
    final role = profile?['role'] as String?;
    final isAdmin = role == 'admin';

    return Drawer(
      backgroundColor: Colors.transparent, // شفاف عشان الزجاجي يبين
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // زجاجي 2026
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassBg, // زجاجي من app_colors
              border: Border(
                left: BorderSide(color: AppColors.glassBorder, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Column(children: [
                const SizedBox(height: 20),
                // الهيدر: صورة + اسم
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    UserAvatar(
                      url: profile?['avatar_url'], 
                      name: profile?['username'] ?? 'زائر',
                      size: 56, 
                      isOnline: profile?['is_online'] ?? false, 
                      showBorder: true
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(profile?['username'] ?? 'زائر', 
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Tajawal')),
                      Text(auth.currentUser?.email ?? '', 
                        style: const TextStyle(color: AppColors.textSub, fontSize: 12, fontFamily: 'Tajawal'), 
                        overflow: TextOverflow.ellipsis),
                      if (isAdmin) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1), 
                            borderRadius: BorderRadius.circular(20)
                          ),
                          child: const Text('👑 مدير', 
                            style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Tajawal'))),
                      ],
                    ])),
                  ]),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
                  child: Divider(height: 1, color: AppColors.divider)
                ),
                
                // 1. سياسات
                _tile(
                  Icons.policy_outlined, 
                  'سياسات الاستخدام',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                ),
                
                // 2. تواصل
                _tile(
                  Icons.support_agent_rounded, 
                  'تواصل معنا',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactScreen())),
                ),
                
                // 3. الثيم ليلي/نهاري
                _tile(
                  themeProv.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, 
                  themeProv.isDark ? 'الوضع النهاري' : 'الوضع الليلي',
                  () => themeProv.toggleTheme(),
                ),
                
                // 4. لوحتي
                _tile(
                  Icons.dashboard_rounded, 
                  'لوحتي',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                ),
                
                // 5. المحظورين - ExpansionTile بس بدون كرت
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                    childrenPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.block_rounded, color: AppColors.textSub, size: 22),
                    title: const Text('المحظورين', 
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, fontFamily: 'Tajawal')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_blockedOpen && _blocked.isNotEmpty)
                          Text('${_blocked.length}', 
                            style: const TextStyle(color: AppColors.textSub, fontSize: 12, fontFamily: 'Tajawal')),
                        const SizedBox(width: 8),
                        Icon(_blockedOpen ? Icons.expand_less : Icons.chevron_left_rounded, 
                          color: AppColors.textSub, size: 22),
                      ],
                    ),
                    onExpansionChanged: (v) { 
                      setState(() => _blockedOpen = v); 
                      if (v) _loadBlocked(); 
                    },
                    children: [
                      if (_blockedLoading)
                        const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2))
                      else if (_blocked.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Text('لا يوجد محظورين', 
                            style: TextStyle(color: AppColors.textSub, fontSize: 12, fontFamily: 'Tajawal'))
                        )
                      else ..._blocked.map((b) {
                        final p = b['profiles'] as Map<String, dynamic>?;
                        final peerId = b['blocked_id'] as String;
                        final name = p?['username'] ?? 'مستخدم';
                        final avatar = p?['avatar_url'] as String?;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
                          ),
                          child: Row(children: [
                            UserAvatar(url: avatar, name: name, size: 36),
                            const SizedBox(width: 10),
                            Expanded(child: Text(name, 
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'))),
                            TextButton(
                              onPressed: () => _unblock(peerId),
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.danger.withOpacity(0.1),
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              child: const Text('فك', 
                                style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
                            ),
                          ]),
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.only(right: 20, bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft, 
                          child: TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedUsersScreen())),
                            child: const Text('عرض الكل', 
                              style: TextStyle(color: AppColors.primary, fontSize: 12, fontFamily: 'Tajawal'))
                          )
                        )
                      ),
                    ],
                  ),
                ),
                
                // لوحة الإدارة
                if (isAdmin)
                  _tile(
                    Icons.admin_panel_settings_outlined, 
                    'لوحة الإدارة',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen())),
                    color: AppColors.primary
                  ),
                
                const Spacer(),
                
                // تسجيل الخروج
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _tile(Icons.logout_rounded, 'تسجيل الخروج', () async {
                    Navigator.pop(context);
                    await context.read<AuthProvider>().logout();
                  }, color: AppColors.danger),
                ),
                
                // حقوق 2026
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Text(
                    'جميع الحقوق محفوظة 2026 ©',
                    style: TextStyle(
                      color: AppColors.textSub, 
                      fontSize: 11, 
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // Tile موحد: أيقونة + نص + سهم > + خط سفلي
  Widget _tile(IconData icon, String label, VoidCallback onTap, {Color? color}) => 
    Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(icon, color: color ?? AppColors.textSub, size: 22),
        title: Text(label, 
          style: TextStyle(
            color: color ?? AppColors.text, 
            fontSize: 15, 
            fontWeight: FontWeight.w500,
            fontFamily: 'Tajawal',
          )
        ),
        trailing: Icon(Icons.chevron_left_rounded, color: AppColors.textSub, size: 22), // > موحد
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // بدون كرت
      ),
    );
}
