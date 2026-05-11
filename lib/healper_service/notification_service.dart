// notification_service.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:harismruti/utils/firebase_options.dart';

/// Single navigator key so any isolate can push routes.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static AndroidNotificationChannel? _channel;
  static bool _initialised = false;

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Background / terminated handler
  // ─────────────────────────────────────────────────────────────────────────
  @pragma('vm:entry-point')
  static Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await setupFlutterNotifications();
    // _showNotification(message); // show local banner
    _navigateFromData(message.data); // cold-start navigation
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. One-off initialisation (permissions + channel)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> setupFlutterNotifications() async {
    if (_initialised) return;

    // Ask the user (iOS) / register (Android)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      sound: true,
      badge: true,
    );

    // Auto-init FCM and subscribe to a topic
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await FirebaseMessaging.instance.subscribeToTopic('all1');

    // Print token once (handy for Postman tests)
    final token = Platform.isAndroid
        ? await FirebaseMessaging.instance.getToken()
        : await FirebaseMessaging.instance.getAPNSToken();
    debugPrint('🪪  FCM token: $token');

    // High-importance channel (Android 8+)
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

    // iOS: show notifications even when app is foreground
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          sound: true,
          badge: true,
        );

    _initialised = true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Attach foreground listener
  // ─────────────────────────────────────────────────────────────────────────
  static void attachForegroundListener() {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    _plugin.initialize(
      initSettings,
      // Fired when user taps the local notification banner
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        if (resp.payload?.isNotEmpty ?? false) {
          final data = jsonDecode(resp.payload!) as Map<String, dynamic>;
          _navigateFromData(data);
        }
      },
    );

    // FCM -> foreground -> show our own local notification
    FirebaseMessaging.onMessage.listen(_showNotification);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Show local notification
  // ─────────────────────────────────────────────────────────────────────────
  static void _showNotification(RemoteMessage message) {
    final n = message.notification;
    final android = n?.android;
    if (n == null || android == null || kIsWeb) return;

    _plugin.show(
      n.hashCode, // id
      n.title, // title
      n.body, // body
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel!.id,
          _channel!.name,
          channelDescription: _channel!.description,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data), // 🔑 pass data so tap can navigate
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5. Centralised navigation helper
  // ─────────────────────────────────────────────────────────────────────────
  @pragma('vm:entry-point')
  static void _navigateFromData(Map<String, dynamic> data) {
    switch (data['screen'].toString()) {
      case 'Add New Screen':
        break;
      default:
        log('🔔 Unknown screen key: ${data['screen']}');
    }
  }

  // Wrapper so existing FCM handlers call the new helper
  static void _navigateFromMessage(RemoteMessage m) =>
      _navigateFromData(m.data);

  // ─────────────────────────────────────────────────────────────────────────
  // 6. Listen for taps from background / terminated state
  // ─────────────────────────────────────────────────────────────────────────
  static void listenForInitialAndOpenedApp() {
    // Called when app is launched by tapping a notification
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? msg) {
      if (msg != null) {
        log("🚀 App launched by notification: ${msg.data}");
        _navigateFromMessage(msg); // 🔁 Navigate
      }
    });

    // Called when app is resumed from background by tapping a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      log("🔁 App resumed by notification: ${msg.data}");
      _navigateFromMessage(msg); // 🔁 Navigate
    });
  }
}
