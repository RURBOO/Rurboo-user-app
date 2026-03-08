# CLAUDE.md — Rurboo User App

This file provides AI assistants with essential context about the Rurboo User App codebase — a Flutter-based ride-sharing application with a voice-first, multi-language interface targeting Indian markets.

---

## Project Overview

**Rurboo** is a cross-platform Flutter ride-hailing app (Android, iOS, macOS, Linux, Windows, Web). It features:
- Firebase-backed authentication (Phone OTP), real-time ride tracking, and cloud messaging
- A voice agent with 16+ states for hands-free booking in multiple Indian languages
- Google Maps integration for routing, geocoding, and place search
- Multi-language support (English, Hindi, Marathi, Tamil, Telugu, Kannada, Gujarati, Bengali)

**Version**: `1.0.8+13` | **Dart SDK**: `^3.8.1` | **Flutter**: Latest stable

---

## Directory Structure

```
Rurboo-user-app/
├── lib/
│   ├── main.dart                   # App entry point — Firebase init, providers, routing
│   ├── core/                       # Shared across all features
│   │   ├── constants/
│   │   │   └── app_strings.dart    # Multi-language translation map (all UI strings)
│   │   ├── navigation/
│   │   │   └── app_router.dart     # Named route constants and route definitions
│   │   ├── services/
│   │   │   ├── user_preferences.dart       # SharedPreferences wrapper
│   │   │   ├── language_service.dart       # Google Translator integration
│   │   │   ├── notification_service.dart   # Firebase Messaging + local notifications
│   │   │   └── deep_link_service.dart      # App links / deep navigation
│   │   ├── theme/
│   │   │   ├── app_colors.dart     # Color palette (primary: #0F62FE, accent: #00B050)
│   │   │   └── app_theme.dart      # Material 3 theme, Plus Jakarta Sans font
│   │   ├── utils/
│   │   │   ├── fare_calc.dart      # Fare calculation utilities
│   │   │   ├── number_to_hindi.dart # Number localization for Hindi TTS
│   │   │   └── safe_parser.dart    # Safe type-casting helpers
│   │   ├── widgets/
│   │   │   └── shimmer_loading.dart # Shimmer skeleton loading widgets
│   │   └── wrappers/
│   │       └── connectivity_wrapper.dart # Network connectivity detection
│   └── features/                   # Feature-based modules
│       ├── auth/                   # Phone OTP auth, profile creation, location permission
│       ├── chat/                   # In-ride messaging (Firebase Firestore)
│       ├── history/                # Past ride listings
│       ├── home/                   # Core map screen, ride booking, location search
│       ├── language/               # Language selection UI
│       ├── navigation/             # Bottom tab navigator
│       ├── onboarding/             # First-launch onboarding slides
│       ├── profile/                # User profile, settings, legal screens
│       ├── ride/                   # Vehicle selection, active ride tracking
│       ├── safety/                 # SOS and safety features
│       ├── searching/              # "Finding driver" screen
│       ├── splash/                 # Splash / startup screen
│       ├── support/                # Help tickets
│       └── voice/                  # Voice agent (TTS/STT, intent parsing, wake word)
├── test/                           # Flutter test files (currently minimal)
├── assets/                         # Icons, images, vehicle images, map styles
├── android/                        # Android platform code
├── ios/                            # iOS platform code
├── pubspec.yaml                    # Dependencies and Flutter config
├── .env.example                    # Environment variable template
├── firestore.rules                 # Firestore security rules
├── storage.rules                   # Firebase Storage security rules
├── analysis_options.yaml           # Dart linter configuration
├── FIREBASE_SETUP.md               # Firebase project setup guide
└── BACKEND_MASTER_GUIDE.md         # Backend architecture documentation
```

---

## Architecture

### Pattern: Clean Architecture + Feature-Based Organization

Each feature follows a consistent layered structure:

```
features/<feature_name>/
├── views/          # UI screens (StatefulWidget / StatelessWidget)
├── viewmodels/     # State management (extends ChangeNotifier)
├── models/         # Data classes with toJson() / fromJson()
├── repositories/   # Data access layer (Firestore, local storage, APIs)
└── services/       # Business logic and third-party wrappers
```

### State Management: Provider

