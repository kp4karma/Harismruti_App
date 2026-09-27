# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Hari Smruti** (`harismruti`, bundle id `org.hp.harismruti`) — a Flutter mobile app (Android + iOS) for browsing a curated photo/media gallery ("Smruti"), backed by a real REST API. State management is GetX (`get` + `get_storage`). Portrait-first, Material 3.

## Commands

```bash
flutter pub get                           # install/refresh deps after pulling
flutter analyze                           # static analysis — run before considering a change done
flutter test                              # run all tests (test/ has unit + widget tests)
flutter test test/ui/controller/gallery_controller_filter_test.dart   # single test file
flutter test --plain-name "groups My Smruti under matching main-category subheaders"  # single test by name
flutter run                               # run on first connected device
flutter run -d <deviceId>                 # run on a specific device
cd ios && pod install --repo-update       # after Firebase / native plugin / Podfile changes
flutter clean                             # nuke build/, .dart_tool/, ios/Pods/ when builds misbehave
```

Release builds accept `--dart-define` overrides (see `lib/api/api_endpoints.dart` and `MIXPANEL.md`):
- `API_BASE_URL` — override the API host entirely
- `VRUND_API_BASE_URL` — secondary admin API host
- `MOBILE_API_KEY` — `X-API-Key` header value
- `MIXPANEL_TOKEN` — send analytics to a non-production Mixpanel project

There is no backend/server in this repo — the app talks to a hosted API (`hpsmruti.suhrad.digital`). Do not go looking for server-side code here.

## Architecture

### Layering

```
lib/
├── main.dart / bootstrap.dart   # startup sequencing (see below)
├── api/
│   ├── api_client.dart          # single Dio instance; auth, retry, caching, logging all live here
│   ├── api_endpoints.dart       # every backend path as a static getter/method
│   ├── api_visibility.dart      # response-level filtering of API-flagged "ignored" items
│   ├── auth_repository.dart
│   ├── models/                  # plain Dart response/request models
│   └── repositories/            # one repository per feature area, wraps ApiClient calls
├── ui/
│   ├── controller/               # GetX controllers — one per feature, registered in global_binding.dart
│   └── view/                     # screens, grouped by feature folder (home, auth, gallery, Profile, notification, logs, splash)
├── widget/                        # reusable presentational widgets (appbar, carousel, buttons, gallery cards…)
├── helper/                        # small stateless utilities (navigation, snackbars, image picking, logging)
├── healper_service/               # FCM + local notification wiring (note the misspelled dir name — intentional, matches existing imports)
├── services/                      # cross-cutting app services (see below)
└── utils/                         # constants, theming, storage keys, routes, size/responsive helpers
```

**Pattern to follow when adding a feature**: add a repository under `api/repositories/` that calls `ApiClient`, a GetX controller under `ui/controller/` that owns the repository and app state, register the controller in `global_binding.dart` (as `Get.put(..., permanent: true)` or `Get.lazyPut(..., fenix: true)` depending on whether it should survive navigation), and a screen under `ui/view/<feature>/`. Add the route to `AppRoutes` in `lib/utils/app_routes.dart`.

### Startup sequence (`lib/main.dart`, `lib/bootstrap.dart`)

Startup is split into a blocking phase and a deferred phase so the first frame isn't held up:

