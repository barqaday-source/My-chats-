import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../chat/chats_list_screen.dart';
import '../rooms/rooms_screen.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 1; // نبدأ بالغرف
  int _notifCount = 0;
  final _notifService = NotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotifCount());
  }

  void _loadNotifCount() async {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;
    try {
      final count = await _notifService.unreadCount(uid);
      if (mounted) setState(() => _notifCount = count);
    } catch (e) {
      debugPrint('_loadNotifCount error: $e');
    }
  }

  String _getTitle(int idx) {
    switch (idx) {
      case 0: return 'الدردشات';
      case 1: return 'الغرف';
      case 2: return 'البروفايل';
      case 3: return 'الإشعارات';
      default: return 'CChat';
    }
  }

  Widget _page(int idx) {
    switch (idx) {
      case 0: return const ChatsListScreen();
      case 1: return const RoomsScreen();
      case 2: return const ProfileScreen();
      case 3: return NotificationsScreen(onRead: () => setState(() => _notifCount = 0));
      default: return const RoomsScreen(); // ✅ شلنا _MenuPage
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        drawer: const AppDrawer(), // ✅ المنيو هنا بس
        appBar: AppBar(
          title: Text(_getTitle(_tab)),
          // ✅ حذفنا أيقونة الإشعارات من هنا لأنها صارت تحت
        ),
        body: _page(_tab),
        bottomNavigationBar: AppBottomNav(
          current: _tab,
          notifCount: _notifCount,
          onTap: (i) {
            setState(() => _tab = i);
            if (i == 3) _loadNotifCount(); // حدث العداد لما يفتح الإشعارات
          },
        ),
      );
}