- All state holders extend `ChangeNotifier`
- Dependency injection via `MultiProvider` in `main.dart`
- `ChangeNotifierProxyProvider` used when ViewModels depend on other providers

```dart
// Example: VoiceAgentViewModel is rebuilt when LanguageService changes
ChangeNotifierProxyProvider<LanguageService, VoiceAgentViewModel>(
  create: (context) => VoiceAgentViewModel(...),
  update: (context, langService, previous) => previous!..updateLanguage(langService),
)
```

**Key ViewModels:**

| ViewModel | Responsibility |
|-----------|----------------|
| `HomeViewModel` | Location tracking, pickup/destination, map markers, polylines |
| `VoiceAgentViewModel` | 16-state voice FSM, intent parsing, TTS/STT orchestration |
| `LanguageViewModel` | Current language, UI string translation |
| `RideSelectionViewModel` | Vehicle type selection, fare display |
| `RideBookedViewModel` | Live ride tracking |
| `SearchingDriverViewModel` | Driver search state |
| `HistoryViewModel` | Past rides list |
| `ProfileViewModel` | User profile data |
| `SafetyViewModel` | SOS state |
| `SupportViewModel` | Help ticket management |

---

## Key Conventions

### 1. Debug Logging with Emojis

All `debugPrint()` calls use emoji prefixes for visual categorization. Follow this convention:

| Emoji | Domain |
|-------|--------|
| 🔥 | Firebase operations |
| 📍 | Location / GPS |
| 🎤 | Voice / TTS / STT |
| ✅ | Success states |
| ❌ | Errors / failures |
| 🔐 | Security / auth |
| 🗺️ | Maps / routing |
| 🚗 | Ride operations |
| 💾 | Local storage |
| 📡 | Network calls |

```dart
debugPrint('📍 Location updated: $lat, $lng');
debugPrint('❌ Firebase error: ${e.message}');
```

### 2. Multi-language Strings

All UI text must go through `AppStrings` — never hardcode user-visible strings.

```dart
// In app_strings.dart:
static const Map<String, Map<String, String>> strings = {
  'book_ride': {
    'en': 'Book Ride',
    'hi': 'राइड बुक करें',
    'mr': 'राइड बुक करा',
    // ... other languages
  },
};

// Usage:
final text = AppStrings.get('book_ride', currentLanguage);
```

Supported language codes: `en`, `hi`, `mr`, `ta`, `te`, `kn`, `gu`, `bn`

### 3. Async Safety (BuildContext Across Gaps)

Always capture context-dependent values before `await` calls:

```dart
// CORRECT
final navigator = Navigator.of(context);
final scaffoldMessenger = ScaffoldMessenger.of(context);
await someAsyncOperation();
navigator.pop();

// WRONG — context may be invalid after await
await someAsyncOperation();
Navigator.of(context).pop(); // ❌ Do not do this
```

Always check `mounted` before using `setState` after async operations:

```dart
await someAsyncOperation();
if (!mounted) return;
setState(() { ... });
```

### 4. Error Handling

Use try-catch with graceful degradation. Log errors with `debugPrint` and emoji:

```dart
try {
  final result = await repository.fetchData();
  // handle success
} catch (e) {
  debugPrint('❌ Error fetching data: $e');
  // degrade gracefully — show fallback UI, don't crash
}
```

### 5. Location Accuracy Fallback

Always try high accuracy first, fall back to medium on failure:

```dart
try {
  position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
    timeLimit: const Duration(seconds: 10),
  );
} catch (e) {
  position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.medium,
  );
}
```

### 6. Model Pattern

All data models use named constructors and JSON serialization:

