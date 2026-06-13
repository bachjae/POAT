plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.rallycoach.rallycoach"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    androidResources {
        // Large model assets must stay uncompressed: AssetManager cannot
        // open compressed entries this big, and the chunks are reassembled
        // by streaming reads.
        noCompress += listOf("tflite", "litertlm", "chunk0", "chunk1", "chunk2")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.rallycoach.rallycoach"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // tflite_flutter requires 26; flutter_gemma's LiteRT-LM also
        // assumes modern NNAPI/OpenCL stacks.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            // 16 KB page support (Android 15 / Galaxy S25): keep native libs
            // UNcompressed and page-aligned inside the APK so they are mmap'd
            // directly. This is the modern AGP default; stated explicitly so
            // nobody re-enables legacy extraction and breaks 16 KB devices.
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Disable R8 minification to avoid missing class errors (MediaPipe/proto)
            isMinifyEnabled = false
            isShrinkResources = false
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

