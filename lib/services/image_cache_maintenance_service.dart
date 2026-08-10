import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:harismruti/utils/storage_helper.dart';

class ImageCacheMaintenanceService {
  const ImageCacheMaintenanceService._();

  /// Removes full-resolution files cached by older app versions. This affects
  /// only recreatable network images; downloads and user photos are untouched.
  static Future<void> compactLegacyCacheOnce() async {
    final alreadyCompacted = StorageHelper.getValue<bool>(
      key: StorageKeys.compactImageCacheMigrated,
      defaultValue: false,
    );
    if (alreadyCompacted == true) return;

    try {
      await DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      StorageHelper.setValue(
        key: StorageKeys.compactImageCacheMigrated,
        value: true,
      );
    } catch (_) {
      // Retry on the next launch if Android temporarily has the cache locked.
    }
  }
}
