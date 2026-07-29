import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/api/api_endpoints.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/utils/storage_helper.dart';

enum GallerySwami { prabodh, hariprasad }

extension GallerySwamiApiValue on GallerySwami {
  String get apiValue => switch (this) {
    GallerySwami.prabodh => 'prabodh',
    GallerySwami.hariprasad => 'hariprasad',
  };
}

class GalleryRepository {
  const GalleryRepository();

  static const String _latestSort = 'latest';
  static const String _descendingOrder = 'desc';
  static GallerySwami activeSwami = GallerySwami.prabodh;

  Map<String, String> get imageHeaders {
    final headers = <String, String>{};
    if (ApiEndpoints.mobileApiKey.isNotEmpty) {
      headers['X-API-Key'] = ApiEndpoints.mobileApiKey;
    }
    final token = StorageHelper.getValue<String>(key: StorageKeys.accessToken);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<GalleryHomeBundle> getHomeBundle({
    int samples = 4,
    bool forceRefresh = false,
  }) async {
    try {
      final response = await ApiClient.get(
        ApiEndpoints.home,
        queryParams: _latestQueryParams({'samples': samples}),
        cacheDuration: const Duration(hours: 1),
        forceRefresh: forceRefresh,
      );
      final bundle = GalleryHomeBundle.fromJson(response.data);
      return await _fillMissingHomeSections(
        _sortHomeBundleNewestFirst(bundle),
        samples: samples,
      );
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
      queryParams: _latestQueryParams({'page': page, 'per_page': perPage}),
    );
    return _sortPhotosNewestFirst(
      GalleryPage.fromJson(response.data, GalleryPhoto.fromJson).items,
    );
  }

  Future<List<GalleryPhoto>> getOnThisDay({
    int limit = 60,
    bool forceRefresh = false,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.onThisDay,
      queryParams: _scopedQueryParams({'limit': limit}),
      cacheDuration: const Duration(hours: 1),
      forceRefresh: forceRefresh,
    );
    return GalleryPage.fromJson(response.data, GalleryPhoto.fromJson).items;
  }

  Future<List<GalleryFilterGroup>> getFilters({
    int limit = 200,
    Map<String, List<String>> selected = const {},
    bool includeDates = false,
  }) async {
    final queryParams = _latestQueryParams({
      'limit': limit,
      if (includeDates) 'include_dates': true,
    });
    final mobile = currentPhoneNumber();
    if (mobile.isNotEmpty) queryParams['mobile'] = mobile;
    selected.forEach((slug, values) {
      if (values.isNotEmpty) queryParams[slug] = values;
    });
    var response = await ApiClient.get(
      ApiEndpoints.filters,
      queryParams: queryParams,
    );
    if (_isHtmlResponse(response.data)) {
      response = await ApiClient.get(
        ApiEndpoints.legacyFilters,
        queryParams: queryParams,
      );
    }
    return GalleryPage.fromJson(
      response.data,
      GalleryFilterGroup.fromJson,
    ).items;
  }

  Future<GalleryPhotoAttributes> getPhotoAttributes(int photoId) async {
    final response = await ApiClient.get(ApiEndpoints.photoAttributes(photoId));
    return GalleryPhotoAttributes.fromJson(response.data);
  }

  Future<GalleryPhoto> getSharedPhoto(String token) async {
    final response = await ApiClient.get(ApiEndpoints.sharedPhoto(token));
    return GalleryPhoto.fromJson(response.data);
  }

  Future<Map<String, dynamic>> getMyLibrary() async {
    final response = await ApiClient.get(
      ApiEndpoints.myLibrary,
      queryParams: _scopedQueryParams(),
    );
    return asJsonMap(response.data);
  }

  Future<Map<String, dynamic>> getMySmruti({
    int offset = 0,
    int limit = 50,
  }) async {
    final mobile = currentPhoneNumber();
    if (mobile.isEmpty) {
      throw Exception('Mobile number is missing from profile.');
    }
    final response = await ApiClient.get(
      ApiEndpoints.mySmruti,
      queryParams: {'mobile': mobile, 'offset': offset, 'limit': limit},
      forceRefresh: true,
    );
    return asJsonMap(response.data);
  }

  Future<Map<String, dynamic>> submitMySmrutiSelfie(String path) async {
    final mobile = currentPhoneNumber();
    if (mobile.isEmpty) {
      throw Exception('Mobile number is missing from profile.');
    }
    final response = await ApiClient.postMedia(
      ApiEndpoints.myFaceSearch,
      data: FormData.fromMap({
        'name': currentUserName(),
        'mobile': mobile,
        'file': await MultipartFile.fromFile(path),
      }),
    );
    return asJsonMap(response.data);
  }

  Future<Map<String, dynamic>> getMySmrutiRequestStatus(int requestId) async {
    final response = await ApiClient.get(
      ApiEndpoints.myFaceSearchStatus(requestId),
    );
    return asJsonMap(response.data);
  }

  Future<Map<String, dynamic>> getMobileFeatures({
    bool forMySmruti = false,
  }) async {
    final mobile = currentPhoneNumber();
    if (mobile.isEmpty) return const {'allow_ignore': false};
    final response = await ApiClient.get(
      ApiEndpoints.mobileFeatures,
      queryParams: {'mobile': mobile, if (forMySmruti) 'context': 'my_smruti'},
    );
    return asJsonMap(response.data);
  }

  Future<Set<int>> ignorePhotos(Iterable<int> photoIds) async {
    final mobile = currentPhoneNumber();
    if (mobile.isEmpty) {
      throw Exception('Mobile number is missing from profile.');
    }
    final response = await ApiClient.post(
      ApiEndpoints.ignoredPhotos,
      data: {'mobile': mobile, 'photo_ids': photoIds.toSet().toList()},
    );
    final data = asJsonMap(response.data);
    return (data['ignored_photo_ids'] is List
            ? data['ignored_photo_ids'] as List
            : const [])
        .map((value) => int.tryParse('$value'))
        .whereType<int>()
        .toSet();
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
    final phoneNumber = currentPhoneNumber();
    final fileName = _serverFileName(path, pose);
    final uploadPath = phoneNumber.isEmpty ? 'path' : 'path/$phoneNumber';
    final response = await ApiClient.postMedia(
      ApiEndpoints.myImages,
      data: FormData.fromMap({
        'pose': pose,
        if (phoneNumber.isNotEmpty) ...{
          'mobile': phoneNumber,
          'phone_number': phoneNumber,
          'folder': phoneNumber,
        },
        'upload_path': uploadPath,
        'server_path': uploadPath,
        'file': await MultipartFile.fromFile(path, filename: fileName),
      }),
    );
    return asJsonMap(response.data);
  }

  String _serverFileName(String path, String pose) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final safePose = pose.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return safePose.isEmpty ? name : '$safePose-$name';
  }

