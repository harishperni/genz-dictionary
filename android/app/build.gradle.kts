// android/app/build.gradle.kts (module-level)
plugins {
    id("com.android.application")
    id("kotlin-android")
    // Must be after Android & Kotlin plugins
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase (reads google-services.json)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.genz_dictionary"

    // Provided by Flutter Gradle plugin
    compileSdk = flutter.compileSdkVersion
    // If you need a pinned NDK, uncomment the next line and set your version:
    // ndkVersion = "29.0.13846066"

    // ✅ Java 17 + core desugaring (required by flutter_local_notifications 17.x)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.genz_dictionary"
        // Firebase Auth requires at least 23
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Replace with a real signing config for release builds later
            signingConfig = signingConfigs.getByName("debug")
            // Enables code shrinking/obfuscation if you want later:
            // isMinifyEnabled = true
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

flutter {
    // Path back to your Flutter project root (inner project)
    source = "../.."
}

dependencies {
    // ✅ Required when isCoreLibraryDesugaringEnabled = true
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