```dart
class RideBooking {
  final String id;
  final String userId;
  // ...

  RideBooking({required this.id, required this.userId});

  factory RideBooking.fromJson(Map<String, dynamic> json) => RideBooking(
    id: json['id'] as String,
    userId: json['userId'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'userId': userId};
}
```

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| State Management | Provider (`^6.1.5+1`) |
| Authentication | Firebase Auth — Phone OTP |
| Database | Cloud Firestore (real-time) |
| Storage | Firebase Storage |
| Push Notifications | Firebase Cloud Messaging |
| Crash Reporting | Firebase Crashlytics |
| Security | Firebase App Check (Play Integrity) |
| Maps | Google Maps Flutter (`^2.14.0`) |
| Routing/Geocoding | Google Places API, Geocoding package |
| Voice (TTS) | `flutter_tts: ^4.2.5` |
| Voice (STT) | `speech_to_text: ^7.3.0` |
| Navigation | Named routes + `go_router` (prepared, not active) |
| Local Storage | `shared_preferences: ^2.5.3` |
| Networking | `http: ^1.6.0` |
| Localization | `flutter_localization`, `translator`, `intl` |
| Deep Linking | `app_links: ^6.3.0` |
| Fonts | Plus Jakarta Sans (UI), Poppins (headings) |
| Image Handling | `image_picker`, `cached_network_image` |
| UI Extras | `shimmer`, `flutter_animate`, `flutter_rating_bar` |

---

## Environment Setup

### Prerequisites

- Flutter SDK (latest stable channel)
- Dart SDK `^3.8.1`
- Firebase CLI
- Google Maps API Key with Places, Directions, Geocoding, Geolocation APIs enabled
- Android Studio / Xcode for platform builds

### Configuration

1. Copy `.env.example` to `.env` in the project root:

```bash
cp .env.example .env
```

2. Fill in required values:

```env
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
FIREBASE_API_KEY=your_firebase_api_key
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_APP_ID=your_app_id
ENV=development
API_BASE_URL=https://api.rurboo.com
RAZORPAY_KEY_ID=your_razorpay_key
```

3. Place your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) in the appropriate platform directories.

### Install Dependencies

```bash
flutter pub get
```

### Run the App

```bash
# Development
flutter run

# Specific platform
flutter run -d android
flutter run -d ios

# Release build
flutter build apk --release
flutter build ios --release
```

---

## Common Development Commands

```bash
# Run app
flutter run

# Run tests
flutter test

# Analyze code (must pass before committing)
flutter analyze

# Format code
dart format lib/

# Generate launcher icons
flutter pub run flutter_launcher_icons

# Check outdated packages
flutter pub outdated

# Upgrade packages
flutter pub upgrade

# Clean build artifacts
flutter clean && flutter pub get
```

---

## Firebase & Firestore

### Collections Structure

| Collection | Document | Purpose |
|-----------|----------|---------|
| `users/{userId}` | User profile | Name, phone, photo, location (GeoPoint), online status, `lastSeen` |
| `rideRequests/{rideId}` | Ride request | Pickup/destination, vehicle type, status, fare, timestamps |
| `drivers/{driverId}` | Driver profile | Name, vehicle, ratings, real-time location |
| `rides/{rideId}` | Completed ride | Full ride history record |

### Firestore Security Rules

- Users can read/write only their own `users/{userId}` document
- Drivers can read all driver documents, write only their own
- Ride requests: creators can read; both user and driver can update status

### Real-time Location Sync

The `HomeViewModel` continuously syncs the user's location to Firestore:
- Updates every **15 seconds** if the user has moved at least **20 meters**
- Writes `currentLocation` (GeoPoint) and `lastSeen` (timestamp) to `users/{userId}`
- Marks user `isOnline: true` while the app is active

### Active Ride Detection

On every app launch, `HomeViewModel.checkForActiveRide()` queries Firestore for rides linked to the current user with status `pending`, `accepted`, `in_progress`, or `arrived`. It automatically redirects to the appropriate screen.

---

## Voice Agent

The voice agent (`VoiceAgentViewModel`) is a core feature. It is a finite state machine with the following states:

```
idle → listening → processing → speaking
     ↓
booking → confirmingFare → searchingDriver → driverAssigned
     ↓
rideStarted → rideCompleted
     ↓
sos (emergency)
     ↓
askName → askAge → askCategory (profile creation flow)
```

### Key Rules for Voice Agent Changes

- All TTS announcements must respect the user's **language setting** (use `languageCode` from `LanguageViewModel`)
- Hindi TTS uses `number_to_hindi.dart` for number conversion (e.g., `150` → `एक सौ पचास`)
- Always call `voiceService.stop()` before starting a new announcement
- State transitions must call `notifyListeners()` to update UI
- The voice agent auto-highlights vehicle cards during fare announcements

---

## Navigation / Routing

Routes are defined in `lib/core/navigation/app_router.dart`:

