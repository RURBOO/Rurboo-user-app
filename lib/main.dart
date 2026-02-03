import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

// CORE
import 'core/wrappers/connectivity_wrapper.dart';
import 'core/services/language_service.dart';

// LANGUAGE
import 'features/language/viewmodels/language_vm.dart';

// HOME
import 'features/home/viewmodels/home_viewmodel.dart';
import 'features/home/repositories/home_repository.dart';
import 'features/home/services/location_service.dart';
import 'features/home/services/recent_places_service.dart';
import 'features/home/services/polyline_service.dart';

// SPLASH
import 'features/splash/views/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// 🔥 Firebase init
  await Firebase.initializeApp();

  /// 🔐 App Check
  if (kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    );
  } else {
    await FirebaseAppCheck.instance.activate(
      // webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    );
  }

  /// 🌱 ENV
  await dotenv.load();

  runApp(
    MultiProvider(
      providers: [
        // ===============================
        // SERVICES (LOWEST LAYER)
        // ===============================
        Provider<LanguageService>(
          create: (_) => LanguageService(),
        ),

        // ===============================
        // VIEW MODELS
        // ===============================
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
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rurboo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        primarySwatch: Colors.blue,
      ),
      builder: (context, child) {
        return ConnectivityWrapper(
          child: child ?? const SizedBox(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
