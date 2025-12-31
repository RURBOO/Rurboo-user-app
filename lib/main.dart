import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/wrappers/connectivity_wrapper.dart';
import 'core/services/language_service.dart';
import 'features/language/viewmodels/language_vm.dart';
import 'features/home/viewmodels/home_viewmodel.dart';
import 'features/home/repositories/home_repository.dart';
import 'features/home/services/location_service.dart';
import 'features/home/services/recent_places_service.dart';
import 'features/home/services/polyline_service.dart';
import 'features/splash/views/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );
  await dotenv.load();

  // Disable Crashlytics
  // FlutterError.onError =
  //     FirebaseCrashlytics.instance.recordFlutterFatalError;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LanguageViewModel(LanguageService()),
        ),
        ChangeNotifierProvider(
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
  // }, (error, stack) {
  //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  // });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RURBOO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Poppins'),
      builder: (context, child) {
        return ConnectivityWrapper(child: child!);
      },
      home: const SplashScreen(),
    );
  }
}
