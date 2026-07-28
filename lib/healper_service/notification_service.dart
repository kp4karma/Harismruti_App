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
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/services/notification_history_service.dart';
import 'package:harismruti/ui/view/notification/notification_image_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
class NotificationService {
  static const String developerTopic = 'developer_only';
  static const int _topicSubscriptionVersion = 1;

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

  static List<String> get _topicsToSubscribe => [
    ...topics,
    if (kDebugMode) developerTopic,
  ];

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static AndroidNotificationChannel? _channel;
  static bool _initialised = false;
  static bool _foregroundListenerAttached = false;
  static bool _tokenRefreshListenerAttached = false;

  @pragma('vm:entry-point')
  static Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await StorageHelper.init();
    await setupFlutterNotifications();
    _saveMessage(message);
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
    var appleRegistrationReady = true;
    if (Platform.isIOS || Platform.isMacOS) {
      String? apnsToken;
      for (var attempt = 0; attempt < 20 && apnsToken == null; attempt++) {
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      appleRegistrationReady = apnsToken != null;
      if (apnsToken == null) {
        debugPrint(
          'APNs token is not available yet. Topic subscription will retry '
          'when FCM issues a token.',
        );
      }
    }

    if (!_tokenRefreshListenerAttached) {
      FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
        debugPrint('FCM token refreshed: $fcmToken');
        await _subscribeToTopics(force: true);
      });
      _tokenRefreshListenerAttached = true;
    }

    if (appleRegistrationReady) {
      // getToken() returns the FCM registration token on both Android and iOS.
      // getAPNSToken() is an Apple transport token and must not be sent to FCM.
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        debugPrint('FCM token: $fcmToken');
      } catch (error) {
        debugPrint('Could not obtain FCM token: $error');
      }
      await _subscribeToTopics();
    }

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          sound: true,
          badge: true,
        );

    _initialised = true;
  }

  static Future<void> _subscribeToTopics({bool force = false}) async {
    final savedVersion = StorageHelper.getValue<int>(
      key: StorageKeys.fcmTopicsSubscriptionVersion,
      defaultValue: 0,
    );
    if (!force && savedVersion == _topicSubscriptionVersion) return;

    final subscriptions = <Future<void>>[];
    if (!kDebugMode) {
      // Remove a subscription left behind if this installation was upgraded
      // from a developer build to a release build.
      subscriptions.add(
        FirebaseMessaging.instance.unsubscribeFromTopic(developerTopic),
      );
    }

    for (final topic in _topicsToSubscribe) {
      subscriptions.add(FirebaseMessaging.instance.subscribeToTopic(topic));
    }

    final results = await Future.wait(
      subscriptions.map((subscription) async {
        try {
          await subscription;
          return null;
        } catch (error) {
          return error;
        }
      }),
    );

    for (var index = 0; index < results.length; index++) {
      final error = results[index];
      final isDeveloperUnsubscribe = !kDebugMode && index == 0;
      final topicIndex = index - (!kDebugMode ? 1 : 0);
      final topic = isDeveloperUnsubscribe
          ? developerTopic
          : _topicsToSubscribe[topicIndex];
      if (error == null) {
        if (kDebugMode) {
          debugPrint('Subscribed to FCM topic "$topic".');
        }
      } else {
        // One transient subscription failure must not disable the remaining
        // notification topics.
        debugPrint('Could not subscribe to FCM topic "$topic": $error');
      }
    }

    if (results.every((error) => error == null)) {
      StorageHelper.setValue(
        key: StorageKeys.fcmTopicsSubscriptionVersion,
        value: _topicSubscriptionVersion,
      );
    }
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
    _saveMessage(message);
    final notification = message.notification;
    if (notification == null || kIsWeb || _channel == null) return;

    final imageUrl =
        message.data['image_url']?.toString() ??
        notification.android?.imageUrl ??
        notification.apple?.imageUrl;
    ByteArrayAndroidBitmap? bigPicture;
    String? iOSAttachmentPath;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          bigPicture = ByteArrayAndroidBitmap(response.bodyBytes);
          if (Platform.isIOS) {
            final uri = Uri.parse(imageUrl);
            final sourceName = uri.pathSegments.isEmpty
                ? 'notification.jpg'
                : uri.pathSegments.last;
            final extension = sourceName.contains('.')
                ? sourceName.substring(sourceName.lastIndexOf('.'))
                : '.jpg';
            final attachment = File(
              '${Directory.systemTemp.path}'
              '${Platform.pathSeparator}notification-${message.messageId ?? notification.hashCode}'
              '$extension',
            );
            await attachment.writeAsBytes(response.bodyBytes, flush: true);
            iOSAttachmentPath = attachment.path;
          }
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
        iOS: DarwinNotificationDetails(
          attachments: iOSAttachmentPath == null
              ? null
              : [DarwinNotificationAttachment(iOSAttachmentPath)],
        ),
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
    _saveMessage(message);
    final imageUrl = _imageUrl(message);
    if (imageUrl.isNotEmpty) {
      _openImage(imageUrl, message.notification?.title);
      return;
    }
    _navigateFromData(message.data);
  }

  static void openSavedNotification(Map<String, dynamic> entry) {
    final imageUrl = entry['image_url']?.toString().trim() ?? '';
    if (imageUrl.isNotEmpty) {
      _openImage(imageUrl, entry['title']?.toString());
      return;
    }
    final data = entry['data'];
    if (data is Map) {
      _navigateFromData(Map<String, dynamic>.from(data));
    }
  }

  static void _openImage(String imageUrl, String? title) {
    if (Get.key.currentContext == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openImage(imageUrl, title),
      );
      return;
    }
    Get.to(
      () => NotificationImageScreen(imageUrl: imageUrl, title: title),
      transition: Transition.cupertino,
    );
  }

  static void _saveMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = Map<String, dynamic>.from(message.data);
    final imageUrl = _imageUrl(message);
    if (imageUrl.isNotEmpty) data['image_url'] = imageUrl;
    NotificationHistoryService.save(
      id:
          message.messageId ??
          '${notification?.hashCode ?? message.data.hashCode}',
      title:
          notification?.title ??
          message.data['title']?.toString() ??
          'Notification',
      body: notification?.body ?? message.data['body']?.toString() ?? '',
      data: data,
    );
  }

  static String _imageUrl(RemoteMessage message) {
    return message.data['image_url']?.toString().trim() ??
        message.notification?.android?.imageUrl?.trim() ??
        message.notification?.apple?.imageUrl?.trim() ??
        '';
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
