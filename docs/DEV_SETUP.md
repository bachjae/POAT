# Dev environment setup (Android, from scratch)

This captures the **exact toolchain** RallyCoach builds with, so a fresh
machine is a scripted reproduction instead of a rediscovery. None of these
artifacts live in the repo — they are machine-global SDK/runtime installs —
so a brand-new machine still downloads them once. What this doc removes is
the *figuring-out* time.

> Versions verified building on Windows 11 (Galaxy S25 target), 2026-06.
> Newer patch versions are usually fine; the majors are what matter.

## Toolchain versions

| Component | Version | Notes |
|---|---|---|
| Flutter SDK | 3.44.2 (stable) | Dart 3.12.2 bundled |
| JDK | Microsoft OpenJDK 17 (17.0.19) | `JAVA_HOME` must point here |
| Android SDK Platform | android-35 | `flutter.compileSdkVersion` |
| Android Build-Tools | 35.0.0 | |
| Android Platform-Tools | 37.x | provides `adb` |
| Android NDK | 28.2.13676358 | r28 ⇒ 16 KB-aligned `.so` by default |
| Android Gradle Plugin | 9.0.1 | `android/settings.gradle.kts` |
| Gradle | 9.1.0 | `android/gradle/wrapper/...` |
| Kotlin | 2.3.20 | |

## 1. Flutter SDK

Install Flutter 3.44.2 (stable) and put `<flutter>/bin` on PATH, **or**
reference it via `android/local.properties` (git-ignored):

```properties
flutter.sdk=C:\\Users\\<you>\\flutter
sdk.dir=C:\\Users\\<you>\\AppData\\Local\\Android\\Sdk
```

## 2. JDK 17 (Windows)

```sh
winget install Microsoft.OpenJDK.17 --accept-package-agreements --accept-source-agreements
# JAVA_HOME -> C:\Program Files\Microsoft\jdk-17.x.x-hotspot
```

## 3. Android SDK (command-line tools, no Android Studio required)

Download `commandlinetools-win-*_latest.zip` from
<https://developer.android.com/studio#command-tools>, unzip to
`%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\`, then:

```sh
# from cmdline-tools\latest\bin
sdkmanager.bat --licenses          # accept all
sdkmanager.bat "platform-tools" "platforms;android-35" "build-tools;35.0.0"
flutter config --android-sdk "%LOCALAPPDATA%\Android\Sdk"
```

The NDK (28.2.x), CMake, and build-tools;36 are pulled automatically by the
first `flutter run` — no manual step.

## 4. Connecting a phone — wireless ADB (no USB driver needed)

USB on Windows needs an OEM driver (Samsung's was the blocker here). Wireless
debugging sidesteps it entirely and is the recommended path:

On the phone: **Developer Options → Wireless debugging → ON**.

```sh
# one-time pair: code + IP:port from "Pair device with pairing code"
adb pair 192.168.1.x:PAIRPORT PAIRINGCODE
# connect: IP:port from the main Wireless debugging screen (port changes
# each time debugging restarts / the screen locks — reconnect with the new one)
adb connect 192.168.1.x:CONNPORT
```

## 5. Build / run

```sh
flutter pub get                       # pubspec.lock is committed -> deterministic
flutter run -d <device-id>            # first build ~20 min (NDK + gemma libs); later builds fast
```

First build also downloads `flutter_gemma`'s native libs (LiteRT-LM, qdrant)
to `%LOCALAPPDATA%\flutter_gemma\native\` — another machine-global one-time cache.

## Why a fresh machine is still slow once

The multi-GB downloads (Flutter SDK, JDK, Android SDK/NDK, Gradle dist,
pub-cache, flutter_gemma native libs) all land in machine-global caches, not
the repo, so they cannot be committed away. On the **same** machine, second
checkouts are fast because those caches are already warm. `pubspec.lock` (and
the pinned Gradle/AGP versions) make the dependency-resolution step
deterministic and skip version solving.

## 16 KB page alignment (Android 15 / Galaxy S25)

`android/app/build.gradle.kts` sets `useLegacyPackaging = false` so native
libs are stored **uncompressed and page-aligned** in the APK (mmap-able). With
NDK r28 everything we build is 16 KB-aligned. Five prebuilt vendor binaries
inside `flutter_gemma` are still 4 KB-aligned (`libqdrant_edge_ffi.so`,
`libQnnHtpV{73,75,79,81}Skel.so`) — only their upstream authors can fix those;
they do not affect running on current devices (16 KB pages are opt-in).
