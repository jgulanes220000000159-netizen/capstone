import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'user/login_page.dart';
import 'user/home_page.dart';
import 'user/register_page.dart';
import 'expert/scan_request_list.dart';
import 'test_account.dart';
import 'admin/screens/admin_login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'expert/expert_dashboard.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  await Hive.openBox('reviews'); // Open a box for review/request data
  await Hive.openBox('userBox'); // Box for login state and user profile
  await Hive.openBox('settings'); // Box for app settings (including locale)
  await Hive.openBox('notificationBox'); // Box for notification counts
  await EasyLocalization.ensureInitialized();
  await dotenv.load(); // Load environment variables
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // --- FCM Notification Setup ---
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Create Android notification channel (Android 8+)
  const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
    'high_importance',
    'High Importance Notifications',
    description: 'Used for important notifications like reviews and requests',
    importance: Importance.high,
  );
  final androidPlugin =
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
  await androidPlugin?.createNotificationChannel(defaultChannel);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // --- End FCM Notification Setup ---

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

// FCM background handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // You can handle background notification logic here
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

  void _setupFCM(BuildContext context) async {
    // Request notification permissions
    await FirebaseMessaging.instance.requestPermission();

    // Get FCM token and store it if needed
    String? token = await FirebaseMessaging.instance.getToken();
    // Store token for the signed-in user (farmer or expert)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
      } catch (_) {
        // ignore write errors silently for now
      }
    }

    // Listen for token refresh and persist
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(u.uid)
              .update({'fcmToken': newToken});
        } catch (_) {}
      }
    });

    // Foreground notification handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    // When app is opened from a notification (background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Handle deep linking or navigation if needed using message.data
    });

    // When app is launched by tapping a notification (terminated)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // Handle cold-start navigation if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    _setupFCM(context);
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
