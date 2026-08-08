// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/healper_service/notification_service.dart';
import 'package:harismruti/services/analytics_service.dart';
import 'package:harismruti/utils/firebase_options.dart';
import 'package:harismruti/utils/storage_helper.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep enough decoded thumbnails in memory that scrolling back through a
  // gallery does not repeatedly decode/read them. This is especially useful
  // on slow connections because the disk cache is only needed after this
  // warm in-memory layer is exhausted.
  PaintingBinding.instance.imageCache
    ..maximumSize = 240
    ..maximumSizeBytes = 96 * 1024 * 1024;
  _configureLoadingUI();
  // MediaKit.ensureInitialized();

  // These operations are independent. Starting them together shortens the
  // interval before the fully initialized app replaces the startup frame.
  await Future.wait([
    SystemChrome.setPreferredOrientations(defaultOrientationsForDevice()),
    StorageHelper.init(),
    ApiClient.init(),
  ]);
}

/// Notification permissions, token creation, and topic subscriptions can take
/// several seconds on a fresh install. Run them after the first frame so they
/// never hold up the native splash screen or Flutter UI.
Future<void> bootstrapNotifications() async {
  final firebaseOptions = DefaultFirebaseOptions.currentPlatform;
  final hasFirebaseConfig =
      firebaseOptions.apiKey != '---' &&
      firebaseOptions.appId != '---' &&
      firebaseOptions.projectId != '---';

  if (!hasFirebaseConfig) {
    if (kDebugMode) {
      debugPrint(
        'Firebase is not configured yet; skipping notification bootstrap.',
      );
    }
    return;
  }

  try {
    await Firebase.initializeApp(options: firebaseOptions);
    FirebaseMessaging.onBackgroundMessage(
      NotificationService.firebaseBackgroundHandler,
    );
    await NotificationService.setupFlutterNotifications();
    await NotificationService.attachForegroundListener();
    NotificationService.listenForInitialAndOpenedApp();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Notification bootstrap failed, continuing without it: $e');
    }
  }
}

Future<void> bootstrapDeferredServices() async {
  await Future.wait([
    AnalyticsService.instance.initialize(),
    bootstrapNotifications(),
  ]);
}

/// Phones stay portrait-locked (existing behavior, unchanged). Tablets
/// (shortest physical side >= 600dp) are allowed to rotate freely so
/// landscape use is possible on iPad/Android tablets.
///
/// Exposed (not private) so routes that need to temporarily force
/// portrait (e.g. a fixed-layout capture screen) can restore this
/// app-level default afterwards instead of hardcoding a guess.
List<DeviceOrientation> defaultOrientationsForDevice() {
  final view = PlatformDispatcher.instance.views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  final shortestSide = size.shortestSide;

  if (shortestSide >= 600) {
    return [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ];
  }

  return [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];
}

void _configureLoadingUI() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 1000)
    ..loadingStyle = EasyLoadingStyle.custom
    ..indicatorType = EasyLoadingIndicatorType.ring
    ..indicatorSize = 30
    ..radius = 8
    ..textColor = Colors.white
    ..backgroundColor = const Color(0xff933525)
    ..indicatorColor = Colors.white
    ..maskColor = Colors.blue.withAlpha(125)
    ..userInteractions = false
    ..dismissOnTap = false;
}
