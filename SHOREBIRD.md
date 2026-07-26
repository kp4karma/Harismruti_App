# HariSmruti Shorebird workflow

This project uses Shorebird app ID
`c46e42b3-37fe-4c81-a659-01d4f4c51bd6`.

## Runtime behavior

- The Shorebird engine performs its normal background check at launch.
- The app also checks after its first frame and whenever it returns to the
  foreground (at most once every 15 minutes).
- When a stable patch is available, the app downloads it without blocking
  startup and shows a banner asking the user to close and reopen the app.
- A patch is activated only after a full app restart. It is not safe to
  hot-restart the Dart layer while native Flutter plugins remain alive.
- Normal `flutter run` and widget tests do not contain the Shorebird engine, so
  the updater intentionally reports itself as unavailable there.

## One-time workstation setup

The CLI is installed at:

```powershell
C:\Users\admin\.shorebird\bin\shorebird.ps1
```

Authenticate again if `shorebird account whoami` says the credentials could
not be refreshed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\admin\.shorebird\bin\shorebird.ps1" login
```

Run the readiness check:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\admin\.shorebird\bin\shorebird.ps1" doctor
```

## First store release

Android production signing is configured through the ignored files
`android/key.properties` and `android/upload-keystore.jks`. Back up both files
in a secure password manager or encrypted vault before publishing. Losing the
upload key can interrupt future Play Store and Shorebird release workflows.

Build and register the base release:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\admin\.shorebird\bin\shorebird.ps1" release android
```

Upload the generated AAB to Google Play. Users can only receive patches after
installing a store build created by `shorebird release`.

iOS releases must be built on macOS:

```shell
shorebird release ios
```

## Safe patch workflow

Keep `version: 1.0.0+1` unchanged while patching its corresponding release.
Commit and test the Dart fix, then validate without uploading:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\admin\.shorebird\bin\shorebird.ps1" patch android --dry-run
```

Publish to internal testers first:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\admin\.shorebird\bin\shorebird.ps1" patch android --track staging
```

After validation, publish the same source state to stable:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\admin\.shorebird\bin\shorebird.ps1" patch android
```

Do not bypass native or asset-difference warnings unless the exact generated
diff has been reviewed. Changes to Kotlin, Java, Swift, Objective-C, Flutter
engine version, newly required plugin native code, images, or fonts require a
new store release. Dart-only UI, business logic, API, and state-management
changes are normally patchable.

## Version responsibilities

The existing `/app-version/check` API and Shorebird solve different problems:

- Shorebird applies Dart patches within an already installed store version.
- `/app-version/check` can require a new App Store/Play Store binary when native
  code, assets, permissions, plugins, or the Flutter engine change.

Keep both systems enabled.
