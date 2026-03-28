import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {

signingConfigs {
    create("release") {
        val props = Properties()
        props.load(rootProject.file("key.properties").inputStream())

        keyAlias = props["keyAlias"] as String
        keyPassword = props["keyPassword"] as String
        storeFile = file(props["storeFile"] as String)
        storePassword = props["storePassword"] as String
    }
}


    namespace = "com.rurboo.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.rurboo.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}

}

flutter {
    source = "../.."
}

dependencies {
    // Import the BoM for the Firebase platform
    // The BoM (Bill of Materials) manages the versions of all Firebase libraries for you.
    implementation(platform("com.google.firebase:firebase-bom:34.8.0"))

    // Add the dependencies for the Firebase products you want to use.
    // When using the BoM, you don't specify versions in Firebase library dependencies.
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-appcheck-playintegrity")
    implementation("com.google.android.play:integrity:1.6.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
