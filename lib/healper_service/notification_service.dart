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

  @pragma('vm:entry-point')
  static Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await setupFlutterNotifications();
  }

  static Future<void> setupFlutterNotifications() async {
    if (_initialised) return;

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      sound: true,
      badge: true,
    );
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await Future.wait(topics.map(FirebaseMessaging.instance.subscribeToTopic));

    final token = Platform.isAndroid
        ? await FirebaseMessaging.instance.getToken()
        : await FirebaseMessaging.instance.getAPNSToken();
    debugPrint('FCM token: $token');

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

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          sound: true,
          badge: true,
        );

    _initialised = true;
  }

  static Future<void> attachForegroundListener() async {
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
