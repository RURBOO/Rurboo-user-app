# Firebase Configuration Guide for Rurboo

This guide will help you set up Firebase for the Rurboo app.

## Prerequisites
- Google account
- Access to Firebase Console (https://console.firebase.google.com)

---

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add Project"
3. Enter project name: `rurboo` (or your preferred name)
4. Enable Google Analytics (recommended)
5. Click "Create Project"

---

## Step 2: Add Android App

1. In Firebase Console, click the Android icon
2. Enter Android package name: `com.rurboo.app` (check `android/app/build.gradle` for actual package)
3. Enter app nickname: "Rurboo User App"
4. Download `google-services.json`
5. **IMPORTANT**: Place the file here:
   ```
   android/app/google-services.json
   ```

---

## Step 3: Add iOS App

1. In Firebase Console, click the iOS icon
2. Enter iOS bundle ID: `com.rurboo.app` (check `ios/Runner.xcodeproj` for actual bundle)
3. Download `GoogleService-Info.plist`
4. **IMPORTANT**: Place the file here:
   ```
   ios/Runner/GoogleService-Info.plist
   ```
5. Also add it to Xcode project (open in Xcode and drag the file into the project)

---

## Step 4: Enable Firebase Services

### Authentication
1. Go to "Authentication" → "Sign-in method"
2. Enable "Phone" provider
3. Add your test phone numbers if needed

### Firestore Database
1. Go to "Firestore Database"
2. Click "Create Database"
3. Start in **production mode** (we'll add security rules later)
4. Choose a location (asia-south1 for India recommended)

### Firebase Storage
1. Go to "Storage"
2. Click "Get Started"
3. Start in **production mode**
4. Same location as Firestore

### Cloud Messaging (FCM)
1. Already enabled by defaultp
2. No additional setup needed

### Crashlytics
1. Go to "Crashlytics"
2. Click "Set up Crashlytics"
3. Follow the setup wizard

### App Check
1. Go to "App Check"
2. Register your app
3. For development: Use "Debug provider"
4. For production: Use "Play Integrity" (Android) and "App Attest" (iOS)

---

## Step 5: Security Rules

### Firestore Rules (Copy to Firebase Console)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && isOwner(userId);
      allow update, delete: if isSignedIn() && isOwner(userId);
    }
    
    // Rides collection
    match /rides/{rideId} {
      allow read: if isSignedIn() && (
        resource.data.userId == request.auth.uid ||
        resource.data.driverId == request.auth.uid
      );
      allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
      allow update: if isSignedIn() && (
        resource.data.userId == request.auth.uid ||
        resource.data.driverId == request.auth.uid
      );
    }
    
    // Drivers collection
    match /drivers/{driverId} {
      allow read: if isSignedIn();
      allow create, update: if isSignedIn() && isOwner(driverId);
    }
    
    // Recent places (user-specific)
    match /users/{userId}/recent_places/{placeId} {
      allow read, write: if isSignedIn() && isOwner(userId);
    }
    
    // Settings (user-specific)
    match /users/{userId}/settings/{settingId} {
      allow read, write: if isSignedIn() && isOwner(userId);
    }
  }
}
```

### Storage Rules (Copy to Firebase Console)

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Profile pictures
    match /profile_pictures/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null 
                   && request.auth.uid == userId
                   && request.resource.size < 5 * 1024 * 1024  // 5MB limit
                   && request.resource.contentType.matches('image/.*');
    }
    
    // Vehicle documents (driver only)
    match /vehicle_documents/{driverId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == driverId;
    }
  }
}
```

---

## Step 6: Update .env File

After setting up Firebase, update your `.env` file with:

```env
# Firebase (if needed for web or custom configs)
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_API_KEY=your-api-key
```

---

## Step 7: Verify Setup

Run these commands to verify:

```bash
# Check if google-services.json exists
ls -la android/app/google-services.json

# Check if GoogleService-Info.plist exists
ls -la ios/Runner/GoogleService-Info.plist

# Run the app
flutter run
```

---

## Troubleshooting

### Android: "google-services.json not found"
- Make sure the file is in `android/app/` directory
- Clean and rebuild: `cd android && ./gradlew clean && cd ..`

### iOS: "GoogleService-Info.plist not found"
- Open project in Xcode
- Drag the file into the Runner folder
- Make sure "Copy items if needed" is checked

### Firebase not initializing
- Check `main.dart` has `await Firebase.initializeApp()`
- Verify internet connection
- Check Firebase project is active

---

## Production Checklist

Before going to production:

- [ ] Update Firestore rules (remove test mode)
- [ ] Update Storage rules (remove test mode)
- [ ] Enable App Check (production providers)
- [ ] Set up Firebase Crashlytics
- [ ] Configure Firebase Analytics
- [ ] Set up Cloud Functions (if needed)
- [ ] Add API keys to environment variables
- [ ] Test on real devices
- [ ] Monitor Firebase quotas and billing

---

## Useful Links

- [Firebase Console](https://console.firebase.google.com)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase Pricing](https://firebase.google.com/pricing)

---

**Last Updated**: February 3, 2026
