# Harismruti — Setup Guide

End-to-end setup for the **Hari Smruti** Flutter app. The repo is a UI-only mock today; this guide covers (1) prerequisites to build & run as-is, and (2) what to wire up to convert it into a real, backend-integrated app.

---

## 1. What this project is

- **Name / bundle**: `harismruti` (`org.hp.harismruti`)
- **Type**: Flutter mobile app (Android + iOS), portrait-first, Material 3
- **State management**: GetX (`get`, `get_storage`)
- **Networking**: `dio` with interceptors for auth + refresh + secure error logging
- **Push / messaging**: `firebase_core` + `firebase_messaging` + `flutter_local_notifications`
- **Other**: `flutter_screenutil`, `image_picker` + `image_cropper`, `cached_network_image`, `connectivity_plus`, `flutter_easyloading`, `flutter_pin_code_fields`, `flutter_swiper_view`, `parallax_cards`, `flutter_tilt`, `encrypt`
- **Project metadata** (`.metadata`): Flutter stable channel, revision `6fba2447e95c…` ⇒ **Flutter 3.32.1** (works on later 3.32.x / 3.35.x stable)

### Code structure
```
lib/
├── main.dart                   # entrypoint — bootstrap() currently disabled, home = HomeScreen
├── bootstrap.dart              # Firebase + storage + notifications init (NOT being called)
├── api/
│   ├── api_client.dart         # Dio singleton, auth interceptor, 403 refresh-token retry, secure error log
│   └── api_endpoints.dart      # PLACEHOLDER domains, only login/refresh defined
├── healper_service/
│   └── notification_service.dart  # FCM + local notifications, channel "high_importance_channel"
├── helper/
│   ├── getx_helper.dart        # snackbar wrapper
│   ├── image_service.dart      # camera/gallery sheet + crop
│   ├── log_helper.dart         # AES-encrypted local error log file
│   └── navigation_helper.dart  # GetX named-route wrappers
├── ui/
│   ├── controller/             # GetX controllers (Profile, SmrutiSection, Notification, GlobalBindings)
│   └── view/
│       ├── splash/             # body says "Coming Soon"
│       ├── auth/               # login_home, login, otp, register — NOT wired to API
│       ├── home/               # home_screen + 8 section widgets (recent, with, of, location, album, collection, people, wallpaper)
│       ├── Profile/            # profile_screen (hardcoded user) + smruti_section_setting (reorder/toggle sections, persisted in GetStorage)
│       └── logs/               # encrypted log viewer
├── utils/
│   ├── app_color.dart          # primary #933525, secondary #F6A20A
│   ├── app_string.dart         # SmrutiSectionKeys + hardcoded imageUrls/photoAlbumList/eventList
│   ├── app_routes.dart         # AppRoutes constants — `routes` list is empty
│   ├── firebase_options.dart   # PLACEHOLDER "---" values
│   ├── size_config.dart        # responsive multipliers
│   └── storage_helper.dart     # GetStorage wrapper, accessToken/refreshToken keys
└── widget/
    ├── appbar/                 # CustomAppbar (glass blur), DetailAppbar, SubHeader
    ├── background/             # CustomBackground
    ├── bottom_bar/             # SwamiTabBar
    ├── buttons/                # CustomButton
    ├── carousel/               # AutoScrollCarousel (infinite marquee PageView)
    ├── internet_status_widget.dart
    ├── network_Image_with_loader.dart
    └── spinner.dart
```

---

## 2. Prerequisites

Install these once on your dev machine.

### 2.1 Tooling
| Tool | Version | Notes |
|---|---|---|
| **Flutter SDK** | **3.32.1+** (stable channel) | required by `.metadata` and `sdk: ^3.8.1` |
| **Dart SDK** | 3.8.1+ | bundled with Flutter |
| **Xcode** | 15+ (iOS 14+ deployment target) | macOS only, for iOS builds |
| **CocoaPods** | 1.14+ | `sudo gem install cocoapods` |
| **Android Studio** | Hedgehog 2023.1+ | for emulators + SDK manager |
| **Android SDK** | API 35 (compile/target via Flutter defaults) | min SDK inherits from Flutter (currently 21+) |
| **Android Gradle Plugin** | 8.7.3 (already pinned in `android/settings.gradle.kts`) | needs **JDK 17** |
| **Kotlin** | 2.1.0 (already pinned) | — |
| **Java / JDK** | **17** (Temurin/Zulu) | required for AGP 8.7.3 |
| **Ruby** | 3.x (system or rbenv) | for CocoaPods |
| **Node.js** | 18+ | optional, only for FlutterFire CLI install |
| **FlutterFire CLI** | latest | `dart pub global activate flutterfire_cli` |
| **Firebase CLI** | latest | `npm i -g firebase-tools` |

### 2.2 Verify
```bash
flutter --version          # expect ≥ 3.32.1
flutter doctor -v          # no red ❌; accept Android licenses if asked
dart --version             # ≥ 3.8.1
pod --version              # ≥ 1.14
java -version              # 17.x
```