  String currentPhoneNumber() {
    final profileJson = StorageHelper.getValue<String>(
      key: StorageKeys.userProfile,
    );
    if (profileJson == null || profileJson.isEmpty) return '';
    try {
      final decoded = jsonDecode(profileJson);
      if (decoded is Map) {
        for (final key in ['mobile', 'phone', 'phone_number', 'username']) {
          final value = decoded[key]?.toString().trim() ?? '';
          if (value.isNotEmpty && value != 'null') {
            return value.replaceAll(RegExp(r'[^0-9+]'), '');
          }
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to parse stored profile for upload: $error');
      }
    }
    return '';
  }

  String currentUserName() {
    final profileJson = StorageHelper.getValue<String>(
      key: StorageKeys.userProfile,
    );
    if (profileJson != null && profileJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(profileJson);
        if (decoded is Map) {
          for (final key in ['name', 'full_name', 'display_name', 'username']) {
            final value = decoded[key]?.toString().trim() ?? '';
            if (value.isNotEmpty && value != 'null') return value;
          }
        }
      } catch (_) {}
    }
    return 'Harismruti User';
  }

  Future<void> deleteMyImage(int imageId) async {
    await ApiClient.delete(ApiEndpoints.myImage(imageId));
  }

  Future<List<GalleryCard>> getCollections({int samples = 4}) async {
    final response = await ApiClient.get(
      ApiEndpoints.collections,
      queryParams: _latestQueryParams({'samples': samples}),
    );
    return GalleryPage.fromJson(
      response.data,
      (raw) => GalleryCard.fromJson(raw, fallbackType: 'collection'),
    ).items.where((card) => card.hasValue).toList();
  }

