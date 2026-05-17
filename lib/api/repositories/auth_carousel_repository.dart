import 'dart:math';

import 'package:harismruti/api/repositories/gallery_repository.dart';
import 'package:harismruti/utils/storage_helper.dart';

class AuthCarouselImages {
  final List<String> imageUrls;
  final Map<String, String> headers;

  const AuthCarouselImages({required this.imageUrls, this.headers = const {}});
}

class AuthCarouselRepository {
  AuthCarouselRepository({GalleryRepository? galleryRepository})
    : _galleryRepository = galleryRepository ?? const GalleryRepository();

  final GalleryRepository _galleryRepository;

  Map<String, String> get imageHeaders => _galleryRepository.imageHeaders;

  AuthCarouselImages? getCachedRecentImages() {
    final urls = StorageHelper.getValue<List>(
      key: StorageKeys.authCarouselImages,
    );
    if (urls == null || urls.isEmpty) return null;

    return AuthCarouselImages(
      imageUrls: urls
          .map((url) => url.toString())
          .where((url) => url.isNotEmpty)
          .toList(),
      headers: imageHeaders,
    );
  }

  Future<AuthCarouselImages> getRandomRecentImages({
    int recentLimit = 50,
    int displayCount = 5,
  }) async {
    try {
      final photos = await _galleryRepository.getRecent(perPage: recentLimit);
      final urls =
          photos
              .map((photo) => photo.thumbnailUrl)
              .where((url) => url.isNotEmpty)
              .toSet()
              .toList()
            ..shuffle(Random());

      if (urls.isEmpty) return AuthCarouselImages(imageUrls: const []);

      final selectedUrls = urls.take(displayCount).toList();
      StorageHelper.setValue(
        key: StorageKeys.authCarouselImages,
        value: selectedUrls,
      );

      return AuthCarouselImages(imageUrls: selectedUrls, headers: imageHeaders);
    } catch (_) {
      return getCachedRecentImages() ?? AuthCarouselImages(imageUrls: const []);
    }
  }
}