### 2.3 macOS-only one-time
```bash
sudo gem install cocoapods
flutter precache --ios
```

---

## 3. First-time clone & install

```bash
git clone <repo-url> harismruti
cd harismruti

# Resolve Dart deps
flutter pub get

# iOS pods
cd ios && pod install --repo-update && cd ..

# Sanity check
flutter analyze
```

> If `pod install` complains about `Generated.xcconfig`, run `flutter pub get` again — the iOS Podfile reads `FLUTTER_ROOT` from that file.

### Android `local.properties`
`android/local.properties` is git-ignored. Create it (Android Studio does this automatically on first open):
```properties
sdk.dir=/Users/<you>/Library/Android/sdk
flutter.sdk=/Users/<you>/fvm/versions/3.32.1     # or wherever Flutter lives
flutter.versionName=1.0.0
flutter.versionCode=1
```

---

## 4. Run the mock app

The app currently boots straight into `HomeScreen` (the splash/login flow is bypassed in `main.dart`). Bootstrap (Firebase, GetStorage, notifications) is commented out, so **you can run the UI without any backend keys**.

```bash
flutter run                 # picks first connected device
flutter run -d <deviceId>   # specific device (see `flutter devices`)
flutter run --release       # release-mode profiling on device
```

Hot reload: `r`  •  Hot restart: `R`  •  Quit: `q`

---

## 5. Convert from mock → integrated app

Below are every placeholder/hardcoded touchpoint, ordered by what to do first.

### 5.1 Re-enable bootstrap

`lib/main.dart`:
```dart
void main() async {
  await bootstrap();          // ← uncomment
  runApp(const MyApp());
}
```
…and in `_MyAppState.build`, switch the entry point back to your real flow:
```dart
// home: HomeScreen(),                 // ← remove (mock)
initialRoute: AppRoutes.splash,
getPages: AppRoutes.routes,
```

### 5.2 Configure Firebase (push notifications + future auth)

`lib/utils/firebase_options.dart` and the native config files are placeholders. Regenerate them:

```bash
# 1. login
firebase login

# 2. activate FlutterFire CLI once
dart pub global activate flutterfire_cli
export PATH="$PATH":"$HOME/.pub-cache/bin"

# 3. from the repo root
flutterfire configure \
  --project=<your-firebase-project-id> \
  --platforms=android,ios \
  --android-package-name=org.hp.harismruti \
  --ios-bundle-id=org.hp.harismruti
```

This will:
- Overwrite `lib/utils/firebase_options.dart` with real keys
- Drop `android/app/google-services.json` (currently missing)
- Drop `ios/Runner/GoogleService-Info.plist` (currently missing)

**Android — apply the Google Services Gradle plugin** (not yet wired):

`android/settings.gradle.kts` — add:
```kotlin
id("com.google.gms.google-services") version "4.4.2" apply false
```
`android/app/build.gradle.kts` — add to the `plugins {}` block:
```kotlin
id("com.google.gms.google-services")
```

**iOS** — add `GoogleService-Info.plist` to the `Runner` target in Xcode (drag into the Runner group, tick *Copy if needed* and the Runner target).

**APNs (push on iOS)** — in Xcode:
- Signing & Capabilities → **+ Capability** → *Push Notifications* and *Background Modes* (tick *Remote notifications*).
- Upload an APNs key in Firebase console → Cloud Messaging.

### 5.3 Configure your API backend

`lib/api/api_endpoints.dart`:
```dart
static const String _testDomain = "https://api-staging.example.com";
static const String _liveDomain = "https://api.example.com";
```
…and add the rest of your endpoints (`register`, `verifyOtp`, profile, smruti feeds, etc.) as static getters.

`lib/api/api_client.dart` is already production-shaped: bearer token from `StorageHelper`, JSON encoding, multipart support, 403 → refresh-token retry, encrypted error log. No changes needed unless you change auth scheme.

### 5.4 Wire the auth screens to the API

These screens currently call no API and just `Navigator.push`:
- `lib/ui/view/auth/login.dart` — Sign In button → push OTPScreen
- `lib/ui/view/auth/otp_screen.dart` — Verify button → re-pushes OTPScreen (bug)
- `lib/ui/view/auth/register.dart` — Register button → empty `onTap`
- `lib/ui/view/splash/splash_screen.dart` — body is `Text("Coming Soon")`; `_checkInternetAndNavigate` has empty branch when logged in

Plan: introduce an `AuthController` (GetX) + `AuthRepository` calling `ApiClient.post(ApiEndpoints.login, …)`, persist tokens via `StorageHelper.setValue(key: StorageKeys.accessToken, …)`, and replace direct `Navigator.push` with `NavigationHelper.navigateAndRemoveAll(AppRoutes.home)`.

### 5.5 Replace mock content

