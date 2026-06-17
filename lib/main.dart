import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/pages/privacy_screen.dart';
import 'screens/pages/contact_screen.dart';
import 'screens/pages/about_screen.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/notification_service.dart';

// هذا الـ Key مهم عشان نقدر نستخدم Navigator من أي مكان
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // تهيئة Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL', // حط الرابط مالتك هنا
    anonKey: 'YOUR_SUPABASE_ANON_KEY', // حط المفتاح مالتك هنا
  );

  // تهيئة الإشعارات
  await NotificationService.init();
  
  // تهيئة timeago للعربي
  timeago.setLocaleMessages('ar', timeago.ArMessages());

  runApp(const MyChatApp());
}

class MyChatApp extends StatelessWidget {
  const MyChatApp({super.key});

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
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (!auth.initialized) {
              return const Scaffold(
                backgroundColor: Color(0xFF0B1220),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                ),
              );
            }
            return auth.isLoggedIn ? const HomeScreen() : const WelcomeScreen();
          },
        ),
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
