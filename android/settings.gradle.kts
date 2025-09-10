// android/settings.gradle.kts

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    // Read flutter.sdk from local.properties (or FLUTTER_ROOT)
    val props = java.util.Properties()
    val localProps = File(rootDir, "local.properties")
    if (localProps.exists()) {
        val fis = java.io.FileInputStream(localProps)
        fis.use { stream -> props.load(stream) }
    }
    val flutterSdkPath = props.getProperty("flutter.sdk")
        ?: System.getenv("FLUTTER_ROOT")
        ?: throw GradleException(
            "flutter.sdk not set in android/local.properties and FLUTTER_ROOT not present. " +
            "Run `flutter doctor` or add flutter.sdk to android/local.properties"
        )

    // Let Gradle see Flutter’s build logic
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.6.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")