| Location | What's mocked | Replace with |
|---|---|---|
| `lib/utils/app_string.dart` | `imageUrls` (24× `epuzzle.info`), `photoAlbumList`, `eventList` | API responses fetched in section controllers |
| `lib/ui/view/home/recent_smruti.dart`, `smruti_with.dart`, `smruti_of.dart`, `album_smruti.dart`, `collection_smruti.dart`, `location_smruti.dart`, `people_smruti.dart`, `wallpaper_smruti.dart` | All consume the static `imageUrls` list | Fetch per-section data; pass into widgets via constructor |
| `lib/ui/view/Profile/profile_screen.dart` | hardcoded `Virendra Rathod`, `+91 98524 12211`, email | bind to `ProfileController` populated from `/profile` API |
| `lib/utils/app_routes.dart` | `routes` list is empty | register `splash`, `login`, `register`, `home` GetPages |
| `lib/ui/controller/global_binding.dart` | empty `dependencies()` | register controllers (`AuthController`, `SmrutiSectionController`, …) |

### 5.6 Native permissions (must add before image picker / notifications work)

**Android** — `android/app/src/main/AndroidManifest.xml` (currently has none):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>
```
And a `FileProvider` for `image_cropper`:
```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths"/>
</provider>
```
…plus a `<activity android:name="com.yalantis.ucrop.UCropActivity" .../>` entry per `image_cropper` docs.

**iOS** — `ios/Runner/Info.plist` (only `NSMotionUsageDescription` is present today):
```xml
<key>NSCameraUsageDescription</key>
<string>Used to capture profile photos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to choose photos for your Smruti collection.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Used to save Smruti images to your library.</string>
```

### 5.7 App identity

| Item | Current | Action |
|---|---|---|
| App icon | default Flutter | replace `android/app/src/main/res/mipmap-*` and `ios/Runner/Assets.xcassets/AppIcon.appiconset` (use `flutter_launcher_icons`) |
| App display name | Android: `harismruti`, iOS: `Harismruti` | update `android:label` and `CFBundleDisplayName` |
| Splash | `Text("Coming Soon")` | use `flutter_native_splash` with brand asset |
| Bundle id | `org.hp.harismruti` | confirm both stores match |
| Signing | debug only | add release `signingConfig` in `android/app/build.gradle.kts` and an Apple distribution profile in Xcode |

### 5.8 Assets folder

`pubspec.yaml` declares `assets/` but the directory does not exist. Create `assets/` and drop fonts/images, or remove the line:
```bash
mkdir assets
```
Note: `fontFamily: 'Poppins'` is set in `main.dart` but no Poppins font is bundled — either add it under `assets/fonts/` and declare `fonts:` in `pubspec.yaml`, or remove the family.

---

## 6. Day-to-day commands

```bash
flutter pub get                           # after pulling
flutter pub upgrade                       # bump deps inside ranges
flutter pub outdated                      # see what's behind
flutter analyze                           # static analysis
flutter test                              # widget tests (test/ has only a stub)
flutter build apk --release               # Android release APK
flutter build appbundle --release         # Play Store .aab
flutter build ios --release               # iOS archive (then ship via Xcode)
flutter clean                             # nuke build/, .dart_tool/, ios/Pods/
cd ios && pod install --repo-update       # after Firebase / native plugin changes
```

---

## 7. Quick smoke checklist after first integration

- [ ] `flutter doctor` is green
- [ ] `flutter pub get` succeeds
- [ ] `flutter run` boots and shows HomeScreen
- [ ] `flutterfire configure` was run; `firebase_options.dart` has real keys
- [ ] `google-services.json` and `GoogleService-Info.plist` are in place
- [ ] Bootstrap re-enabled in `main.dart`
- [ ] `ApiEndpoints._testDomain` / `_liveDomain` set
- [ ] AndroidManifest + Info.plist permissions added
- [ ] Login → OTP → Home actually hits the API and persists `accessToken`
- [ ] Push notification received in foreground / background / terminated states

---

## 8. Known issues / gotchas

- **`splash_screen.dart`** — when `StorageHelper.isLogin()` is true, the function does nothing (no navigation). Fix when wiring the real flow.
- **`otp_screen.dart`** — *Verify* button pushes `OTPScreen` again instead of `HomeScreen`.
- **`firebase_options.dart`** — values are literally `'---'`; `Firebase.initializeApp` will throw until you regenerate.
- **`api_endpoints.dart`** — `_testDomain` / `_liveDomain` are placeholder strings; `dio` will throw `Invalid URL` on first request.
- **`SecureLogger`** in `helper/log_helper.dart` ships hardcoded AES key + IV. Move to a build-time secret (e.g. `--dart-define`) before release.
- **Empty `assets/` directory** declared in `pubspec.yaml` — `flutter pub get` warns until you create it.
- **No `flutter_lints` strictness** — `analysis_options.yaml` includes the package defaults only.
