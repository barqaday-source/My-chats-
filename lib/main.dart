import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'core/theme/app_theme.dart';
import 'core/constants/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'screens/pages/privacy_screen.dart';
import 'screens/pages/contact_screen.dart';
import 'screens/pages/about_screen.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/notification_service.dart';

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

  await SupabaseConfig.init();
  await NotificationService.init();
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
        },
      ),
    );
  }
}
