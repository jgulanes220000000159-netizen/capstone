import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'user/login_page.dart';
import 'user/home_page.dart';
import 'user/register_page.dart';
import 'expert/expert_dashboard.dart';
import 'test_account.dart';
import 'admin/screens/admin_login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:easy_localization/easy_localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  await Hive.openBox('reviews'); // Open a box for review/request data
  await Hive.openBox('userBox'); // Box for login state and user profile
  await Hive.openBox('settings'); // Box for app settings (including locale)
  await EasyLocalization.ensureInitialized();

  // Load saved locale from Hive
  final settingsBox = Hive.box('settings');
  String? localeCode = settingsBox.get('locale_code');
  Locale? startLocale;
  if (localeCode != null && ['en', 'bs', 'tl'].contains(localeCode)) {
    startLocale = Locale(localeCode);
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('bs'), Locale('tl')],
      path: 'assets/lang',
      fallbackLocale: const Locale('en'),
      startLocale: startLocale,
      child: const CapstoneApp(),
    ),
  );
}

class CapstoneApp extends StatelessWidget {
  const CapstoneApp({Key? key}) : super(key: key);

  Future<bool> _checkLogin() async {
    final box = Hive.box('userBox');
    return box.get('isLoggedIn', defaultValue: false) as bool;
  }

  Future<Widget> _getStartPage() async {
    final box = Hive.box('userBox');
    final isLoggedIn = box.get('isLoggedIn', defaultValue: false) as bool;
    if (!isLoggedIn) return const LoginPage();
    final userProfile = box.get('userProfile');
    final role = userProfile != null ? userProfile['role'] : null;
    if (role == 'expert') {
      return const ExpertDashboard();
    } else {
      return const HomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder:
          (context) => MaterialApp(
            title: 'Mango Detection',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.blue,
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                ),
              ),
            ),
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: FutureBuilder<Widget>(
              future: _getStartPage(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return snapshot.data!;
              },
            ),
            routes: {
              '/login': (context) => const LoginPage(),
              '/register': (context) => const RegisterPage(),
              '/user-home': (context) => const HomePage(),
              '/expert-home': (context) => const ExpertDashboard(),
              '/admin-login': (context) => const AdminLogin(),
            },
          ),
    );
  }
}
