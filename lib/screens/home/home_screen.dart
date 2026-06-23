import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:badges/badges.dart' as badges;
import '../chat/chats_list_screen.dart';
import '../rooms/rooms_screen.dart';
import '../profile/profile_screen.dart';
import '../profile_visits/profile_visits_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 1; // نبدأ بالغرف
  int _notifCount = 0;
  late final NotificationService _notifService;
  late final AuthProvider _authProvider;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _notifService = NotificationService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotifCount());
  }

  Future<void> _loadNotifCount() async {
    final uid = _authProvider.user?.id;
    if (uid == null) return;
    try {
      final count = await _notifService.unreadCount(uid);
      if (mounted) setState(() => _notifCount = count);
    } catch (e) {
      debugPrint('_loadNotifCount error: $e');
    }
  }

  Widget _page(int idx) {
    switch (idx) {
      case 0: return const ChatsListScreen();
      case 1: return const RoomsScreen();
      case 2: return const ProfileScreen();
      case 3: return NotificationsScreen(onRead: () => setState(() => _notifCount = 0));
      default: return const RoomsScreen();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        key: _scaffoldKey,
        drawer: _buildModernDrawer(),
        appBar: AppBar(
          backgroundColor: AppColors.bgCard,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Row(
            children: [
              // أيقونة المنيو بس - شلت اسم الصفحة عشان ما يتكرر
              IconButton(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.density_medium_rounded, color: AppColors.white),
              ),
              const Spacer(),
            ],
          ),
          actions: [
            // أيقونة العين - تظهر بس بتبويب البروفايل
            if (_tab == 2)
              IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const ProfileVisitorsScreen()
                )),
                icon: const Icon(Icons.visibility_rounded, color: AppColors.white),
                tooltip: 'زوار ملفي',
              ),
            // الجرس مع العداد
            badges.Badge(
              showBadge: _notifCount > 0,
              badgeContent: Text(
                _notifCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10)
              ),
              position: badges.BadgePosition.topEnd(top: 0, end: 3),
              badgeStyle: const badges.BadgeStyle(badgeColor: AppColors.danger),
              child: IconButton(
                onPressed: () {
                  setState(() => _tab = 3);
                  _loadNotifCount();
                },
                icon: const Icon(Icons.notifications_rounded, color: AppColors.white),
                tooltip: 'الإشعارات',
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _page(_tab),
        bottomNavigationBar: AppBottomNav(
          current: _tab,
          notifCount: _notifCount,
          onTap: (i) {
            setState(() => _tab = i);
            if (i == 3) _loadNotifCount();
          },
        ),
      );

  // درور انزلاقي حديث مع X
  Widget _buildModernDrawer() {
    final user = _authProvider.user;
    return Drawer(
      backgroundColor: AppColors.bgCard,
      child: SafeArea(
        child: Column(
          children: [
            // هيدر الدرور مع X
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: user?.avatarUrl!= null
                    ? NetworkImage(user!.avatarUrl!)
                      : null,
                    child: user?.avatarUrl == null
                    ? Text(user?.username[0].toUpperCase()?? 'U',
                          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700))
                      : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.username?? 'مستخدم',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16
                          )
                        ),
                        const Text('عرض الملف الشخصي',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            color: AppColors.textSub,
                            fontSize: 12
                          )
                        ),
                      ],
                    ),
                  ),
                  // زر X للإغلاق
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.white),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider),
            // عناصر القائمة
            _drawerItem(Icons.person_rounded, 'الملف الشخصي', () {
              Navigator.pop(context);
              setState(() => _tab = 2);
            }),
            _drawerItem(Icons.visibility_rounded, 'زوار ملفي', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileVisitorsScreen()));
            }),
            _drawerItem(Icons.settings_rounded, 'الإعدادات', () {
              Navigator.pop(context);
            }),
            const Spacer(),
            _drawerItem(Icons.logout_rounded, 'تسجيل خروج', () {
              Navigator.pop(context);
              context.read<AuthProvider>().signOut();
            }, isDestructive: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive? AppColors.danger : AppColors.white),
      title: Text(title,
        style: TextStyle(
          fontFamily: 'Tajawal',
          color: isDestructive? AppColors.danger : AppColors.white,
          fontWeight: FontWeight.w600
        )
      ),
      onTap: onTap,
    );
  }
}
