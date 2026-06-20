import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../providers/auth_provider.dart';
import '../screens/pages/privacy_screen.dart';
import '../screens/pages/contact_screen.dart';
import '../screens/admin/admin_panel_screen.dart';
import '../screens/profile/blocked_users_screen.dart';
import '../services/chat_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/app_snackbar.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
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
      final res = await _supabase
          .from('blocked_users')
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
    final user = auth.currentUser;
    final profile = auth.userProfile;
    
    final role = profile?['role'] as String?;
    final isModFlag = profile?['is_mod'] as bool?? false;
    final isAdmin = role == 'admin';
    final isMod = role == 'moderator' || isModFlag;
    final hasPrivileges = isAdmin || isMod;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: AppColors.bg.withOpacity(0.95),
            child: SafeArea(
              child: Column(children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    UserAvatar(
                      url: profile?['avatar_url'],
                      name: profile?['username']?? '',
                      size: 52,
                      isOnline: profile?['is_online']?? false,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?['username']?? 'زائر',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            user?.email?? '',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: AppColors.textSub,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasPrivileges)...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isAdmin
                                        ? AppColors.primary
                                        : AppColors.accent)
                                   .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: (isAdmin
                                          ? AppColors.primary
                                          : AppColors.accent)
                                      .withOpacity(0.4),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                isAdmin? '👑 مدير' : '🛡️ مشرف',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: isAdmin
                                      ? AppColors.primary
                                      : AppColors.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(color: AppColors.divider),
                ),
                _tile(
                  context,
                  Icons.shield_outlined,
                  AppStrings.privacy,
                  () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                ),
                _tile(
                  context,
                  Icons.mail_outline_rounded,
                  AppStrings.contactUs,
                  () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ContactScreen())),
                ),
                
                // ===== قسم المحظورين - مع عرض مباشر =====
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.block_rounded, color: AppColors.white70, size: 22),
                    title: const Text('المحظورين',
                      style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w500)),
                    trailing: Icon(_blockedOpen ? Icons.expand_less : Icons.expand_more, color: AppColors.textSub),
                    onExpansionChanged: (v) {
                      setState(() => _blockedOpen = v);
                      if (v) _loadBlocked();
                    },
                    children: [
                      if (_blockedLoading)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                        )
                      else if (_blocked.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text('لا يوجد محظورين',
                            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 12)),
                        )
                      else
                        ..._blocked.map((b) {
                          final p = b['profiles'] as Map<String, dynamic>?;
                          final peerId = b['blocked_id'] as String;
                          final name = p?['username'] ?? 'مستخدم';
                          final avatar = p?['avatar_url'] as String?;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Row(
                              children: [
                                UserAvatar(url: avatar, name: name, size: 32),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 13)),
                                ),
                                TextButton(
                                  onPressed: () => _unblock(peerId),
                                  style: TextButton.styleFrom(
                                    backgroundColor: AppColors.danger.withOpacity(0.15),
                                    minimumSize: const Size(0, 32),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('فك',
                                    style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          );
                        }),
                      // رابط لفتح الصفحة الكاملة
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const BlockedUsersScreen())),
                          child: const Text('عرض الكل →',
                            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.primary, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
                // ===== نهاية قسم المحظورين =====

                if (hasPrivileges)
                  _tile(
                    context,
                    Icons.admin_panel_settings_outlined,
                    AppStrings.admin,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminPanelScreen())),
                    color: isAdmin? AppColors.primary : AppColors.accent,
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _tile(
                    context,
                    Icons.logout_rounded,
                    AppStrings.logout,
                    () async {
                      Navigator.pop(context);
                      await context.read<AuthProvider>().logout();
                    },
                    color: AppColors.danger,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext ctx, IconData icon, String label, VoidCallback onTap,
          {Color? color}) =>
      ListTile(
        leading: Icon(icon, color: color?? AppColors.white70, size: 22),
        title: Text(label,
            style: TextStyle(
                fontFamily: 'Tajawal',
                color: color?? AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w500)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}
