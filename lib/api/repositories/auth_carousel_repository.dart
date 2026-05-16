import 'dart:math';

import 'package:harismruti/api/repositories/gallery_repository.dart';
import 'package:harismruti/utils/app_string.dart';

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

      if (urls.isEmpty) return _fallback();

      return AuthCarouselImages(
        imageUrls: urls.take(displayCount).toList(),
        headers: imageHeaders,
      );
    } catch (_) {
      return _fallback();
    }
  }

  AuthCarouselImages _fallback() {
    return AuthCarouselImages(imageUrls: imageUrls);
  }
}
