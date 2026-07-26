import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:harismruti/utils/app_routes.dart';
import 'package:harismruti/utils/firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
class NotificationService {
  static const List<String> topics = [
    'recent',
    'smruti_with',
    'darshan_of',
    'location',
    'smruti_category',
    'smruti_of',
    'year',
    'my_smruti',
    'my_diary',
    'my_favorite',
    'my_collection',
  ];

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static AndroidNotificationChannel? _channel;
  static bool _initialised = false;
  static bool _foregroundListenerAttached = false;

  @pragma('vm:entry-point')
  static Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await setupFlutterNotifications();
  }

  static Future<void> setupFlutterNotifications() async {
    if (_initialised) return;

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      sound: true,
      badge: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Notification permission was denied by the user.');
    }
    await FirebaseMessaging.instance.setAutoInitEnabled(true);

    _channel = const AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'Channel for important notifications',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel!);

    // On Apple devices FCM cannot create a token or subscribe to topics until
    // APNs has registered the app. Registration may complete shortly after the
    // permission prompt, so give it a small bounded wait.
    if (Platform.isIOS || Platform.isMacOS) {
      String? apnsToken;
      for (var attempt = 0; attempt < 10 && apnsToken == null; attempt++) {
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      if (apnsToken == null) {
        debugPrint(
          'APNs token is not available yet; FCM setup will retry next launch.',
        );
      }
    }

    // getToken() returns the FCM registration token on both Android and iOS.
    // getAPNSToken() is an Apple transport token and must not be sent to FCM.
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM token: $fcmToken');
    } catch (error) {
      debugPrint('Could not obtain FCM token: $error');
    }

    for (final topic in topics) {
      try {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      } catch (error) {
        // One transient subscription failure must not disable all notification
        // listeners and foreground presentation.
        debugPrint('Could not subscribe to FCM topic "$topic": $error');
      }
    }

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          sound: true,
          badge: true,
        );

    _initialised = true;
  }

  static Future<void> attachForegroundListener() async {
    if (_foregroundListenerAttached) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _navigateFromData(jsonDecode(payload) as Map<String, dynamic>);
        }
      },
    );

    FirebaseMessaging.onMessage.listen(_showNotification);
    _foregroundListenerAttached = true;
  }

  static Future<void> _showNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || kIsWeb || _channel == null) return;

    final imageUrl =
        message.data['image_url']?.toString() ??
        notification.android?.imageUrl ??
        notification.apple?.imageUrl;
    ByteArrayAndroidBitmap? bigPicture;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          bigPicture = ByteArrayAndroidBitmap(response.bodyBytes);
        }
      } catch (error) {
        debugPrint('Could not load notification image: $error');
      }
    }

    await _plugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel!.id,
          _channel!.name,
          channelDescription: _channel!.description,
          icon: '@mipmap/ic_launcher',
          styleInformation: bigPicture == null
              ? null
              : BigPictureStyleInformation(
                  bigPicture,
                  contentTitle: notification.title,
                  summaryText: notification.body,
                ),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _navigateFromData(Map<String, dynamic> data) {
    if (Get.key.currentContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateFromData(data);
      });
      return;
    }
    final screen = data['screen']?.toString() ?? 'home';
    const supportedHomeSections = {
      'home',
      'recent',
      'smruti_with',
      'darshan_of',
      'location',
      'smruti_category',
      'smruti_of',
      'year',
      'my_smruti',
      'my_diary',
      'my_favorite',
      'my_collection',
    };
    if (supportedHomeSections.contains(screen)) {
      Get.offAllNamed(
        AppRoutes.home,
        arguments: {
          'notification_screen': screen,
          'photo_id': data['photo_id']?.toString(),
        },
      );
      return;
    }
    log('Unknown notification screen key: $screen');
  }

  static void _navigateFromMessage(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  static void listenForInitialAndOpenedApp() {
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _navigateFromMessage(message);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromMessage);
  }
}
