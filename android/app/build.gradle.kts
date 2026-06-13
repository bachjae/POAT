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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id).
        applicationId = "com.rallycoach.rallycoach"
        // tflite_flutter requires 26; flutter_gemma's LiteRT-LM also
        // assumes modern NNAPI/OpenCL stacks.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            // Android 16 (API 36) enforces 16 KB page-size alignment at install
            // time for all native libraries, even when extractNativeLibs=true.
            // Five prebuilt vendor binaries bundled by flutter_gemma are only
            // 4 KB-aligned at the ELF level and CANNOT be rebuilt here:
            //   • libqdrant_edge_ffi.so  — VectorStore/RAG, unused by this app
            //   • libQnnHtpV73/75/79/81Skel.so — Qualcomm NPU skeletons, only
            //     needed when PreferredBackend.npu is explicitly requested;
            //     this app uses the default (auto/GPU) backend.
            // Excluding them lets the APK pass Android 16's install-time check
            // without losing any functionality on the target device.
            useLegacyPackaging = false
            excludes += listOf(
                "**/libqdrant_edge_ffi.so",
                "**/libQnnHtpV73Skel.so",
                "**/libQnnHtpV75Skel.so",
                "**/libQnnHtpV79Skel.so",
                "**/libQnnHtpV81Skel.so",
            )
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
