import 'package:flutter/foundation.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/utils/storage_helper.dart';

class DownloadLibraryService {
  DownloadLibraryService._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static List<GalleryPhoto> get savedOriginals {
    final raw = StorageHelper.getValue<List>(
      key: StorageKeys.downloadedPhotos,
      defaultValue: const [],
    );
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map((item) => item['photo'])
        .whereType<Map>()
        .map((photo) => GalleryPhoto.fromJson(Map<String, dynamic>.from(photo)))
        .where((photo) => photo.id > 0 && photo.fullUrl.isNotEmpty)
        .toList(growable: false);
  }

  static void recordOriginal(GalleryPhoto photo) {
    final existing =
        StorageHelper.getValue<List>(
          key: StorageKeys.downloadedPhotos,
          defaultValue: const [],
        ) ??
        const [];
    final records = existing
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) {
          final savedPhoto = item['photo'];
          return savedPhoto is! Map || '${savedPhoto['id']}' != '${photo.id}';
        })
        .toList();
    records.insert(0, {
      'kind': 'original',
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'photo': photo.toJson(),
    });
    StorageHelper.setValue(
      key: StorageKeys.downloadedPhotos,
      value: records.take(100).toList(),
    );
    notifyChanged();
  }

  static void notifyChanged() => revision.value++;
}
