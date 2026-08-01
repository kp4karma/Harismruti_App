import 'dart:convert';
import 'dart:io';

import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/services/deep_link_service.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;

class PhoneSmrutiWidgetService {
  static const providerNames = <String>[
    'SmrutiHomeWidgetProvider',
    'DailyDarshanWidgetProvider',
    'SmrutiStoriesWidgetProvider',
    'FeaturedRecentWidgetProvider',
    'MinimalSmrutiWidgetProvider',
  ];

  static Future<void> prepareAndAdd({
    required List<GalleryPhoto> photos,
    required Map<String, String> imageHeaders,
    required int storyCount,
    required int refreshHours,
    String providerName = 'SmrutiHomeWidgetProvider',
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Adding the phone widget from inside the app is currently available on Android.',
      );
    }

    await _prepareData(
      photos: photos,
      imageHeaders: imageHeaders,
      storyCount: storyCount,
      refreshHours: refreshHours,
    );

    final canPin = await HomeWidget.isRequestPinWidgetSupported() ?? false;
    if (!canPin) {
      throw UnsupportedError(
        'Your launcher does not support adding widgets from inside the app. Long-press the phone Home screen and choose Widgets.',
      );
    }
    if (!providerNames.contains(providerName)) {
      throw ArgumentError.value(providerName, 'providerName');
    }
    await HomeWidget.requestPinWidget(name: providerName);
  }

  static Future<void> syncInstalledWidget({
    required List<GalleryPhoto> photos,
    required Map<String, String> imageHeaders,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final installed = await HomeWidget.getInstalledWidgets();
      if (installed.isEmpty) return;
      final count =
          StorageHelper.getValue<int>(
            key: StorageKeys.smrutiStoryCount,
            defaultValue: 8,
          ) ??
          8;
      final refreshHours =
          StorageHelper.getValue<int>(
            key: StorageKeys.smrutiStoryRefreshHours,
            defaultValue: 1,
          ) ??
          1;
      await _prepareData(
        photos: photos,
        imageHeaders: imageHeaders,
        storyCount: count,
        refreshHours: refreshHours,
      );
    } catch (_) {
      // Gallery loading must not fail because a launcher widget cannot sync.
    }
  }

  static Future<void> _prepareData({
    required List<GalleryPhoto> photos,
    required Map<String, String> imageHeaders,
    required int storyCount,
    required int refreshHours,
  }) async {
    final candidates = _uniquePhotos(photos)
        .where((photo) => photo.id > 0 && photo.thumbnailUrl.isNotEmpty)
        .take(storyCount)
        .toList(growable: false);
    if (candidates.isEmpty) {
      throw StateError('No Smrutis are available for the phone widget.');
    }

    final stories = <Map<String, String>>[];
    for (var index = 0; index < candidates.length; index++) {
      final photo = candidates[index];
      try {
        final response = await http.get(
          Uri.parse(photo.thumbnailUrl),
          headers: imageHeaders,
        );
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final path = await HomeWidget.saveFile(
          'smruti_story_$index',
          response.bodyBytes,
          extension: 'jpg',
        );
        stories.add({
          'image': path,
          'title': _label(photo),
          'uri': DeepLinkService.photoUri(photo).toString(),
        });
      } catch (_) {
        // A single unavailable thumbnail should not prevent the widget from
        // being created with the remaining cached stories.
      }
    }
    if (stories.isEmpty) {
      throw StateError('Smruti thumbnails could not be prepared.');
    }
    // Remove files left behind when the user reduces the story count.
    for (var index = stories.length; index < 12; index++) {
      await HomeWidget.saveWidgetData<String>('smruti_story_$index', null);
    }

    await HomeWidget.saveWidgetData<String>(
      'smruti_stories',
      jsonEncode(stories),
    );
    await HomeWidget.saveWidgetData<int>('smruti_refresh_hours', refreshHours);
    for (final providerName in providerNames) {
      await HomeWidget.updateWidget(name: providerName);
    }
  }

  static Future<void> markNotificationReceived() async {
    if (!Platform.isAndroid) return;
    try {
      await HomeWidget.saveWidgetData<int>(
        'smruti_notification_at',
        DateTime.now().millisecondsSinceEpoch,
      );
      for (final providerName in providerNames) {
        await HomeWidget.updateWidget(name: providerName);
      }
    } catch (_) {
      // Notifications must still be delivered if a launcher does not support
      // widgets or the widget plugin is unavailable in a background isolate.
    }
  }

  static List<GalleryPhoto> _uniquePhotos(Iterable<GalleryPhoto> photos) {
    final seen = <String>{};
    return photos
        .where((photo) {
          final key = photo.id > 0 ? 'id:${photo.id}' : photo.thumbnailUrl;
          return key.isNotEmpty && seen.add(key);
        })
        .toList(growable: false);
  }

  static String _label(GalleryPhoto photo) {
    for (final value in [
      photo.title,
      photo.smrutiWith,
      photo.darshanOf,
      photo.location,
    ]) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return 'Smruti';
  }
}
