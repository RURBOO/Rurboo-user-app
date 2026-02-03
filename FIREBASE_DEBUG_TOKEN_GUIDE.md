# Firebase App Check Debug Token Guide

## क्या है Debug Token?

Firebase App Check debug token development में testing के लिए जरूरी है। यह token आपको Firebase Console में register करना होगा ताकि app बिना production security के test हो सके।

---

## Method 1: App को Run करके (Recommended)

### Android

1. **App को debug mode में run करें:**
   ```bash
   flutter run --debug
   ```

2. **Logcat में debug token देखें:**
   
   Terminal में यह output आएगा:
   ```
   D/FirebaseAppCheck: Firebase App Check debug token: XXXXX-XXXXX-XXXXX-XXXXX
   ```
   
   या फिर Android Studio के Logcat में search करें: `App Check`

3. **Alternative - ADB से direct:**
   ```bash
   adb logcat -s FirebaseAppCheck
   ```

### iOS

1. **App को Xcode में run करें**

2. **Console में देखें:**
   ```
   [FirebaseAppCheck] Firebase App Check debug token: XXXXX-XXXXX-XXXXX-XXXXX
   ```

---

## Method 2: Programmatically Generate (Quick Method)

App के `main.dart` में temporarily add करें:

```dart
import 'package:firebase_app_check/firebase_app_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // 🔥 DEBUG TOKEN PRINT करने के लिए
  if (kDebugMode) {
    final token = await FirebaseAppCheck.instance.getToken();
    print('🔥 DEBUG TOKEN: ${token}');
  }
  
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
  );
  
  runApp(const MyApp());
}
```

---

## Method 3: Commands

### Android - Direct Command
```bash
cd android
./gradlew signingReport
```

Debug SHA-1 milega, फिर Firebase Console में add कर सकते हैं।

---

## Debug Token को Firebase में Register करें

1. **Firebase Console खोलें:**
   - https://console.firebase.google.com
   - अपना project select करें

2. **App Check section में जाएं:**
   - Left sidebar → App Check

3. **Apps tab में:**
   - अपना app select करें (com.rurboo.app)

4. **Debug tokens section में:**
   - "Manage debug tokens" पर click करें
   - "Add debug token" पर click करें
   - Copy किया हुआ token paste करें
   - Display name दें (जैसे: "Local Dev Machine")
   - Save करें

---

## Quick Commands (Run करें)

### Android Debug Token निकालने के लिए:

```bash
# Method 1: App run करो और logs देखो
flutter run --debug

# Method 2: ADB से directly
adb shell "logcat -d | grep 'FirebaseAppCheck'"

# Method 3: Fresh install के साथ
flutter clean && flutter run --debug
```

### iOS Debug Token:

```bash
# Xcode से run करें और console में देखें
open ios/Runner.xcworkspace
```

---

## Troubleshooting

### Token नहीं दिख रहा?

1. **Firebase App Check properly configured है?**
   ```bash
   grep -r "FirebaseAppCheck" lib/main.dart
   ```

2. **Debug mode में run कर रहे हैं?**
   ```bash
   flutter run --debug  # Release नहीं
   ```

3. **google-services.json सही जगह है?**
   ```bash
   ls -la android/app/google-services.json
   ```

### Token expire हो गया?

Debug tokens **7 days** में expire होते हैं। नया token generate करके Firebase Console में add करें।

---

## Production के लिए

Production में debug tokens **हटा देना** है। Instead use:
- **Android:** Play Integrity API
- **iOS:** DeviceCheck / App Attest
- **Web:** reCAPTCHA v3

---

**Last Updated:** February 3, 2026  
**Package:** com.rurboo.app
