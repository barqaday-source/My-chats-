import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../providers/auth_provider.dart';
import '../screens/pages/privacy_screen.dart';
import '../screens/pages/contact_screen.dart';
import '../screens/admin/admin_panel_screen.dart';
import '../screens/profile/blocked_users_screen.dart';
import '../widgets/user_avatar.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final isAdmin = user?.role == 'admin';
    final isMod = user?.role == 'moderator' || (user?.isMod ?? false);
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
                      url: user?.avatarUrl,
                      name: user?.username ?? '',
                      size: 52,
                      isOnline: user?.isOnline ?? false,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.username ?? 'زائر',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: AppColors.textSub,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasPrivileges) ...[
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
                                isAdmin ? '👑 مدير' : '🛡️ مشرف',
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
                _tile(
                  context,
                  Icons.block_rounded,
                  'المحظورين',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BlockedUsersScreen())),
                ),
                if (hasPrivileges)
                  _tile(
                    context,
                    Icons.admin_panel_settings_outlined,
                    AppStrings.admin,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminPanelScreen())),
                    color: isAdmin ? AppColors.primary : AppColors.accent,
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
        leading: Icon(icon, color: color ?? AppColors.white70, size: 22),
        title: Text(label,
            style: TextStyle(
                fontFamily: 'Tajawal',
                color: color ?? AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w500)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}
