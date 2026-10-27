import java.util.Properties

plugins {
    id("com.android.application")
    // Reads google-services.json so Firebase.initializeApp() works.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: create android/key.properties (never commit it) with
// storePassword, keyPassword, keyAlias and storeFile. See RELEASE_CHECKLIST.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

// AdMob app id. Google's public test id unless -PadmobAppId=... is passed.
val admobAppId: String =
    (project.findProperty("admobAppId") as String?)
        ?: "ca-app-pub-3940256099942544~3347511713"

android {
    namespace = "com.arrowescape.arrow_escape"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.arrowescape.arrow_escape"
        minSdk = flutter.minSdkVersion
        // Flutter's default is API 36, which Google Play requires for new
        // apps and updates from 31 Aug 2026.
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug signing only so local `flutter run --release`
            // works without a keystore. Play uploads require key.properties.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
