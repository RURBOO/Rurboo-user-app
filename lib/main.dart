// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

// CORE
import 'core/wrappers/connectivity_wrapper.dart';
import 'core/services/language_service.dart';
import 'core/theme/app_theme.dart'; // NEW THEME

// LANGUAGE
import 'features/language/viewmodels/language_vm.dart';
// VOICE
import 'features/voice/viewmodels/voice_agent_viewmodel.dart';

// HOME
import 'features/home/viewmodels/home_viewmodel.dart';
import 'features/home/repositories/home_repository.dart';
import 'features/home/services/location_service.dart';
import 'features/home/services/recent_places_service.dart';
import 'features/home/services/polyline_service.dart';

// DEEP LINK
import 'core/services/deep_link_service.dart';
import 'core/services/notification_service.dart';

// SPLASH
import 'features/splash/views/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ===============================
  // 🔥 FIREBASE INITIALIZATION
  // ===============================
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');
  } catch (e, stack) {
    debugPrint('❌ Firebase init failed: $e');
    debugPrintStack(stackTrace: stack);
  }

  // ===============================
  // 🔐 FIREBASE APP CHECK
  // ===============================
  try {
    // 🔹 Use Play Integrity for Real Devices (Debug & Release)
    // Ensure SHA-1 & SHA-256 are added to Firebase Console!
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
    );
    debugPrint('🔐 App Check: Play Integrity active');

    // ✅ VERY IMPORTANT: prevents token expiry issues
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  } catch (e) {
    debugPrint('⚠️ App Check init issue (non-fatal): $e');
  }

  // ===============================
  // 🌱 ENV VARIABLES
  // ===============================
  try {
    await dotenv.load();
    debugPrint('🌱 ENV loaded');
  } catch (e) {
    debugPrint('⚠️ ENV load failed: $e');
  }

  // ===============================
  // 🔔 NOTIFICATIONS
  // ===============================
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('⚠️ Notification init failed: $e');
  }

  // ===============================
  // 🚀 RUN APP
  // ===============================
  runApp(
    MultiProvider(
      providers: [
        // SERVICES
        Provider<LanguageService>(
          create: (_) => LanguageService(),
        ),

        // VIEW MODELS
        ChangeNotifierProvider<LanguageViewModel>(
          create: (context) =>
              LanguageViewModel(context.read<LanguageService>()),
        ),

        ChangeNotifierProvider<HomeViewModel>(
          create: (_) => HomeViewModel(
            HomeRepository(
              locationService: LocationService(),
              recentService: RecentPlacesService(),
              polylineService: PolylineService(),
            ),
          ),
        ),
        
        // VOICE AGENT
        ChangeNotifierProvider<VoiceAgentViewModel>(
          create: (_) => VoiceAgentViewModel()..init(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

// ===============================
// 🧱 ROOT APP
// ===============================

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize Deep Link Service
    DeepLinkService().init(navigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rurboo',
      navigatorKey: navigatorKey, // 👈 KEY ADDED
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, // APPLIED THEME
      builder: (context, child) {
        return ConnectivityWrapper(
          child: child ?? const SizedBox(),
        );
      },
      home: const SplashScreen(),
    );
  }
}