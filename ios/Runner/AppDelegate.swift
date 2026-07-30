import Flutter
import FirebaseMessaging
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    // Register explicitly instead of relying only on Firebase's AppDelegate
    // swizzling. This also makes APNs registration failures visible in logs.
    DispatchQueue.main.async {
      application.registerForRemoteNotifications()
    }

    return launched
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    NSLog("APNs registration succeeded: %@", token)
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("APNs registration failed: %@", error.localizedDescription)
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "WallpaperPhotoSaver"
    ) else {
      return
    }
    let wallpaperChannel = FlutterMethodChannel(
      name: "org.hp.harismruti/wallpaper",
      binaryMessenger: registrar.messenger()
    )
    wallpaperChannel.setMethodCallHandler { call, result in
      guard call.method == "saveToPhotos" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String,
        !path.isEmpty
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT",
            message: "A wallpaper image file is required.",
            details: nil
          )
        )
        return
      }

      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        guard status == .authorized || status == .limited else {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "PHOTO_ACCESS_DENIED",
                message: "Allow Photos access to save the wallpaper.",
                details: nil
              )
            )
          }
          return
        }

        PHPhotoLibrary.shared().performChanges {
          PHAssetChangeRequest.creationRequestForAssetFromImage(
            atFileURL: URL(fileURLWithPath: path)
          )
        } completionHandler: { saved, error in
          DispatchQueue.main.async {
            if saved {
              result(true)
            } else {
              result(
                FlutterError(
                  code: "SAVE_PHOTO_FAILED",
                  message: error?.localizedDescription ?? "Unable to save the wallpaper to Photos.",
                  details: nil
                )
              )
            }
          }
        }
      }
    }
  }
}
