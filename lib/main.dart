// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:flutter/foundation.dart';
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
import 'features/voice/models/voice_agent_state.dart';

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

// NAVIGATION
import 'core/navigation/app_router.dart';
import 'features/ride/views/ride_selection_screen.dart';
import 'features/ride/views/ride_booked_screen.dart';

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
  // 🚨 CRASHLYTICS CONFIG
  // ===============================
  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // ===============================
  // 🔐 FIREBASE APP CHECK
  // ===============================
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode 
          ? AndroidProvider.debug 
          : AndroidProvider.playIntegrity,
    );
    debugPrint('🔐 App Check: ${kDebugMode ? "Debug" : "Play Integrity"} active');

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
  // 🚀 RUN APP (WITH ERROR HANDLING)
  // ===============================
  runZonedGuarded(() {
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
          ChangeNotifierProxyProvider<LanguageViewModel, VoiceAgentViewModel>(
            create: (_) => VoiceAgentViewModel()..init(),
            update: (_, lang, voice) {
              if (voice != null) {
                voice.updateLanguage(lang.language);
              }
              return voice ?? VoiceAgentViewModel();
            },
          ),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint("🔴 CRITICAL APP ERROR: $error");
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
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
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      
      // 1. Static Routes
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        // AppRoutes.home: (context) => const HomeScreen(), 
        // Note: HomeScreen is usually pushed manually or via wrapper, keeping simple for now.
      },

      // 2. Dynamic Routes (Arguments)
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.rideSelection:
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => RideSelectionScreen(
                pickupText: args['pickupText'],
                destinationText: args['destinationText'],
                pickupLoc: args['pickupLoc'],
                destinationLoc: args['destinationLoc'],
                distanceKm: args['distanceKm'],
              ),
            );

          case AppRoutes.rideTracking:
             final args = settings.arguments as Map<String, dynamic>;
             return MaterialPageRoute(
               builder: (context) => RideBookedScreen(
                 pickupLatLng: args['pickupLatLng'],
                 pickupAddress: args['pickupAddress'],
                 destinationLatLng: args['destinationLatLng'],
                 destinationAddress: args['destinationAddress'],
                 ride: args['ride'],
                 rideId: args['rideId'],
               ),
             );

          default:
            return null;
        }
      },
      
      builder: (context, child) {
        return ConnectivityWrapper(
          child: Listener(
            onPointerDown: (_) {
              // Global Tap Listener to Stop Voice Announcements
              final voiceVM = Provider.of<VoiceAgentViewModel>(context, listen: false);
              if (voiceVM.state == VoiceAgentState.speaking) {
                voiceVM.stopAnnouncement();
              }
            },
            child: child ?? const SizedBox(),
          ),
        );
      },
    );
  }
}