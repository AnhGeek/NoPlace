import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload-key credentials. Never committed — see android/.gitignore, and
// key.properties.example for the shape. CI writes this file from a secret
// before it builds.
//
// Absent, a release build falls back to the debug key so that
// `flutter run --release` still works on a machine without the keystore. That
// fallback is for local use only: Play rejects an upload signed in debug mode,
// which is the whole reason this block exists.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasUploadKey = keystorePropertiesFile.exists()

// Say so at the point it matters. A debug-signed release is not a build error —
// it fails much later, on upload — so the warning is worth more than silence.
gradle.taskGraph.whenReady {
    if (!hasUploadKey && allTasks.any { it.name.contains("Release") }) {
        logger.warn(
            "NoPlace: android/key.properties is missing, so this release build " +
                "is signed with the debug key. Fine for `flutter run --release`; " +
                "Play will reject the upload."
        )
    }
}

android {
    namespace = "site.lya3hc.noplace"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "site.lya3hc.noplace"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("upload") {
            if (hasUploadKey) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                // Relative paths resolve against android/app/.
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
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