| Route | Screen |
|-------|--------|
| `/` | `SplashScreen` |
| `/login` | `PhoneInputScreen` |
| `/otp` | `OTPScreen` |
| `/create-profile` | `CreateProfileScreen` |
| `/home` | `HomeScreen` |
| `/ride-selection` | `RideSelectionScreen` |
| `/ride-tracking` | `RideBookedScreen` |

**Navigation patterns:**

```dart
// Push a new screen
Navigator.pushNamed(context, AppRoutes.rideSelection, arguments: rideArgs);

// Replace entire stack (e.g., after login)
Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);

// Pop back
Navigator.pop(context);
```

**Note**: `go_router` is listed as a dependency but the app currently uses Flutter's built-in `Navigator` with named routes. Do not switch to `go_router` without updating all navigation calls.

---

## Google Maps & Places API

- **Android**: API key is set in `android/app/src/main/AndroidManifest.xml` as `<meta-data>` and loaded from `.env`
- **Places API**: Called directly via HTTP in `SearchRepository` — not via the Maps SDK
- **SHA-1 Restriction**: `SearchRepository` switches between debug and release SHA-1 fingerprints based on `kDebugMode`
- **Language Parameter**: Always pass the current language code to Places API calls for localized results

---

## Code Quality Standards

- Run `flutter analyze` before every commit — no warnings allowed
- Run `dart format lib/` to auto-format code
- Use `const` constructors wherever possible
- Avoid `dynamic` typing — use explicit types or generics
- Follow the emoji logging convention for all `debugPrint` calls
- Check `mounted` after every `await` that touches `setState` or `context`
- Never hardcode user-visible strings — use `AppStrings`
- Keep ViewModels free of direct Flutter widget imports (except `ChangeNotifier`)

---

## Known Patterns to Follow

### Adding a New Feature

1. Create `lib/features/<feature_name>/` directory
2. Add subdirectories: `views/`, `viewmodels/`, `models/`, `repositories/`, `services/`
3. Register any new ViewModels in `MultiProvider` in `main.dart`
4. Add routes to `app_router.dart`
5. Add all UI strings to `app_strings.dart` with translations for all 8 languages
6. Follow the existing ChangeNotifier + Repository pattern

### Adding a New Language String

In `lib/core/constants/app_strings.dart`:

```dart
'new_string_key': {
  'en': 'English text',
  'hi': 'हिंदी टेक्स्ट',
  'mr': 'मराठी मजकूर',
  'ta': 'தமிழ் உரை',
  'te': 'తెలుగు వచనం',
  'kn': 'ಕನ್ನಡ ಪಠ್ಯ',
  'gu': 'ગુજરાતી ટેક્સ્ટ',
  'bn': 'বাংলা পাঠ্য',
},
```

### Adding a New Firestore Query

Place data access in the appropriate `repository` class, not directly in ViewModels:

```dart
// In repository:
Future<List<RideHistory>> getRideHistory(String userId) async {
  final snapshot = await _firestore
      .collection('rides')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .get();
  return snapshot.docs.map((doc) => RideHistory.fromJson(doc.data())).toList();
}

// In ViewModel:
final rides = await _repository.getRideHistory(userId);
```

---

## Testing

Tests live in `/test/`. The test infrastructure is minimal — new tests should use `flutter_test`:

```bash
flutter test                    # Run all tests
flutter test test/widget_test.dart  # Run specific file
```

When writing tests:
- Unit test ViewModels and repositories in isolation using mocks
- Widget test screens with `WidgetTester`
- Use `MockFirebaseFirestore` or equivalent for Firestore-dependent code

---

## Security Notes

- **Never commit `.env`** — it is git-ignored; only commit `.env.example`
- **Firebase App Check** is active — debug mode in development, Play Integrity in production
- **API keys** for Google Maps must be restricted by SHA-1 fingerprint and package name in Google Cloud Console
- **Firestore rules** in `firestore.rules` enforce per-user data isolation — always review rules when adding new collections
- **Firebase Auth** handles all authentication — do not implement custom auth flows

---

## Contact & Documentation

- `FIREBASE_SETUP.md` — Full Firebase project configuration guide
- `BACKEND_MASTER_GUIDE.md` — Backend architecture and Cloud Functions documentation
- `FIREBASE_DEBUG_TOKEN_GUIDE.md` — App Check debug token setup
