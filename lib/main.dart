// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'signalling_service.dart';
import 'services/webrtc_service.dart';
import 'screens/lobby_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/username_setup_screen.dart';

class NavigatorService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  MobileAds.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SignalingService()),
        ChangeNotifierProvider(create: (_) => WebRTCService()),
      ],
      child: const MafiaMeetingApp(),
    ),
  );
}

class MafiaMeetingApp extends StatefulWidget {
  const MafiaMeetingApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_MafiaMeetingAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MafiaMeetingApp> createState() => _MafiaMeetingAppState();
}

class _MafiaMeetingAppState extends State<MafiaMeetingApp> {
  Locale _locale = const Locale('en');
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? true;
      _locale = Locale(prefs.getString('locale') ?? 'en');
    });
  }

  void setLocale(Locale newLocale) {
    setState(() => _locale = newLocale);
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString('locale', newLocale.languageCode));
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = value);
    await prefs.setBool('isDarkMode', value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mafia Meeting',
      locale: _locale,
      navigatorKey: NavigatorService.navigatorKey,
      theme: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
        Locale('az'),
      ],
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData) {
            final User? user = snapshot.data;
            if (user == null) {
              return LoginScreen();
            }
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, userDocSnapshot) {
                if (userDocSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                if (userDocSnapshot.hasError) {
                  print(
                      "Ошибка загрузки профиля пользователя в main.dart: ${userDocSnapshot.error}");
                  return UsernameSetupScreen(
                    userId: user.uid,
                    toggleTheme: _toggleTheme, // Добавлено
                    isDarkMode: _isDarkMode, // Добавлено
                  );
                }

                // Проверяем, есть ли пользовательское имя в Firestore
                String? userNameFromFirestore;
                if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                  final userData = userDocSnapshot.data!.data();
                  userNameFromFirestore = userData?['name'] as String?;
                }

                // Если userNameFromFirestore пустой или отсутствует, переходим на UsernameSetupScreen
                if (userNameFromFirestore == null ||
                    userNameFromFirestore.isEmpty) {
                  return UsernameSetupScreen(
                    userId: user.uid,
                    toggleTheme: _toggleTheme,
                    isDarkMode: _isDarkMode,
                  );
                }

                // Если имя пользователя уже есть в Firestore, используем его
                return LobbyScreen(
                  currentUserId: user.uid,
                  playerName: userNameFromFirestore,
                  toggleTheme: _toggleTheme,
                  isDarkMode: _isDarkMode,
                  onLocaleChanged: (locale) =>
                      MafiaMeetingApp.setLocale(context, locale),
                );
              },
            );
          } else {
            return LoginScreen();
          }
        },
      ),
    );
  }
}