  Future<List<GalleryCard>> getSmrutiOf({
    String type = 'person',
    int samples = 4,
    int limit = 60,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.smrutiOf,
      queryParams: _latestQueryParams({
        'type': type,
        'samples': samples,
        'limit': limit,
      }),
    );
    return _sortCardsNewestFirst(
      GalleryPage.fromJson(
        response.data,
        (raw) => GalleryCard.fromJson(raw, fallbackType: type),
      ).items,
    );
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
        'order': _descendingOrder,
        'swami': activeSwami.apiValue,
      },
    );
    return _sortCardsNewestFirst(
      GalleryPage.fromJson(
        response.data,
        (raw) => GalleryCard.fromJson(raw, fallbackType: 'person'),
      ).items,
    );
  }

  Future<List<GalleryPhoto>> getByAttributePhotos({
    required String slug,
    required String value,
    int page = 1,
    int perPage = 60,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.byAttributePhotos(slug),
      queryParams: _latestQueryParams({
        'value': value,
        'page': page,
        'per_page': perPage,
      }),
    );
    return _sortPhotosNewestFirst(
      GalleryPage.fromJson(response.data, GalleryPhoto.fromJson).items,
    );
  }

  Future<List<GalleryPhoto>> getFilteredPhotos({
    required Map<String, List<String>> selected,
    int page = 1,
    int perPage = 60,
  }) async {
    final queryParams = _latestQueryParams({'page': page, 'per_page': perPage});
    final mobile = currentPhoneNumber();
    if (mobile.isNotEmpty) queryParams['mobile'] = mobile;
    selected.forEach((slug, values) {
      if (values.isNotEmpty) queryParams[slug] = values;
    });
    var response = await ApiClient.get(
      ApiEndpoints.filteredPhotos,
      queryParams: queryParams,
    );
    if (_isHtmlResponse(response.data)) {
      response = await ApiClient.get(
        ApiEndpoints.legacyFilteredPhotos,
        queryParams: queryParams,
      );
    }
    return _sortPhotosNewestFirst(
      GalleryPage.fromJson(response.data, GalleryPhoto.fromJson).items,
    );
  }

  Future<List<GalleryPhoto>> getCollectionYearPhotos({
    required int year,
    int page = 1,
    int perPage = 60,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.collectionYearPhotos(year),
      queryParams: _latestQueryParams({'page': page, 'per_page': perPage}),
    );
    return _sortPhotosNewestFirst(
      GalleryPage.fromJson(response.data, GalleryPhoto.fromJson).items,
    );
  }

  Future<List<GalleryTimeBucket>> getCollectionMonths({
    required int year,
    int samples = 4,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.collectionMonths(year),
      queryParams: _latestQueryParams({'samples': samples}),
    );
    return _sortTimeBucketsNewestFirst(
      GalleryPage.fromJson(response.data, GalleryTimeBucket.fromJson).items,
    );
  }

  Future<List<GalleryTimeBucket>> getCollectionDays({
    required int year,
    required int month,
    int samples = 4,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.collectionDays(year, month),
      queryParams: _latestQueryParams({'samples': samples}),
    );
    return _sortTimeBucketsNewestFirst(
      GalleryPage.fromJson(response.data, GalleryTimeBucket.fromJson).items,
    );
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
      queryParams: _latestQueryParams({'page': page, 'per_page': perPage}),
    );
    return _sortPhotosNewestFirst(
      GalleryPage.fromJson(response.data, GalleryPhoto.fromJson).items,
    );
  }

  Future<List<GalleryPhoto>> getPersonPhotos({
    required int groupId,
    int page = 1,
    int perPage = 60,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.personPhotos(groupId),
      queryParams: _latestQueryParams({'page': page, 'per_page': perPage}),
    );
    return _sortPhotosNewestFirst(
      GalleryPage.fromJson(response.data, GalleryPhoto.fromJson).items,
    );
  }

  Map<String, dynamic> _latestQueryParams(Map<String, dynamic> params) {
    return {
      ...params,
      'sort': params['sort'] ?? _latestSort,
      'order': params['order'] ?? _descendingOrder,
      'swami': activeSwami.apiValue,
      'cache_revision': _activeCacheRevision,
    };
  }

  static bool _isHtmlResponse(dynamic data) {
    if (data is! String) return false;
    final normalized = data.trimLeft().toLowerCase();
    return normalized.startsWith('<!doctype html') ||
        normalized.startsWith('<html');
  }

  Map<String, dynamic> _scopedQueryParams([
    Map<String, dynamic> params = const {},
  ]) {
    return {
      ...params,
      'swami': activeSwami.apiValue,
      'cache_revision': _activeCacheRevision,
    };
  }

  int get _activeCacheRevision {
    final revisions = StorageHelper.getValue<Map<dynamic, dynamic>>(
      key: StorageKeys.appSectionCacheRevisions,
    );
    return int.tryParse(revisions?[activeSwami.apiValue]?.toString() ?? '') ??
        0;
  }

  GalleryHomeBundle _sortHomeBundleNewestFirst(GalleryHomeBundle bundle) {
    return GalleryHomeBundle(
      recent: _sortPhotosNewestFirst(bundle.recent),
      collections: bundle.collections.where((card) => card.hasValue).toList(),
      smrutiWith: _sortCardsNewestFirst(bundle.smrutiWith),
      smrutiOf: _sortCardsNewestFirst(bundle.smrutiOf),
      locations: _sortCardsNewestFirst(bundle.locations),
      albums: _sortCardsNewestFirst(bundle.albums),
      subjects: _sortCardsNewestFirst(bundle.subjects),
      people: _sortCardsNewestFirst(bundle.people),
      wallpapers: _sortCardsNewestFirst(bundle.wallpapers),
    );
  }

  List<GalleryPhoto> _sortPhotosNewestFirst(List<GalleryPhoto> photos) {
    final sorted = photos.toList();
    sorted.sort((a, b) {
      final dateCompare = _photoDateMillis(b).compareTo(_photoDateMillis(a));
      if (dateCompare != 0) return dateCompare;
      return b.id.compareTo(a.id);
    });
    return sorted;
  }

  List<GalleryCard> _sortCardsNewestFirst(List<GalleryCard> cards) {
    final sorted = cards.where((card) => card.hasValue).toList();
    sorted.sort((a, b) {
      final dateCompare = _cardDateMillis(b).compareTo(_cardDateMillis(a));
      if (dateCompare != 0) return dateCompare;
      return b.id.compareTo(a.id);
    });
    return sorted;
  }

  List<GalleryTimeBucket> _sortTimeBucketsNewestFirst(
    List<GalleryTimeBucket> buckets,
  ) {
    final sorted = buckets.toList();
    sorted.sort((a, b) {
      final yearCompare = b.year.compareTo(a.year);
      if (yearCompare != 0) return yearCompare;
      final monthCompare = (b.month ?? 0).compareTo(a.month ?? 0);
      if (monthCompare != 0) return monthCompare;
      return (b.day ?? 0).compareTo(a.day ?? 0);
    });
    return sorted;
  }

  int _cardDateMillis(GalleryCard card) {
    var newest = 0;
    for (final photo in card.photos) {
      final photoMillis = _photoDateMillis(photo);
      if (photoMillis > newest) newest = photoMillis;
    }
    return newest;
  }

  int _photoDateMillis(GalleryPhoto photo) {
    return photo.takenAt?.millisecondsSinceEpoch ?? 0;
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
        bundle.subjects.isEmpty;

    if (!shouldFetch) return bundle;

    final fallback = await _loadHomeSectionsSeparately(samples: samples);
    return bundle.mergeFallback(
      recent: fallback.recent,
      collections: fallback.collections,
      smrutiWith: fallback.smrutiWith,
      smrutiOf: fallback.smrutiOf,
      locations: fallback.locations,
      albums: fallback.albums,
      subjects: fallback.subjects,
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
      safe(getSmrutiOf(type: 'subject', samples: samples), <GalleryCard>[]),
      safe(getPeople(samples: samples, limit: 60), <GalleryCard>[]),
    ]);

    return GalleryHomeBundle(
      recent: results[0] as List<GalleryPhoto>,
      collections: results[1] as List<GalleryCard>,
      smrutiWith: results[2] as List<GalleryCard>,
      smrutiOf: results[3] as List<GalleryCard>,
      locations: results[4] as List<GalleryCard>,
      albums: results[5] as List<GalleryCard>,
      subjects: results[6] as List<GalleryCard>,
      people: results[7] as List<GalleryCard>,
    );
  }
}
