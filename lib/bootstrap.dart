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
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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

  await NotificationService.setupFlutterNotifications();
  NotificationService.attachForegroundListener();
  NotificationService.listenForInitialAndOpenedApp();
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