1. `bootstrap()` — runs before `runApp`: orientation lock, `StorageHelper.init()`, `ApiClient.init()`, image cache sizing, EasyLoading config. `_StartupGate` shows a themed logo splash (`AppImages.darkThemeLogo`/`lightThemeLogo`) while this future is pending.
2. Once `bootstrap()` resolves, `MyApp` mounts and immediately schedules `bootstrapDeferredServices()` in a post-frame callback: Firebase/FCM setup (`bootstrapNotifications`, no-ops gracefully if `firebase_options.dart` isn't configured yet), Mixpanel (`AnalyticsService`), and `DeepLinkService.instance.start()`.
3. `ShorebirdUpdateService` checks for a Dart patch on first frame and whenever the app resumes (throttled). Patches require a full app restart to activate — see `SHOREBIRD.md`.

Routing is GetX (`GetMaterialApp`, `initialRoute`/`getPages` from `AppRoutes.routes`); the initial route is the splash screen, which decides where to send the user based on `StorageHelper.isLogin()`.

### `ApiClient` (`lib/api/api_client.dart`)

A single static Dio wrapper — read this file before touching networking code:
- Bearer token auto-attached from `StorageHelper` except for `ApiClient.skipAuthEndpoints` (login/verify-otp/register).
- 401/403 responses trigger a single in-flight token refresh (`_refreshFuture` dedupes concurrent refreshes) and retry the original request once; repeated failure force-logs-out via `Get.offAllNamed`.
- `GET` responses are cached in-memory per `(mobileUserKey, path, sorted query)` for 15 minutes by default (`cacheDuration` param, `forceRefresh` to bypass); any mutating call (`post`/`put`/`patch`/`delete`) clears the whole cache.
- Every successful response is passed through `filterIgnoredApiItems` (`api_visibility.dart`), which strips any object anywhere in the payload flagged `ignore`/`ignored`/etc. — this happens transparently, so don't re-filter in repositories.
- Errors are normalized through `_handleError`; a 409 specifically raises `ApiRequestException` (carries `statusCode`/`data`) so callers can branch on conflict responses distinctly from generic `Exception`s.

### Native platform surfaces

- **Home screen widgets** (Android App Widgets + iOS `WidgetKit`): built via the `home_widget` package. Android providers live in `android/app/src/main/kotlin/org/hp/harismruti/SmrutiHomeWidgetProvider.kt` plus matching `res/xml/*_widget_info.xml` / `res/layout/*` files (there are 5 named providers — see `PhoneSmrutiWidgetService.providerNames`). iOS side is the `SmrutiWidgets` Xcode target (`ios/SmrutiWidgets/`), sharing data via app group `group.org.hp.harismruti.widgets`. `lib/services/phone_smruti_widget_service.dart` is the Dart-side entry point for preparing/pushing widget content from either platform.
- **iOS notification service extension** (`ios/ImageNotification/`) — renders images inside push notifications (rich FCM notifications) on iOS; separate Xcode target from the main app.
- **Shorebird** (code push) — see `SHOREBIRD.md` for the full release/patch workflow. Key constraint: Dart-only changes are patchable over-the-air; any native code, plugin, asset, or engine version change requires a new store release.

### Analytics (Mixpanel)

`lib/services/analytics_service.dart` + `AnalyticsRouteObserver` (wired in `main.dart`) auto-track screen views. See `MIXPANEL.md` for the full event dictionary and PII rules — authentication and diary events deliberately exclude phone numbers, emails, names, OTPs, diary text, tags, and precise location. Follow that convention when adding new tracked events.

## Testing conventions

- `test/api/` — pure Dart unit tests for models/helpers (no widget pumping).
- `test/ui/controller/` — controller tests using `Get.testMode = true` and `Get.put`/`Get.reset` in `setUp`/`tearDown`.
- Widget tests that need a controller isolate it by subclassing the real controller and overriding network/storage-touching methods as no-ops (see `test/widget_test.dart` for the pattern) rather than mocking `ApiClient` directly.

## Conventions and gotchas

- `lib/healper_service/` is a real, intentional directory name (typo preserved to match existing imports) — don't "fix" it.
- Storage keys all live centrally in `StorageKeys` (`lib/utils/storage_helper.dart`); add new persisted keys there rather than using raw string literals.
- `StorageHelper.clearStorage()` preserves a small allowlist (tutorial-seen flag, last-used mobile number/country code, dark mode) across logout — extend that allowlist deliberately if a new setting should survive logout.
- `ApiEndpoints.mainDomain` resolves at runtime: `API_BASE_URL` dart-define > release-mode production domain > local dev domain (`10.0.2.2:8000`, i.e. Android emulator loopback). There is no separate staging domain switch beyond the dart-define.
