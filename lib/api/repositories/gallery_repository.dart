import 'package:flutter/foundation.dart';
import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/api/api_endpoints.dart';
import 'package:harismruti/api/models/gallery_models.dart';

class GalleryRepository {
  const GalleryRepository();

  Map<String, String> get imageHeaders {
    if (ApiEndpoints.mobileApiKey.isEmpty) return const {};
    return  {'X-API-Key': ApiEndpoints.mobileApiKey};
  }

  Future<GalleryHomeBundle> getHomeBundle({int samples = 4}) async {
    try {
      final response = await ApiClient.get(
        ApiEndpoints.home,
        queryParams: {'samples': samples},
      );
      final bundle = GalleryHomeBundle.fromJson(response.data);
      return await _fillMissingHomeSections(bundle, samples: samples);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Home bundle failed, loading sections separately: $error');
      }
      return _loadHomeSectionsSeparately(samples: samples);
    }
  }

  Future<List<GalleryPhoto>> getRecent({int page = 1, int perPage = 60}) async {
    final response = await ApiClient.get(
      ApiEndpoints.recent,
      queryParams: {'page': page, 'per_page': perPage},
    );
    return GalleryPage.fromJson(response.data, GalleryPhoto.fromJson).items;
  }

  Future<List<GalleryCard>> getCollections({int samples = 4}) async {
    final response = await ApiClient.get(
      ApiEndpoints.collections,
      queryParams: {'samples': samples},
    );
    return GalleryPage.fromJson(
      response.data,
      (raw) => GalleryCard.fromJson(raw, fallbackType: 'collection'),
    ).items;
  }

  Future<List<GalleryCard>> getSmrutiOf({
    String type = 'person',
    int samples = 4,
    int limit = 60,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.smrutiOf,
      queryParams: {'type': type, 'samples': samples, 'limit': limit},
    );
    return GalleryPage.fromJson(
      response.data,
      (raw) => GalleryCard.fromJson(raw, fallbackType: type),
    ).items;
  }

  Future<List<GalleryCard>> getPeople({
    int samples = 4,
    int limit = 60,
    int offset = 0,
    String sort = 'count',
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.people,
      queryParams: {
        'samples': samples,
        'limit': limit,
        'offset': offset,
        'sort': sort,
      },
    );
    return GalleryPage.fromJson(
      response.data,
      (raw) => GalleryCard.fromJson(raw, fallbackType: 'person'),
    ).items;
  }

  Future<List<GalleryPhoto>> getByAttributePhotos({
    required String slug,
    required String value,
    int page = 1,
    int perPage = 60,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.byAttributePhotos(slug),
      queryParams: {'value': value, 'page': page, 'per_page': perPage},
    );
    return GalleryPage.fromJson(response.data, GalleryPhoto.fromJson).items;
  }

  Future<List<GalleryPhoto>> getPersonPhotos({
    required int groupId,
    int page = 1,
    int perPage = 60,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.personPhotos(groupId),
      queryParams: {'page': page, 'per_page': perPage},
    );
    return GalleryPage.fromJson(response.data, GalleryPhoto.fromJson).items;
  }

  Future<GalleryHomeBundle> _fillMissingHomeSections(
    GalleryHomeBundle bundle, {
    required int samples,
  }) async {
    final shouldFetch =
        bundle.recent.isEmpty ||
        bundle.collections.isEmpty ||
        bundle.smrutiOf.isEmpty ||
        bundle.people.isEmpty ||
        bundle.locations.isEmpty ||
        bundle.albums.isEmpty;

    if (!shouldFetch) return bundle;

    final fallback = await _loadHomeSectionsSeparately(samples: samples);
    return bundle.mergeFallback(
      recent: fallback.recent,
      collections: fallback.collections,
      smrutiOf: fallback.smrutiOf,
      locations: fallback.locations,
      albums: fallback.albums,
      people: fallback.people,
      wallpapers: fallback.wallpapers,
    );
  }

  Future<GalleryHomeBundle> _loadHomeSectionsSeparately({
    required int samples,
  }) async {
    Future<T> safe<T>(Future<T> future, T fallback) async {
      try {
        return await future;
      } catch (error) {
        if (kDebugMode) debugPrint('Gallery section request failed: $error');
        return fallback;
      }
    }

    final results = await Future.wait<dynamic>([
      safe(getRecent(perPage: 60), <GalleryPhoto>[]),
      safe(getCollections(samples: samples), <GalleryCard>[]),
      safe(getSmrutiOf(type: 'person', samples: samples), <GalleryCard>[]),
      safe(getSmrutiOf(type: 'location', samples: samples), <GalleryCard>[]),
      safe(getSmrutiOf(type: 'album', samples: samples), <GalleryCard>[]),
      safe(getPeople(samples: samples, limit: 60), <GalleryCard>[]),
      safe(getSmrutiOf(type: 'subject', samples: samples), <GalleryCard>[]),
    ]);

    return GalleryHomeBundle(
      recent: results[0] as List<GalleryPhoto>,
      collections: results[1] as List<GalleryCard>,
      smrutiOf: results[2] as List<GalleryCard>,
      locations: results[3] as List<GalleryCard>,
      albums: results[4] as List<GalleryCard>,
      people: results[5] as List<GalleryCard>,
      wallpapers: results[6] as List<GalleryCard>,
    );
  }
}
