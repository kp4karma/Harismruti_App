import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/api/api_endpoints.dart';
import 'package:harismruti/api/models/gallery_models.dart';

class GalleryRepository {
  const GalleryRepository();

  Map<String, String> get imageHeaders {
    if (ApiEndpoints.mobileApiKey.isEmpty) return const {};
    return {'X-API-Key': ApiEndpoints.mobileApiKey};
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

  Future<List<GalleryFilterGroup>> getFilters({
    int limit = 200,
    Map<String, List<String>> selected = const {},
  }) async {
    final queryParams = <String, dynamic>{'limit': limit};
    selected.forEach((slug, values) {
      if (values.isNotEmpty) queryParams[slug] = values.join(',');
    });
    final response = await ApiClient.get(
      ApiEndpoints.filters,
      queryParams: queryParams,
    );
    return GalleryPage.fromJson(
      response.data,
      GalleryFilterGroup.fromJson,
    ).items;
  }

  Future<GalleryPhotoAttributes> getPhotoAttributes(int photoId) async {
    final response = await ApiClient.get(ApiEndpoints.photoAttributes(photoId));
    return GalleryPhotoAttributes.fromJson(response.data);
  }

  Future<Map<String, dynamic>> getMyLibrary() async {
    final response = await ApiClient.get(ApiEndpoints.myLibrary);
    return asJsonMap(response.data);
  }

  Future<void> addFavorite(int photoId) async {
    await ApiClient.post(ApiEndpoints.myFavorites, data: {'photo_id': photoId});
  }

  Future<void> removeFavorite(int photoId) async {
    await ApiClient.delete(ApiEndpoints.myFavorite(photoId));
  }

  Future<void> addTag({required int photoId, required String tag}) async {
    await ApiClient.post(
      ApiEndpoints.myTags,
      data: {'photo_id': photoId, 'tag': tag},
    );
  }

  Future<void> removeTag({required int photoId, required String tag}) async {
    await ApiClient.delete(ApiEndpoints.myTag(photoId, tag));
  }

  Future<void> addPhotoToCollection({
    required String name,
    required int photoId,
  }) async {
    await ApiClient.post(
      ApiEndpoints.myCollections,
      data: {'name': name, 'photo_id': photoId},
    );
  }

  Future<void> removeCollection(String name) async {
    await ApiClient.delete(ApiEndpoints.myCollection(name));
  }

  Future<Map<String, dynamic>> uploadMyImage({
    required String path,
    required String pose,
  }) async {
    final response = await ApiClient.postMedia(
      ApiEndpoints.myImages,
      data: FormData.fromMap({
        'pose': pose,
        'file': await MultipartFile.fromFile(path),
      }),
    );
    return asJsonMap(response.data);
  }

  Future<void> deleteMyImage(int imageId) async {
    await ApiClient.delete(ApiEndpoints.myImage(imageId));
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

  Future<List<GalleryPhoto>> getFilteredPhotos({
    required Map<String, List<String>> selected,
    int page = 1,
    int perPage = 60,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'per_page': perPage};
    selected.forEach((slug, values) {
      if (values.isNotEmpty) queryParams[slug] = values.join(',');
    });
    final response = await ApiClient.get(
      ApiEndpoints.filteredPhotos,
      queryParams: queryParams,
    );
    return GalleryPage.fromJson(response.data, GalleryPhoto.fromJson).items;
  }

  Future<List<GalleryPhoto>> getCollectionYearPhotos({
    required int year,
    int page = 1,
    int perPage = 60,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.collectionYearPhotos(year),
      queryParams: {'page': page, 'per_page': perPage},
    );
    return GalleryPage.fromJson(response.data, GalleryPhoto.fromJson).items;
  }

  Future<List<GalleryTimeBucket>> getCollectionMonths({
    required int year,
    int samples = 4,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.collectionMonths(year),
      queryParams: {'samples': samples},
    );
    return GalleryPage.fromJson(
      response.data,
      GalleryTimeBucket.fromJson,
    ).items;
  }

  Future<List<GalleryTimeBucket>> getCollectionDays({
    required int year,
    required int month,
    int samples = 4,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.collectionDays(year, month),
      queryParams: {'samples': samples},
    );
    return GalleryPage.fromJson(
      response.data,
      GalleryTimeBucket.fromJson,
    ).items;
  }

  Future<List<GalleryPhoto>> getCollectionDayPhotos({
    required int year,
    required int month,
    required int day,
    int page = 1,
    int perPage = 120,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.collectionDayPhotos(year, month, day),
      queryParams: {'page': page, 'per_page': perPage},
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
        bundle.smrutiWith.isEmpty ||
        bundle.smrutiOf.isEmpty ||
        bundle.people.isEmpty ||
        bundle.locations.isEmpty ||
        bundle.albums.isEmpty ||
        bundle.wallpapers.isEmpty;

    if (!shouldFetch) return bundle;

    final fallback = await _loadHomeSectionsSeparately(samples: samples);
    return bundle.mergeFallback(
      recent: fallback.recent,
      collections: fallback.collections,
      smrutiWith: fallback.smrutiWith,
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
      safe(getSmrutiOf(type: 'with', samples: samples), <GalleryCard>[]),
      safe(getSmrutiOf(type: 'person', samples: samples), <GalleryCard>[]),
      safe(getSmrutiOf(type: 'location', samples: samples), <GalleryCard>[]),
      safe(getSmrutiOf(type: 'album', samples: samples), <GalleryCard>[]),
      safe(getPeople(samples: samples, limit: 60), <GalleryCard>[]),
      safe(getSmrutiOf(type: 'subject', samples: samples), <GalleryCard>[]),
    ]);

    return GalleryHomeBundle(
      recent: results[0] as List<GalleryPhoto>,
      collections: results[1] as List<GalleryCard>,
      smrutiWith: results[2] as List<GalleryCard>,
      smrutiOf: results[3] as List<GalleryCard>,
      locations: results[4] as List<GalleryCard>,
      albums: results[5] as List<GalleryCard>,
      people: results[6] as List<GalleryCard>,
      wallpapers: results[7] as List<GalleryCard>,
    );
  }
}
