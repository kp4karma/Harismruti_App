// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/healper_service/notification_service.dart';
import 'package:harismruti/utils/firebase_options.dart';
import 'package:harismruti/utils/storage_helper.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(defaultOrientationsForDevice());

  _configureLoadingUI();
  // MediaKit.ensureInitialized();

  await StorageHelper.init();
  await ApiClient.init();

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

  await Firebase.initializeApp(options: firebaseOptions);

  FirebaseMessaging.onBackgroundMessage(
    NotificationService.firebaseBackgroundHandler,
  );

  try {
    await NotificationService.setupFlutterNotifications();
    await NotificationService.attachForegroundListener();
    NotificationService.listenForInitialAndOpenedApp();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Notification bootstrap failed, continuing without it: $e');
    }
  }
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
