import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'screens/pages/privacy_screen.dart';
import 'screens/pages/contact_screen.dart';
import 'screens/pages/about_screen.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/notification_service.dart';
import 'widgets/block_guard.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Hive.initFlutter();
  await Hive.openBox('outbox_chat');
  await Hive.openBox('outbox_room');
  await SupabaseConfig.init();
  await NotificationService.init();

  bool isBanned = false;
  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    try {
      final p = await Supabase.instance.client.from('users').select('is_banned').eq('id', user.id).maybeSingle();
      isBanned = p?['is_banned'] == true;
      if (isBanned) await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }
  timeago.setLocaleMessages('ar', timeago.ArMessages());
  runApp(MyChatApp(isBanned: isBanned));
}

class MyChatApp extends StatelessWidget {
  final bool isBanned;
  const MyChatApp({super.key, this.isBanned = false});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..checkSession(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'محادثاتي',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: isBanned ? const BannedScreen() : Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (!auth.initialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            return auth.isLoggedIn ? const BlockGuard(child: HomeScreen()) : const WelcomeScreen();
          }),
        routes: {
          '/privacy': (_) => const PrivacyScreen(),
          '/contact': (_) => const ContactScreen(),
          '/about': (_) => const AboutScreen(),
          '/admin': (_) => const AdminPanelScreen(),
          '/welcome': (_) => const WelcomeScreen(),
          '/home': (_) => const HomeScreen(),
          '/login': (_) => const WelcomeScreen(),
        },
      ),
    );
  }
}

class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.block_rounded, size: 72, color: AppColors.danger),
            SizedBox(height: 16),
            Text('تم حظر حسابك', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('تواصل مع الإدارة إذا تعتقد أن هذا خطأ', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSub)),
          ]),
        ),
      ),
    );
  }
}
