# Rurboo Backend Setup Guide

This guide covers the complete backend setup for Rurboo using Firebase and Google Cloud. Follow these steps sequentially to activate Map services, OTP authentication, and Storage.

---

## 🚀 Part 1: Firebase Project Setup

1.  Go to the [Firebase Console](https://console.firebase.google.com/).
2.  Click **Add project** and name it `Rurboo-Pro`.
3.  Enable **Google Analytics** (optional) and create the project.
4.  Once created, change your billing plan to **Blaze (Pay as you go)**. **This is REQUIRED for Google Maps and Phone Auth to work.** (You won't be charged unless you exceed free tiers).

### Add Android App
1.  Click the **Android icon** to add an app.
2.  **Package Name:** `com.rurboo.app`
3.  **App Nickname:** `Rurboo User App`
4.  **Debug Signing Certificate SHA-1:**
    ```text
    D2:EF:14:F3:EB:8E:65:90:29:22:26:1E:90:09:7F:18:2F:D6:A6:E0
    ```
5.  Click **Register app**.
6.  **Download `google-services.json`** and place it in your project at:
    `android/app/google-services.json`
7.  Click **Next** through the remaining steps.

### Add iOS App (Optional for now)
1.  Click **Add app** -> **iOS**.
2.  **Bundle ID:** `com.rurboo.app` (or `Rurboo` as per your plist, verify matches).
3.  Download `GoogleService-Info.plist` and place it in `ios/Runner/`.

---

## 🔑 Part 2: Google Maps & Cloud Console

1.  Go to the [Google Cloud Console](https://console.cloud.google.com/).
2.  Select your `Rurboo-Pro` project from the dropdown.
3.  Go to **APIs & Services** > **Library**.
4.  **Enable the following APIs** (Search for each and click Enable):
    *   **Maps SDK for Android**
    *   **Maps SDK for iOS**
    *   **Places API (New)**
    *   **Directions API**
    *   **Geolocation API**

### Create API Credentials
1.  Go to **APIs & Services** > **Credentials**.
2.  Click **Create Credentials** > **API Key**.
3.  Copy this key. We will call it `YOUR_GOOGLE_MAPS_KEY`.
4.  (Restricted recommended) Click **Edit API Key**:
    *   **Name:** `Rurboo Android Key`
    *   **Application restrictions:** Android apps
    *   **Package name:** `com.rurboo.app`
    *   **SHA-1 certificate fingerprint:** `D2:EF:14:F3:EB:8E:65:90:29:22:26:1E:90:09:7F:18:2F:D6:A6:E0`
    *   **API restrictions:** Select the 5 APIs enabled above.
    *   *Note: For development ease, you can leave it unrestricted temporarily, but restrict it before production.*

---

## 🔐 Part 3: Authentication & App Check

### Enable Phone Auth
1.  In Firebase Console, go to **Authentication** > **Sign-in method**.
2.  Click **Phone** and enable it.
3.  Add a test phone number for development (e.g., `+91 9999999999` code `123456`) to save SMS costs.

### Enable App Check (Crucial for Integrity)
1.  Go to **Build** > **App Check**.
2.  Click **Get Started**.
3.  Select your Android app (`com.rurboo.app`).
4.  Click **Play Integrity**.
5.  It might ask for SHA-256. Paste this:
    ```text
    23:BE:60:2C:DF:DF:32:8B:9C:3F:C9:73:17:E1:8D:73:5F:C8:B6:C8:B1:86:83:80:DE:B0:EB:D1:EA:22:D9:CD
    ```
6.  Click **Save**.

---

## 🛠 Part 4: Code Integration

### 1. Update Android Manifest
Open `android/app/src/main/AndroidManifest.xml` and make sure this tag has your key:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_KEY" />
```

### 2. Update Environment Variables
Open `.env` file in the project root and update:
```text
GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_KEY
```

### 3. Update iOS Configuration
Open `ios/Runner/AppDelegate.swift` and add `GMSServices`:
```swift
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_KEY") // <--- ADD THIS
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

---

## 🛡 Part 5: Security Rules

### Firestore Rules
Go to **Firestore Database** > **Rules** and paste:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /drivers/{driverId} {
      allow write: if request.auth != null && request.auth.uid == driverId;
      allow read: if request.auth != null;
    }
    match /rides/{rideId} {
      allow create: if request.auth != null;
      allow read, update: if request.auth != null && (
        resource.data.userId == request.auth.uid || 
        resource.data.driverId == request.auth.uid
      );
    }
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Storage Rules
Go to **Storage** > **Rules** and paste:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_images/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

---

## ✅ Part 6: Final Verification

1.  **Stop** any running app instances.
2.  Run `flutter clean`.
3.  Run `flutter run`.
4.  Test **Login with Phone** (OTP should arrive).
5.  Test **Google Maps** (Map should load).
