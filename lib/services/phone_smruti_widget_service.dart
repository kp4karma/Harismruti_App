import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/services/deep_link_service.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;

class PhoneSmrutiWidgetService {
  static const _androidPackage = 'org.hp.harismruti';
  static const _iosAppGroup = 'group.org.hp.harismruti.widgets';
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
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError(
        'Home screen widgets are not supported on this device.',
      );
    }

    if (!providerNames.contains(providerName)) {
      throw ArgumentError.value(providerName, 'providerName');
    }
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(_iosAppGroup);
    }

    await _prepareData(
      photos: photos,
      imageHeaders: imageHeaders,
      storyCount: storyCount,
      refreshHours: refreshHours,
      providerName: providerName,
    );

    if (Platform.isIOS) {
      // iOS does not allow apps to pin widgets programmatically. Data is now
      // ready for the user to add this design from the system widget gallery.
      return;
    }

    final canPin = await HomeWidget.isRequestPinWidgetSupported() ?? false;
    if (!canPin) {
      throw UnsupportedError(
        'Your launcher does not support adding widgets from inside the app. Long-press the phone Home screen and choose Widgets.',
      );
    }
    await HomeWidget.requestPinWidget(
      name: providerName,
      androidName: providerName,
      qualifiedAndroidName: '$_androidPackage.$providerName',
    );
  }

  static Future<void> syncInstalledWidget({
    required Map<String, List<GalleryPhoto>> photoSources,
    required Map<String, String> imageHeaders,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(_iosAppGroup);
      } else {
        final installed = await HomeWidget.getInstalledWidgets();
        if (installed.isEmpty) return;
      }
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
      for (final providerName in providerNames) {
        await _prepareData(
          photos: photoSources[providerName] ?? const [],
          imageHeaders: imageHeaders,
          storyCount: count,
          refreshHours: refreshHours,
          providerName: providerName,
        );
      }
    } catch (_) {
      // Gallery loading must not fail because a launcher widget cannot sync.
    }
  }

  static Future<void> _prepareData({
    required List<GalleryPhoto> photos,
    required Map<String, String> imageHeaders,
    required int storyCount,
    required int refreshHours,
    required String providerName,
  }) async {
    final candidates = _uniquePhotos(photos)
        .where(
          (photo) =>
              photo.id > 0 &&
              (photo.fullUrl.isNotEmpty || photo.thumbnailUrl.isNotEmpty),
        )
        .take(storyCount)
        .toList(growable: false);
    if (candidates.isEmpty) {
      throw StateError('No Smrutis are available for the phone widget.');
    }

    final stories = <Map<String, String>>[];
    for (var index = 0; index < candidates.length; index++) {
      final photo = candidates[index];
      try {
        final imageBytes = await _widgetImageBytes(photo, imageHeaders);
        if (imageBytes == null) continue;
        final path = await HomeWidget.saveFile(
          '${providerName}_smruti_story_$index',
          imageBytes,
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
      await HomeWidget.saveWidgetData<String>(
        '${providerName}_smruti_story_$index',
        null,
      );
    }

    await HomeWidget.saveWidgetData<String>(
      'smruti_stories_$providerName',
      jsonEncode(stories),
    );
    await HomeWidget.saveWidgetData<int>('smruti_refresh_hours', refreshHours);
    await HomeWidget.updateWidget(
      name: providerName,
      androidName: providerName,
      qualifiedAndroidName: '$_androidPackage.$providerName',
      iOSName: providerName,
    );
  }

  static Future<void> markNotificationReceived() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      if (Platform.isIOS) await HomeWidget.setAppGroupId(_iosAppGroup);
      await HomeWidget.saveWidgetData<int>(
        'smruti_notification_at',
        DateTime.now().millisecondsSinceEpoch,
      );
      for (final providerName in providerNames) {
        await HomeWidget.updateWidget(
          name: providerName,
          androidName: providerName,
          qualifiedAndroidName: '$_androidPackage.$providerName',
          iOSName: providerName,
        );
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

  static Future<Uint8List?> _widgetImageBytes(
    GalleryPhoto photo,
    Map<String, String> imageHeaders,
  ) async {
    final urls = <String>{
      if (photo.fullUrl.isNotEmpty) photo.fullUrl,
      if (photo.thumbnailUrl.isNotEmpty) photo.thumbnailUrl,
    };
    for (final url in urls) {
      try {
        final response = await http.get(Uri.parse(url), headers: imageHeaders);
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        return FlutterImageCompress.compressWithList(
          response.bodyBytes,
          minWidth: 900,
          minHeight: 900,
          quality: 86,
          format: CompressFormat.jpeg,
        );
      } catch (_) {
        // Fall back to the next available rendition.
      }
    }
    return null;
  }
}
