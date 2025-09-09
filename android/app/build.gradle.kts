plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase Google Services plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.genz_dictionary"
    // Keep using Flutter’s values
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13846066"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.genz_dictionary"

        // Firebase Auth requires minSdk 23
        minSdk = 23
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Sign with debug for now so `flutter run --release` works
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// --- Firebase Android SDKs (required by Firebase Console “Add SDK” step)
dependencies {
    // Use the Firebase Bill of Materials to manage versions
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))

    // Add the SDKs you need:
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    // (Optional) others later: analytics, messaging, crashlytics, etc.
}