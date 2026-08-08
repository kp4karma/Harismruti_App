import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/api/models/app_section_setting.dart';
import 'package:harismruti/api/repositories/gallery_repository.dart';
import 'package:harismruti/services/analytics_service.dart';
import 'package:harismruti/services/phone_smruti_widget_service.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/utils/storage_helper.dart';

const bool kShowFavoriteCountOnImages = false;

class UserPhotoCollection {
  final String name;
  final List<int> photoIds;

  const UserPhotoCollection({required this.name, required this.photoIds});

  factory UserPhotoCollection.fromJson(dynamic raw) {
    if (raw is String) {
      return UserPhotoCollection(name: raw.trim(), photoIds: const []);
    }
    final json = asJsonMap(raw);
    final name =
        json['name']?.toString().trim() ??
        json['collection_name']?.toString().trim() ??
        json['title']?.toString().trim() ??
        '';
    final rawIds = <dynamic>[
      if (json['photo_ids'] is List) ...(json['photo_ids'] as List),
      if (json['photoIds'] is List) ...(json['photoIds'] as List),
      if (json['photos'] is List)
        ...(json['photos'] as List).map((photo) {
          if (photo is Map) {
            return photo['id'] ?? photo['photo_id'] ?? photo['photoId'];
          }
          return photo;
        }),
    ];
    final ids = rawIds
        .map((value) => value is int ? value : int.tryParse(value.toString()))
        .whereType<int>()
        .toSet()
        .toList();
    return UserPhotoCollection(name: name, photoIds: ids);
  }

  Map<String, dynamic> toJson() => {'name': name, 'photo_ids': photoIds};
}

class _GalleryTabSnapshot {
  final GalleryHomeBundle bundle;
  final List<GalleryPhoto> onThisDayPhotos;
  final bool hasLoadedOnThisDay;
  final DateTime loadedAt;
  final int recentPage;
  final bool hasMoreRecentPhotos;

  const _GalleryTabSnapshot({
    required this.bundle,
    required this.onThisDayPhotos,
    required this.hasLoadedOnThisDay,
    required this.loadedAt,
    required this.recentPage,
    required this.hasMoreRecentPhotos,
  });
}

class GalleryController extends GetxController {
  GalleryController({GalleryRepository? repository})
    : _repository = repository ?? const GalleryRepository();

  static const int _recentPerPage = 60;
  static const Duration _slowHomeLoadThreshold = Duration(seconds: 4);

  final GalleryRepository _repository;

  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isSlowConnection = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isRecentPageLoading = false.obs;
  final RxBool hasMoreRecentPhotos = true.obs;
  final Rx<GallerySwami> selectedSwami = GallerySwami.prabodh.obs;

  final RxList<GalleryPhoto> recentPhotos = <GalleryPhoto>[].obs;
  final RxList<GalleryPhoto> onThisDayPhotos = <GalleryPhoto>[].obs;
  final RxList<GalleryCard> collections = <GalleryCard>[].obs;
  final RxList<GalleryCard> smrutiWith = <GalleryCard>[].obs;
  final RxList<GalleryCard> smrutiOf = <GalleryCard>[].obs;
  final RxList<GalleryCard> locations = <GalleryCard>[].obs;
  final RxList<GalleryCard> allPlaces = <GalleryCard>[].obs;

  List<GalleryCard> get placeCards =>
      allPlaces.isNotEmpty ? allPlaces : locations;
  final RxList<GalleryCard> albums = <GalleryCard>[].obs;
  final RxList<GalleryCard> subjects = <GalleryCard>[].obs;
  final RxList<GalleryCard> people = <GalleryCard>[].obs;
  final RxList<GalleryCard> wallpapers = <GalleryCard>[].obs;
  final RxList<GalleryFilterGroup> filters = <GalleryFilterGroup>[].obs;
  final RxBool areFiltersLoading = false.obs;
  final RxBool areFiltersRefreshing = false.obs;
  final RxBool isMyLibraryLoading = false.obs;
  final RxBool areMySmrutiFiltersLoading = false.obs;
  final RxString filtersError = ''.obs;
  final RxSet<int> favoritePhotoIds = <int>{}.obs;
  final RxMap<int, GalleryPhoto> savedPhotos = <int, GalleryPhoto>{}.obs;
  final RxMap<int, List<String>> userTags = <int, List<String>>{}.obs;
  final RxList<String> userTagNames = <String>[].obs;
  final RxList<GalleryPhoto> mySmrutiPhotos = <GalleryPhoto>[].obs;
  final RxList<GalleryFilterOption> mySmrutiYearOptions =
      <GalleryFilterOption>[].obs;
  final RxList<UserPhotoCollection> userCollections =
      <UserPhotoCollection>[].obs;

  DateTime? _lastLoadedAt;
  Future<void>? _inFlightLoad;
  bool _hasLoadedOnThisDay = false;
  int _recentPage = 1;
  int _favoriteMutationVersion = 0;
  final Map<GallerySwami, _GalleryTabSnapshot> _tabSnapshots = {};
  final Map<GallerySwami, List<GalleryFilterGroup>> _filterSnapshots = {};
  int _filtersRequestId = 0;
  int _mySmrutiFiltersRequestId = 0;
  int _mySmrutiYearsRequestId = 0;
  int _allPlacesRequestId = 0;
  int _swamiSelectionVersion = 0;

  Future<void> loadAllPlaces() async {
    final requestId = ++_allPlacesRequestId;
    final requestedSwami = selectedSwami.value;
    try {
      final cards = await _repository.getSmrutiOf(
        type: 'location',
        samples: 4,
        limit: 500,
        unlimited: true,
      );
      if (requestId != _allPlacesRequestId ||
          requestedSwami != selectedSwami.value) {
        return;
      }
      // The endpoint is already scoped by Swami. Applying the client date
      // filter again can incorrectly discard cards when sample metadata differs
      // from the server's coalesced visibility date.
      allPlaces.assignAll(_orderCards('location', cards));
    } catch (error) {
      if (kDebugMode) debugPrint('Complete place list request failed: $error');
    }
  }

  Map<String, String> get imageHeaders => _repository.imageHeaders;
  bool get hasAnyData =>
      recentPhotos.isNotEmpty ||
      onThisDayPhotos.isNotEmpty ||
      collections.isNotEmpty ||
      smrutiWith.isNotEmpty ||
      smrutiOf.isNotEmpty ||
      locations.isNotEmpty ||
      albums.isNotEmpty ||
      subjects.isNotEmpty ||
      people.isNotEmpty ||
      wallpapers.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    _restorePersistedSwami();
    _restoreSnapshots();
    loadMyLibrary();
    // Render a recent persisted snapshot immediately without spending network
    // data. Stale or missing snapshots are refreshed in the background.
    final snapshot = _tabSnapshots[selectedSwami.value];
    unawaited(
      _loadAndSyncHomeWidget(
        force: snapshot == null || _isSnapshotStale(snapshot),
      ),
    );
  }

  Future<void> _loadAndSyncHomeWidget({required bool force}) async {
    await loadHome(force: force);
    final recent = recentPhotos.toList(growable: false);
    final onThisDay = onThisDayPhotos.isNotEmpty
        ? onThisDayPhotos.toList(growable: false)
        : recent;
    final withPhotos = smrutiWith.isNotEmpty
        ? smrutiWith.expand((card) => card.photos).toList(growable: false)
        : recent;
    final favorites = favoritePhotos.isNotEmpty ? favoritePhotos : recent;
    await PhoneSmrutiWidgetService.syncInstalledWidget(
      photoSources: {
        'SmrutiHomeWidgetProvider': _preferWidgetOrientation(
          recent,
          landscape: true,
        ),
        'DailyDarshanWidgetProvider': _preferWidgetOrientation(
          onThisDay,
          landscape: true,
        ),
        'SmrutiStoriesWidgetProvider': _preferWidgetOrientation(
          withPhotos,
          landscape: false,
        ),
        'FeaturedRecentWidgetProvider': _preferWidgetOrientation(
          recent,
          landscape: true,
        ),
        'MinimalSmrutiWidgetProvider': _preferWidgetOrientation(
          favorites,
          landscape: true,
        ),
      },
      imageHeaders: imageHeaders,
    );
  }

  List<GalleryPhoto> _preferWidgetOrientation(
    Iterable<GalleryPhoto> photos, {
    required bool landscape,
  }) {
    final all = photos
        .where((photo) => photo.thumbnailUrl.isNotEmpty)
        .toList(growable: false);
    final preferred = all
        .where((photo) {
          final width = photo.width ?? 0;
          final height = photo.height ?? 0;
          if (width <= 0 || height <= 0) return false;
          return landscape ? width >= height : height > width;
        })
        .toList(growable: false);
    return preferred.isNotEmpty ? preferred : all;
  }

  void _restorePersistedSwami() {
    final stored = StorageHelper.getValue<String>(
      key: StorageKeys.selectedSwami,
    );
    if (stored == null) return;
    for (final swami in GallerySwami.values) {
      if (swami.apiValue == stored) {
        selectedSwami.value = swami;
        GalleryRepository.activeSwami = swami;
        return;
      }
    }
  }

  bool isFavorite(int photoId) => favoritePhotoIds.contains(photoId);

  int get favoriteCount => favoritePhotoIds.length;

  List<GalleryPhoto> get favoritePhotos => favoritePhotoIds
      .map((id) => savedPhotos[id])
      .whereType<GalleryPhoto>()
      .where(isPhotoInSelectedSwami)
      .toList();

  List<String> tagsForPhoto(int photoId) => userTags[photoId] ?? const [];
  List<String> get allUserTags {
    final tags = {
      ...userTagNames,
      ...userTags.values.expand((values) => values),
    }.toList();
    tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return tags;
  }

  List<GalleryFilterGroup> get filtersWithUserTags =>
      filtersWithUserTagsForSelection(const {});

  List<GalleryFilterGroup> filtersWithUserTagsForSelection(
    Map<String, List<String>> selected,
  ) {
    final customGroups = _buildMySmrutiFilterGroups(selected);
    final userTagGroup = _buildUserTagFilterGroup();
    return [
      ...customGroups,
      if (userTagGroup != null) userTagGroup,
      ...filters,
    ];
  }

  Future<void> handleAuthChanged() async {
    if (!StorageHelper.isLogin()) {
      favoritePhotoIds.clear();
      savedPhotos.clear();
      userTags.clear();
      userTagNames.clear();
      userCollections.clear();
      mySmrutiPhotos.clear();
      mySmrutiYearOptions.clear();
      return;
    }
    await loadMyLibrary();
  }

  List<String> get allUserCollectionNames {
    final names = userCollections.map((collection) => collection.name).toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  List<String> collectionNamesForPhoto(int photoId) {
    return userCollections
        .where((collection) => collection.photoIds.contains(photoId))
        .map((collection) => collection.name)
        .toList();
  }

  List<GalleryPhoto> photosForCollection(UserPhotoCollection collection) {
    return collection.photoIds
        .map((id) => savedPhotos[id])
        .whereType<GalleryPhoto>()
        .where(isPhotoInSelectedSwami)
        .toList();
  }

  bool isPhotoInSelectedSwami(GalleryPhoto photo) {
    return _isPhotoInSwami(photo, selectedSwami.value);
  }

  bool _isPhotoInSwami(GalleryPhoto photo, GallerySwami swami) {
    final date = photo.eventDate ?? photo.takenAt;
    if (date == null) return false;
    final calendarDate = DateTime(date.year, date.month, date.day);
    final cutoff = DateTime(2022, 4, 21);
    return swami == GallerySwami.hariprasad
        ? calendarDate.isBefore(cutoff)
        : !calendarDate.isBefore(cutoff);
  }

  List<GalleryPhoto> _photosForSwami(
    Iterable<GalleryPhoto> photos,
    GallerySwami swami,
  ) => photos.where((photo) => _isPhotoInSwami(photo, swami)).toList();

  List<GalleryPhoto> _previewPhotosForSwami(
    Iterable<GalleryPhoto> photos,
    GallerySwami swami,
  ) {
    return photos.where((photo) {
      // Collection preview payloads currently contain only an id and URLs.
      // Their parent bucket has already been checked against the selected
      // Swami, so an absent date must not make an otherwise valid cover vanish.
      final date = photo.eventDate ?? photo.takenAt;
      return date == null || _isPhotoInSwami(photo, swami);
    }).toList();
  }

  List<GalleryCard> _cardsForSwami(
    Iterable<GalleryCard> cards,
    GallerySwami swami,
  ) {
    return cards
        .map((card) {
          final photos = _photosForSwami(card.photos, swami);
          if (card.photos.isNotEmpty && photos.isEmpty) return null;
          return GalleryCard(
            id: card.id,
            title: card.title,
            subtitle: card.subtitle,
            type: card.type,
            value: card.value,
            count: card.count,
            locationCount: card.locationCount,
            tagCount: card.tagCount,
            faceId: card.faceId,
            latitude: card.latitude,
            longitude: card.longitude,
            photos: photos,
          );
        })
        .whereType<GalleryCard>()
        .toList();
  }

  List<GalleryCard> _collectionCardsForSwami(
    Iterable<GalleryCard> cards,
    GallerySwami swami,
  ) {
    const cutoffYear = 2022;

    return cards
        .where((card) {
          final year = int.tryParse(card.value) ?? int.tryParse(card.title);
          if (year == null) return true;
          if (year == cutoffYear) return true;
          return swami == GallerySwami.hariprasad
              ? year < cutoffYear
              : year > cutoffYear;
        })
        .map(
          (card) => GalleryCard(
            id: card.id,
            title: card.title,
            subtitle: card.subtitle,
            type: card.type,
            value: card.value,
            count: card.count,
            locationCount: card.locationCount,
            tagCount: card.tagCount,
            faceId: card.faceId,
            latitude: card.latitude,
            longitude: card.longitude,
            photos: _previewPhotosForSwami(card.photos, swami),
          ),
        )
        .toList();
  }

  List<GalleryTimeBucket> _timeBucketsForSwami(
    Iterable<GalleryTimeBucket> buckets,
    GallerySwami swami,
  ) {
    const cutoffYear = 2022;
    const cutoffMonth = 4;
    const cutoffDay = 21;

    bool includesSelectedPeriod(GalleryTimeBucket bucket) {
      if (bucket.year != cutoffYear) {
        return swami == GallerySwami.hariprasad
            ? bucket.year < cutoffYear
            : bucket.year > cutoffYear;
      }
      final month = bucket.month;
      if (month == null) return true;
      if (month != cutoffMonth) {
        return swami == GallerySwami.hariprasad
            ? month < cutoffMonth
            : month > cutoffMonth;
      }
      final day = bucket.day;
      if (day == null) return true;
      return swami == GallerySwami.hariprasad
          ? day < cutoffDay
          : day >= cutoffDay;
    }

    return buckets
        .where(includesSelectedPeriod)
        .map((bucket) {
          final photos = _previewPhotosForSwami(bucket.photos, swami);
          return GalleryTimeBucket(
            year: bucket.year,
            month: bucket.month,
            day: bucket.day,
            count: bucket.count,
            locationCount: bucket.locationCount,
            tagCount: bucket.tagCount,
            photos: photos,
          );
        })
        .whereType<GalleryTimeBucket>()
        .toList();
  }

  Future<void> selectSwami(int index) async {
    final next = index == 1 ? GallerySwami.hariprasad : GallerySwami.prabodh;
    if (selectedSwami.value == next) return;
    final selectionVersion = ++_swamiSelectionVersion;

    selectedSwami.value = next;
    GalleryRepository.activeSwami = next;
    StorageHelper.setValue(
      key: StorageKeys.selectedSwami,
      value: next.apiValue,
    );
    if (Get.isRegistered<SmrutiSectionController>()) {
      Get.find<SmrutiSectionController>().applyCachedGlobalSettings(
        next.apiValue,
      );
    }
    AnalyticsService.instance.track(
      'Gallery Persona Selected',
      properties: {'persona': next.apiValue},
    );

    final snapshot = _tabSnapshots[next];
    if (snapshot != null) {
      _applySnapshot(snapshot);
    } else {
      _lastLoadedAt = null;
      _recentPage = 1;
      hasMoreRecentPhotos.value = true;
      _clearGallerySections();
    }
    filters.assignAll(_filterSnapshots[next] ?? const []);

    final pendingLoad = _inFlightLoad;
    if (pendingLoad != null) await pendingLoad;
    if (selectionVersion != _swamiSelectionVersion ||
        selectedSwami.value != next) {
      return;
    }

    await Future.wait([
      loadMyLibrary(),
      loadHome(force: snapshot == null || _isSnapshotStale(snapshot)),
    ]);
  }

  Future<void> loadMyLibrary() async {
    final favoriteVersionAtRequest = _favoriteMutationVersion;
    if (!StorageHelper.isLogin()) {
      favoritePhotoIds.clear();
      userTags.clear();
      userTagNames.clear();
      userCollections.clear();
      return;
    }
    isMyLibraryLoading.value = true;
    try {
      final data = await _repository.getMyLibrary();
      final favoriteIds =
          (data['favorite_photo_ids'] is List
                  ? data['favorite_photo_ids'] as List
                  : const [])
              .map(
                (value) =>
                    value is int ? value : int.tryParse(value.toString()),
              )
              .whereType<int>()
              .toSet();

      final photos =
          (data['photos'] is List ? data['photos'] as List : const [])
              .map(GalleryPhoto.fromJson)
              .where((photo) => photo.id > 0)
              .toList();
      for (final photo in photos) {
        savedPhotos[photo.id] = photo;
      }

      final parsedTags = _parseUserTags(
        data['tags'] ?? data['user_tags'] ?? data['custom_tags'],
      );
      final parsedTagNames = _parseTagNames(
        data['tag_names'] ?? data['all_tags'] ?? data['custom_tag_names'],
      );

      final collections = _parseUserCollections(
        data['collections'] ??
            data['user_collections'] ??
            data['custom_collections'],
      );

      // Do not let an older library response undo a favorite the user changed
      // while this request was in flight.
      if (_favoriteMutationVersion == favoriteVersionAtRequest) {
        favoritePhotoIds.assignAll(favoriteIds);
      }
      userTags.assignAll(parsedTags);
      userTagNames.assignAll(
        _uniqueSorted([
          ...parsedTagNames,
          ..._parseTagNames(
            data['tags'] ?? data['user_tags'] ?? data['custom_tags'],
          ),
          ...parsedTags.values.expand((values) => values),
        ]),
      );
      userCollections.assignAll(collections);
      savedPhotos.refresh();
    } catch (_) {
      favoritePhotoIds.clear();
      userTags.clear();
      userTagNames.clear();
      userCollections.clear();
    } finally {
      isMyLibraryLoading.value = false;
    }
  }

  void toggleFavorite(GalleryPhoto photo) {
    if (!StorageHelper.isLogin()) return;
    _rememberPhoto(photo);
    _favoriteMutationVersion++;
    final updatedIds = favoritePhotoIds.toSet();
    final wasFavorite = favoritePhotoIds.contains(photo.id);
    if (wasFavorite) {
      updatedIds.remove(photo.id);
      favoritePhotoIds.assignAll(updatedIds);
      _repository.removeFavorite(photo.id);
    } else {
      updatedIds.add(photo.id);
      favoritePhotoIds.assignAll(updatedIds);
      _repository.addFavorite(photo.id);
    }
    AnalyticsService.instance.track(
      wasFavorite ? 'Photo Unfavorited' : 'Photo Favorited',
      properties: {
        'photo_id': photo.id,
        'persona': selectedSwami.value.apiValue,
      },
    );
  }

  Future<bool> addTagToPhoto(GalleryPhoto photo, String tag) async {
    if (!StorageHelper.isLogin()) return false;
    final normalized = tag.trim();
    if (normalized.isEmpty) return false;
    final exists = tagsForPhoto(
      photo.id,
    ).any((value) => value.toLowerCase() == normalized.toLowerCase());
    if (exists) return false;

    try {
      await _repository.addTag(photoId: photo.id, tag: normalized);
      await loadMyLibrary();
      AnalyticsService.instance.track(
        'Photo Tagged',
        properties: {'photo_id': photo.id},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> removeTagFromPhoto(int photoId, String tag) async {
    if (!StorageHelper.isLogin()) return;
    await _repository.removeTag(photoId: photoId, tag: tag);
    await loadMyLibrary();
  }

  int photoCountForTag(String tag) {
    final wanted = tag.trim().toLowerCase();
    return userTags.values
        .where((tags) => tags.any((value) => value.toLowerCase() == wanted))
        .length;
  }

  Future<bool> renameTagEverywhere(String tag, String newName) async {
    final cleanName = newName.trim();
    if (!StorageHelper.isLogin() || cleanName.isEmpty) return false;
    try {
      await _repository.renameTag(tag: tag, newName: cleanName);
      await loadMyLibrary();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeTagEverywhere(String tag) async {
    if (!StorageHelper.isLogin()) return false;
    try {
      await _repository.removeTagEverywhere(tag);
      await loadMyLibrary();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addPhotoToCollection(
    GalleryPhoto photo,
    String collectionName,
  ) async {
    if (!StorageHelper.isLogin()) return false;
    final name = collectionName.trim();
    if (name.isEmpty) return false;
    _rememberPhoto(photo);
    final index = userCollections.indexWhere(
      (collection) => collection.name.toLowerCase() == name.toLowerCase(),
    );
    final alreadyAdded =
        index != -1 && userCollections[index].photoIds.contains(photo.id);
    if (alreadyAdded) return false;

    if (index == -1) {
      userCollections.add(
        UserPhotoCollection(name: name, photoIds: [photo.id]),
      );
    } else {
      final collection = userCollections[index];
      if (!collection.photoIds.contains(photo.id)) {
        userCollections[index] = UserPhotoCollection(
          name: collection.name,
          photoIds: [...collection.photoIds, photo.id],
        );
      }
    }
    userCollections.refresh();

    try {
      await _repository.addPhotoToCollection(name: name, photoId: photo.id);
      return true;
    } catch (_) {
      if (index == -1) {
        userCollections.removeWhere(
          (collection) => collection.name.toLowerCase() == name.toLowerCase(),
        );
      } else {
        final collection = userCollections[index];
        userCollections[index] = UserPhotoCollection(
          name: collection.name,
          photoIds: collection.photoIds
              .where((photoId) => photoId != photo.id)
              .toList(),
        );
      }
      userCollections.refresh();
      return false;
    }
  }

  Future<bool> renameCollection(String collectionName, String newName) async {
    final cleanName = newName.trim();
    if (!StorageHelper.isLogin() || cleanName.isEmpty) return false;
    try {
      await _repository.renameCollection(
        name: collectionName,
        newName: cleanName,
      );
      await loadMyLibrary();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> removeCollection(String collectionName) async {
    if (!StorageHelper.isLogin()) return;
    userCollections.removeWhere(
      (collection) =>
          collection.name.toLowerCase() == collectionName.toLowerCase(),
    );
    userCollections.refresh();
    try {
      await _repository.removeCollection(collectionName);
    } catch (_) {
      await loadMyLibrary();
    }
  }

  Map<int, List<String>> _parseUserTags(dynamic raw) {
    final result = <int, List<String>>{};

    void addTags(int photoId, Iterable<dynamic> tags) {
      if (photoId <= 0) return;
      final clean = tags
          .map((tag) => tag.toString().trim())
          .where((tag) => tag.isNotEmpty && tag.toLowerCase() != 'null')
          .toList();
      if (clean.isEmpty) return;
      result[photoId] = _uniqueSorted([
        ...(result[photoId] ?? const []),
        ...clean,
      ]);
    }

    if (raw is Map) {
      raw.forEach((key, value) {
        final photoId = int.tryParse(key.toString()) ?? 0;
        if (value is List) addTags(photoId, value);
        if (value is String) addTags(photoId, [value]);
      });
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final json = Map<String, dynamic>.from(item);
          final photoId =
              _readInt(json, const ['photo_id', 'photoId', 'photo']) ?? 0;
          final tags = json['tags'] is List
              ? json['tags'] as List
              : [
                  json['tag'],
                  json['name'],
                  json['label'],
                ].where((tag) => tag != null).toList();
          addTags(photoId, tags);
        }
      }
    }

    return result;
  }

  List<String> _parseTagNames(dynamic raw) {
    final names = <String>[];
    void add(dynamic value) {
      final name = value?.toString().trim() ?? '';
      if (name.isNotEmpty && name.toLowerCase() != 'null') names.add(name);
    }

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          add(item['name'] ?? item['tag'] ?? item['label']);
        } else {
          add(item);
        }
      }
    } else if (raw is Map) {
      raw.forEach((key, value) {
        if (value is List) {
          for (final item in value) {
            add(
              item is Map ? item['name'] ?? item['tag'] ?? item['label'] : item,
            );
          }
        } else {
          add(value);
        }
      });
    }

    return _uniqueSorted(names);
  }

  List<UserPhotoCollection> _parseUserCollections(dynamic raw) {
    final collections = <UserPhotoCollection>[];
    if (raw is List) {
      collections.addAll(raw.map(UserPhotoCollection.fromJson));
    } else if (raw is Map) {
      raw.forEach((key, value) {
        if (value is List) {
          final ids = value
              .map((item) => item is int ? item : int.tryParse(item.toString()))
              .whereType<int>()
              .toList();
          collections.add(
            UserPhotoCollection(name: key.toString(), photoIds: ids),
          );
        } else {
          collections.add(UserPhotoCollection.fromJson(value));
        }
      });
    }
    final byName = <String, UserPhotoCollection>{};
    for (final collection in collections) {
      final name = collection.name.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      final existing = byName[key];
      byName[key] = UserPhotoCollection(
        name: existing?.name ?? name,
        photoIds: _uniqueInts([
          ...(existing?.photoIds ?? const []),
          ...collection.photoIds,
        ]),
      );
    }
    final values = byName.values.toList();
    values.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return values;
  }

  int? _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  List<String> _uniqueSorted(Iterable<String> values) {
    final unique = <String, String>{};
    for (final value in values) {
      final clean = value.trim();
      if (clean.isEmpty) continue;
      unique.putIfAbsent(clean.toLowerCase(), () => clean);
    }
    final sorted = unique.values.toList();
    sorted.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  List<int> _uniqueInts(Iterable<int> values) => values.toSet().toList();

  Future<void> loadHome({bool force = false}) {
    final loadedRecently =
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) < const Duration(minutes: 10);

    if (!force && loadedRecently && hasAnyData && _hasLoadedOnThisDay) {
      return allPlaces.isEmpty ? loadAllPlaces() : Future.value();
    }

    if (_inFlightLoad != null) return _inFlightLoad!;

    final requestedSwami = selectedSwami.value;
    _inFlightLoad =
        _loadHomeInternal(
          force: force,
          requestedSwami: requestedSwami,
        ).whenComplete(() {
          _inFlightLoad = null;
        });

    return _inFlightLoad!;
  }

  Future<void> refreshHome() async {
    isRefreshing.value = true;
    try {
      await loadHome(force: true);
    } finally {
      isRefreshing.value = false;
    }
  }

  Future<void> loadFilters({
    Map<String, List<String>> selected = const {},
    bool force = false,
  }) async {
    unawaited(loadMySmrutiYearOptions(selected: selected));
    final serverSelected = _serverFilterSelection(selected);
    if (!force && serverSelected.isEmpty && filters.isNotEmpty) return;
    final requestId = ++_filtersRequestId;
    final isInitialLoad = filters.isEmpty;
    if (isInitialLoad) {
      areFiltersLoading.value = true;
      areFiltersRefreshing.value = false;
    } else {
      // Keep the existing facets visible while the server recalculates counts
      // and removes options that are incompatible with the new selection.
      areFiltersRefreshing.value = true;
    }
    filtersError.value = '';
    try {
      final loadedFilters = await _repository.getFilters(
        selected: serverSelected,
      );
      if (requestId != _filtersRequestId) return;
      filters.assignAll(loadedFilters);
      if (serverSelected.isEmpty) {
        _filterSnapshots[selectedSwami.value] = loadedFilters;
      }
    } catch (error) {
      if (requestId != _filtersRequestId) return;
      filtersError.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (requestId == _filtersRequestId) {
        areFiltersLoading.value = false;
        areFiltersRefreshing.value = false;
      }
    }
  }

  Future<void> loadMySmrutiYearOptions({
    Map<String, List<String>> selected = const {},
  }) async {
    if (!StorageHelper.isLogin()) {
      mySmrutiYearOptions.clear();
      return;
    }
    final requestId = ++_mySmrutiYearsRequestId;
    try {
      final years = await _repository.getMySmrutiYears(selected: selected);
      if (requestId == _mySmrutiYearsRequestId) {
        mySmrutiYearOptions.assignAll(years);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('My Smruti Year filters failed: $error');
      }
    }
  }

  Future<void> resetFiltersForSheet() async {
    filters.assignAll(_filterSnapshots[selectedSwami.value] ?? const []);
    filtersError.value = '';
    unawaited(loadMySmrutiFilterPhotos());
    await loadFilters(force: true);
  }

  Future<Set<String>> loadAvailableFilterDates({
    required Map<String, List<String>> selected,
  }) async {
    final groups = await _repository.getFilters(
      selected: _serverFilterSelection(selected),
      includeDates: true,
    );
    return groups
        .where((group) => group.slug.trim().toLowerCase() == 'date')
        .expand((group) => group.options)
        .map((option) => option.value)
        .toSet();
  }

  Future<void> loadMySmrutiFilterPhotos() async {
    if (!StorageHelper.isLogin()) {
      _mySmrutiFiltersRequestId++;
      _mySmrutiYearsRequestId++;
      mySmrutiPhotos.clear();
      areMySmrutiFiltersLoading.value = false;
      return;
    }
    final requestId = ++_mySmrutiFiltersRequestId;
    areMySmrutiFiltersLoading.value = true;
    try {
      await loadMySmrutiYearOptions();
      if (requestId != _mySmrutiFiltersRequestId) return;

      const pageSize = 50;
      // Keep a generous corruption guard while allowing the complete API
      // result set to support the remaining My Smruti facets.
      const maxPages = 1000;
      final photos = <GalleryPhoto>[];
      final seenIds = <int>{};
      var offset = 0;
      var total = 0;
      var pagesFetched = 0;

      do {
        final data = await _repository.getMySmruti(
          offset: offset,
          limit: pageSize,
        );
        if (requestId != _mySmrutiFiltersRequestId) return;
        final beforeCount = photos.length;
        final pagePhotos =
            (data['photos'] is List ? data['photos'] as List : const [])
                .map(GalleryPhoto.fromJson)
                .where((photo) => photo.id > 0 && seenIds.add(photo.id))
                .toList();
        photos.addAll(pagePhotos);
        total = int.tryParse('${data['total']}') ?? photos.length;
        pagesFetched++;
        offset += pageSize;
        if (pagePhotos.isEmpty || photos.length == beforeCount) break;
      } while (photos.length < total && pagesFetched < maxPages);

      if (requestId != _mySmrutiFiltersRequestId) return;
      // My Smruti is shared across both Swamiji sections. Keep the complete
      // personal result set instead of applying the active home-tab scope.
      mySmrutiPhotos.assignAll(photos);
    } catch (_) {
      if (requestId == _mySmrutiFiltersRequestId) {
        mySmrutiPhotos.clear();
      }
    } finally {
      if (requestId == _mySmrutiFiltersRequestId) {
        areMySmrutiFiltersLoading.value = false;
      }
    }
  }

  Future<List<GalleryPhoto>> loadPhotosForCard(
    GalleryCard card, {
    int page = 1,
  }) async {
    final requestedSwami = selectedSwami.value;
    late final List<GalleryPhoto> photos;
    if (card.type == 'person' && card.id > 0) {
      photos = await _repository.getPersonPhotos(
        groupId: card.id,
        page: page,
        perPage: 60,
      );
    } else if (card.type == 'collection') {
      final year = int.tryParse(card.value) ?? card.id;
      if (year > 0) {
        photos = await _repository.getCollectionYearPhotos(
          year: year,
          page: page,
          perPage: 60,
        );
      } else {
        photos = const [];
      }
    } else {
      photos = await _repository.getByAttributePhotos(
        slug: card.type,
        value: card.value,
        page: page,
        perPage: 60,
      );
    }
    return _photosForSwami(photos, requestedSwami);
  }

  Future<List<GalleryPhoto>> loadPhotosForFilter({
    required String slug,
    required String value,
    int page = 1,
  }) async {
    final requestedSwami = selectedSwami.value;
    late final List<GalleryPhoto> photos;
    if (slug == 'duration') {
      final exactDate = DateTime.tryParse(value);
      if (exactDate != null && value.contains('-')) {
        photos = await _repository.getCollectionDayPhotos(
          year: exactDate.year,
          month: exactDate.month,
          day: exactDate.day,
          page: page,
          perPage: 120,
        );
      } else {
        photos = await _repository.getCollectionYearPhotos(
          year: int.tryParse(value) ?? 0,
          page: page,
          perPage: 60,
        );
      }
    } else {
      photos = await _repository.getByAttributePhotos(
        slug: slug,
        value: value,
        page: page,
        perPage: 60,
      );
    }
    return _photosForSwami(photos, requestedSwami);
  }

  Future<List<GalleryPhoto>> loadPhotosForFilters({
    required Map<String, List<String>> selected,
    int page = 1,
  }) async {
    if (selected.containsKey(_mySmrutiScopeFilterSlug) ||
        selected.keys.any(_mySmrutiFilterSlugs.contains)) {
      if (mySmrutiPhotos.isEmpty) {
        await loadMySmrutiFilterPhotos();
      }
      return _loadPhotosForMySmrutiFilters(
        selected: selected,
        page: page,
        perPage: 120,
      );
    }
    final selectedUserTags = selected[_userTagFilterSlug] ?? const <String>[];
    if (selectedUserTags.isNotEmpty) {
      return _loadPhotosForUserTags(
        selected: selected,
        selectedUserTags: selectedUserTags,
        page: page,
        perPage: 120,
      );
    }
    final requestedSwami = selectedSwami.value;
    final photos = await _repository.getFilteredPhotos(
      selected: selected,
      page: page,
      perPage: 120,
    );
    return _photosForSwami(photos, requestedSwami);
  }

  Future<List<GalleryPhoto>> _loadPhotosForMySmrutiFilters({
    required Map<String, List<String>> selected,
    required int page,
    required int perPage,
  }) async {
    var matches = mySmrutiPhotos.toList();
    for (final entry in selected.entries) {
      if (!_mySmrutiFilterSlugs.contains(entry.key) || entry.value.isEmpty) {
        continue;
      }
      final wantedValues = entry.value
          .map(_normalizeFilterValue)
          .where((value) => value.isNotEmpty)
          .toSet();
      matches = matches
          .where(
            (photo) => _mySmrutiValuesForPhoto(
              photo,
              entry.key,
            ).map(_normalizeFilterValue).any(wantedValues.contains),
          )
          .toList();
    }

    final selectedDates =
        (selected['date'] ?? const <String>[])
            .map(DateTime.tryParse)
            .whereType<DateTime>()
            .toList()
          ..sort();
    if (selectedDates.isNotEmpty) {
      final from = selectedDates.first;
      final to = selectedDates.length > 1 ? selectedDates.last : from;
      matches = matches.where((photo) {
        final rawDate = photo.eventDate;
        if (rawDate == null) return false;
        final localDate = rawDate.toLocal();
        final date = DateTime(localDate.year, localDate.month, localDate.day);
        return !date.isBefore(from) && !date.isAfter(to);
      }).toList();
    }

    final selectedUserTags = selected[_userTagFilterSlug] ?? const <String>[];
    if (selectedUserTags.isNotEmpty) {
      final wantedUserTags = selectedUserTags
          .map((tag) => tag.trim().toLowerCase())
          .where((tag) => tag.isNotEmpty)
          .toSet();
      matches = matches
          .where(
            (photo) => (userTags[photo.id] ?? const <String>[]).any(
              (tag) => wantedUserTags.contains(tag.trim().toLowerCase()),
            ),
          )
          .toList();
    }

    final serverSelected = Map<String, List<String>>.from(selected)
      ..remove(_userTagFilterSlug)
      ..remove(_mySmrutiScopeFilterSlug)
      ..remove('date');
    for (final slug in _mySmrutiFilterSlugs) {
      serverSelected.remove(slug);
    }
    if (serverSelected.isNotEmpty && matches.isNotEmpty) {
      final matchingIds = matches.map((photo) => photo.id).toSet();
      final filteredById = <int, GalleryPhoto>{};
      final seenServerPhotoIds = <int>{};
      var serverPage = 1;
      const serverPageSize = 200;
      const maxServerPages = 100;
      while (serverPage <= maxServerPages) {
        final photos = await _repository.getFilteredPhotos(
          selected: serverSelected,
          page: serverPage,
          perPage: serverPageSize,
        );
        var hasNewServerPhotos = false;
        for (final photo in photos) {
          if (seenServerPhotoIds.add(photo.id)) hasNewServerPhotos = true;
          if (matchingIds.contains(photo.id)) {
            filteredById[photo.id] = photo;
          }
        }
        if (photos.length < serverPageSize) break;
        // Protect the filter screen from a backend that ignores `page` and
        // keeps returning the same full page.
        if (!hasNewServerPhotos) break;
        serverPage++;
      }
      matches = filteredById.values.toList();
    }

    matches.sort((a, b) {
      final first = a.eventDate ?? a.takenAt;
      final second = b.eventDate ?? b.takenAt;
      if (first == null) return second == null ? 0 : 1;
      if (second == null) return -1;
      return second.compareTo(first);
    });
    final start = (page - 1) * perPage;
    if (start >= matches.length) return const [];
    return matches.sublist(start, min(start + perPage, matches.length));
  }

  Future<List<GalleryPhoto>> _loadPhotosForUserTags({
    required Map<String, List<String>> selected,
    required List<String> selectedUserTags,
    required int page,
    required int perPage,
  }) async {
    final wantedTags = selectedUserTags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet();
    final matchingIds = userTags.entries
        .where(
          (entry) => entry.value.any(
            (tag) => wantedTags.contains(tag.trim().toLowerCase()),
          ),
        )
        .map((entry) => entry.key)
        .toSet();
    if (matchingIds.isEmpty) return const [];

    var matches = matchingIds
        .map((id) => savedPhotos[id])
        .whereType<GalleryPhoto>()
        .toList();

    final selectedDates =
        (selected['date'] ?? const <String>[])
            .map(DateTime.tryParse)
            .whereType<DateTime>()
            .toList()
          ..sort();
    if (selectedDates.isNotEmpty) {
      final from = selectedDates.first;
      final to = selectedDates.length > 1 ? selectedDates.last : from;
      matches = matches.where((photo) {
        final rawDate = photo.eventDate ?? photo.takenAt;
        if (rawDate == null) return false;
        final localDate = rawDate.toLocal();
        final date = DateTime(localDate.year, localDate.month, localDate.day);
        return !date.isBefore(from) && !date.isAfter(to);
      }).toList();
    }
    matches.sort((a, b) {
      final first = a.eventDate ?? a.takenAt;
      final second = b.eventDate ?? b.takenAt;
      if (first == null) return second == null ? 0 : 1;
      if (second == null) return -1;
      return second.compareTo(first);
    });

    final start = (page - 1) * perPage;
    if (start >= matches.length) return const [];
    final end = min(start + perPage, matches.length);
    return matches.sublist(start, end);
  }

  Future<GalleryPhotoAttributes> loadPhotoAttributes(int photoId) {
    return _repository.getPhotoAttributes(photoId);
  }

  Future<void> loadMoreRecentPhotos() async {
    if (isRecentPageLoading.value || !hasMoreRecentPhotos.value) return;
    isRecentPageLoading.value = true;
    final requestedSwami = selectedSwami.value;
    final nextPage = _recentPage + 1;
    try {
      final photos = await _repository.getRecent(
        page: nextPage,
        perPage: _recentPerPage,
      );
      if (selectedSwami.value != requestedSwami) return;
      final tabPhotos = _photosForSwami(photos, requestedSwami);
      debugPrint(
        'loadMoreRecentPhotos: page=$nextPage perPage=$_recentPerPage '
        'returned=${tabPhotos.length} totalLoaded=${recentPhotos.length + tabPhotos.length}',
      );
      if (tabPhotos.isEmpty) {
        hasMoreRecentPhotos.value = false;
        debugPrint('loadMoreRecentPhotos: page=$nextPage empty, no more pages');
        return;
      }

      final existingIds = recentPhotos
          .where((photo) => photo.id > 0)
          .map((photo) => photo.id)
          .toSet();
      final existingUrls = recentPhotos
          .where((photo) => photo.id <= 0)
          .map((photo) => photo.thumbnailUrl)
          .toSet();
      final newPhotos = tabPhotos.where((photo) {
        if (photo.id > 0) return existingIds.add(photo.id);
        return photo.thumbnailUrl.isNotEmpty &&
            existingUrls.add(photo.thumbnailUrl);
      }).toList();

      if (newPhotos.isNotEmpty) {
        recentPhotos.assignAll(
          _orderPhotos('recent', [...recentPhotos, ...newPhotos]),
        );
      }
      _recentPage = nextPage;
      hasMoreRecentPhotos.value = photos.length >= _recentPerPage;
      debugPrint(
        'loadMoreRecentPhotos: now on page=$_recentPage '
        'displayedTotal=${recentPhotos.length} hasMore=${hasMoreRecentPhotos.value}',
      );
      _saveCurrentSnapshot();
    } catch (e) {
      debugPrint('loadMoreRecentPhotos: request failed for page=$nextPage, $e');
      hasMoreRecentPhotos.value = true;
    } finally {
      isRecentPageLoading.value = false;
    }
  }

  Future<List<GalleryTimeBucket>> loadMonthsForYear(int year) async {
    final requestedSwami = selectedSwami.value;
    final buckets = await _repository.getCollectionMonths(year: year);
    return _timeBucketsForSwami(buckets, requestedSwami);
  }

  Future<List<GalleryTimeBucket>> loadDaysForMonth({
    required int year,
    required int month,
  }) async {
    final requestedSwami = selectedSwami.value;
    final buckets = await _repository.getCollectionDays(
      year: year,
      month: month,
    );
    return _timeBucketsForSwami(buckets, requestedSwami);
  }

  Future<List<GalleryPhoto>> loadPhotosForDay({
    required int year,
    required int month,
    required int day,
  }) async {
    final requestedSwami = selectedSwami.value;
    final photos = await _repository.getCollectionDayPhotos(
      year: year,
      month: month,
      day: day,
    );
    return _photosForSwami(photos, requestedSwami);
  }

  Future<void> _loadHomeInternal({
    required bool force,
    required GallerySwami requestedSwami,
  }) async {
    final loadTimer = Stopwatch()..start();
    final slowConnectionTimer = Timer(_slowHomeLoadThreshold, () {
      if (!isClosed) isSlowConnection.value = true;
    });
    if (!hasAnyData) {
      isLoading.value = true;
    }
    errorMessage.value = '';

    try {
      final cacheRevisionChanged = await _refreshSectionSettings(
        requestedSwami,
      );
      if (cacheRevisionChanged) {
        _tabSnapshots.remove(requestedSwami);
      }
      final forceDataRefresh = force || cacheRevisionChanged;
      final bundle = await _repository.getHomeBundle(
        samples: 4,
        forceRefresh: forceDataRefresh,
      );
      if (selectedSwami.value != requestedSwami) return;
      _applyBundle(bundle);
      await loadAllPlaces();
      if (selectedSwami.value != requestedSwami) return;
      try {
        final loadedOnThisDay = await _repository.getOnThisDay(
          forceRefresh: forceDataRefresh,
        );
        if (selectedSwami.value != requestedSwami) return;
        onThisDayPhotos.assignAll(
          _orderPhotos(
            'on_this_day',
            _photosForSwami(loadedOnThisDay, requestedSwami),
          ),
        );
        _hasLoadedOnThisDay = true;
      } catch (error) {
        onThisDayPhotos.clear();
        _hasLoadedOnThisDay = false;
        debugPrint('On This Day load failed: $error');
      }
      _recentPage = 1;
      hasMoreRecentPhotos.value = bundle.recent.length >= _recentPerPage;
      _lastLoadedAt = DateTime.now();
      _saveCurrentSnapshot();
    } catch (error) {
      if (selectedSwami.value != requestedSwami) return;
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      slowConnectionTimer.cancel();
      loadTimer.stop();
      if (loadTimer.elapsed < _slowHomeLoadThreshold) {
        isSlowConnection.value = false;
      }
      isLoading.value = false;
    }
  }

  Future<bool> _refreshSectionSettings(GallerySwami requestedSwami) async {
    if (!Get.isRegistered<SmrutiSectionController>()) return false;
    final controller = Get.find<SmrutiSectionController>();
    await controller.refreshGlobalVisibility(
      optionKey: requestedSwami.apiValue,
    );
    if (selectedSwami.value != requestedSwami) return false;
    return controller.consumeCacheRefresh(requestedSwami.apiValue);
  }

  void _clearGallerySections() {
    recentPhotos.clear();
    onThisDayPhotos.clear();
    _hasLoadedOnThisDay = false;
    collections.clear();
    smrutiWith.clear();
    smrutiOf.clear();
    locations.clear();
    albums.clear();
    subjects.clear();
    people.clear();
    wallpapers.clear();
  }

  bool _isSnapshotStale(_GalleryTabSnapshot snapshot) {
    return DateTime.now().difference(snapshot.loadedAt) >=
        const Duration(hours: 1);
  }

  void _applySnapshot(_GalleryTabSnapshot snapshot) {
    _applyBundle(snapshot.bundle);
    onThisDayPhotos.assignAll(
      _photosForSwami(snapshot.onThisDayPhotos, selectedSwami.value),
    );
    _hasLoadedOnThisDay = snapshot.hasLoadedOnThisDay;
    _lastLoadedAt = snapshot.loadedAt;
    _recentPage = snapshot.recentPage;
    hasMoreRecentPhotos.value = snapshot.hasMoreRecentPhotos;
  }

  void _applyBundle(GalleryHomeBundle bundle) {
    final swami = selectedSwami.value;
    recentPhotos.assignAll(
      _orderPhotos('recent', _photosForSwami(bundle.recent, swami)),
    );
    collections.assignAll(
      _orderCards('year', _collectionCardsForSwami(bundle.collections, swami)),
    );
    smrutiWith.assignAll(
      _orderCards('smruti_with', _cardsForSwami(bundle.smrutiWith, swami)),
    );
    smrutiOf.assignAll(
      _orderCards('darshan_of', _cardsForSwami(bundle.smrutiOf, swami)),
    );
    locations.assignAll(
      _orderCards('location', _cardsForSwami(bundle.locations, swami)),
    );
    albums.assignAll(
      _orderCards('smruti_category', _cardsForSwami(bundle.albums, swami)),
    );
    subjects.assignAll(
      _orderCards('smruti_of', _cardsForSwami(bundle.subjects, swami)),
    );
    people.assignAll(
      _orderCards('darshan_of', _cardsForSwami(bundle.people, swami)),
    );
    wallpapers.assignAll(_cardsForSwami(bundle.wallpapers, swami));
  }

  AppSectionSetting? _sectionSetting(String sectionKey) {
    final configurations = StorageHelper.getValue<Map>(
      key: StorageKeys.appSectionSettingsByOption,
    );
    final raw = configurations?[selectedSwami.value.apiValue];
    if (raw is! List) return null;
    for (final item in raw.whereType<Map>()) {
      final setting = AppSectionSetting.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (setting.sectionKey == sectionKey) return setting;
    }
    return null;
  }

  AppSectionSetting? sectionSetting(String sectionKey) =>
      _sectionSetting(sectionKey);

  List<GalleryPhoto> _orderPhotos(String sectionKey, List<GalleryPhoto> items) {
    final setting = _sectionSetting(sectionKey);
    final ordered = _applyConfiguredOrder<GalleryPhoto>(
      sectionKey,
      items,
      setting,
      // Gallery order means the date of the Smruti, not when its database row
      // happened to be uploaded. Imported old photos often have a new
      // `created_at`, which previously made "Oldest first" look newest-first.
      (photo) => photo.eventDate ?? photo.takenAt ?? photo.createdAt,
      (photo) => photo.id,
    );
    return ordered;
  }

  List<GalleryPhoto> orderedSectionPhotos(
    String sectionKey,
    Iterable<GalleryPhoto> items,
  ) => _orderPhotos(sectionKey, items.toList());

  List<GalleryCard> _orderCards(String sectionKey, List<GalleryCard> items) {
    final setting = _sectionSetting(sectionKey);
    final ordered = _applyConfiguredOrder<GalleryCard>(
      sectionKey,
      items,
      setting,
      (card) => card.photos
          .map((photo) => photo.eventDate ?? photo.takenAt ?? photo.createdAt)
          .whereType<DateTime>()
          .fold<DateTime?>(
            null,
            (latest, date) =>
                latest == null || date.isAfter(latest) ? date : latest,
          ),
      (card) => card.id,
    );
    return ordered;
  }

  List<T> _applyConfiguredOrder<T>(
    String sectionKey,
    List<T> items,
    AppSectionSetting? setting,
    DateTime? Function(T item) dateOf,
    int Function(T item) idOf,
  ) {
    final result = items.toList();
    final mode = setting?.orderMode ?? 'newest_first';
    int compareNewest(T first, T second) {
      final firstDate = dateOf(first)?.millisecondsSinceEpoch ?? 0;
      final secondDate = dateOf(second)?.millisecondsSinceEpoch ?? 0;
      final dateResult = secondDate.compareTo(firstDate);
      return dateResult != 0 ? dateResult : idOf(second).compareTo(idOf(first));
    }

    if (mode == 'newest_first') {
      result.sort(compareNewest);
      return result;
    }
    if (mode == 'oldest_first') {
      result.sort((first, second) => compareNewest(second, first));
      return result;
    }
    if (mode == 'random') {
      result.shuffle(_dailyRandom(sectionKey));
      return result;
    }

    final cutoff = DateTime.now().subtract(
      Duration(days: setting?.freshnessDays ?? 7),
    );
    final fresh =
        result.where((item) => dateOf(item)?.isAfter(cutoff) == true).toList()
          ..sort(compareNewest);
    final old =
        result.where((item) => dateOf(item)?.isAfter(cutoff) != true).toList()
          ..shuffle(_dailyRandom(sectionKey));
    return [...fresh, ...old];
  }

  Random _dailyRandom(String sectionKey) {
    final now = DateTime.now();
    final revisions = StorageHelper.getValue<Map>(
      key: StorageKeys.appSectionCacheRevisions,
    );
    final revision =
        int.tryParse(
          revisions?[selectedSwami.value.apiValue]?.toString() ?? '',
        ) ??
        0;
    final seedText =
        '$sectionKey:$revision:${now.year}-${now.month}-${now.day}';
    var seed = 17;
    for (final unit in seedText.codeUnits) {
      seed = 0x1fffffff & (seed * 31 + unit);
    }
    return Random(seed);
  }

  void _saveCurrentSnapshot() {
    final loadedAt = _lastLoadedAt ?? DateTime.now();
    _tabSnapshots[selectedSwami.value] = _GalleryTabSnapshot(
      bundle: GalleryHomeBundle(
        recent: recentPhotos.toList(),
        collections: collections.toList(),
        smrutiWith: smrutiWith.toList(),
        smrutiOf: smrutiOf.toList(),
        locations: locations.toList(),
        albums: albums.toList(),
        subjects: subjects.toList(),
        people: people.toList(),
        wallpapers: wallpapers.toList(),
      ),
      onThisDayPhotos: onThisDayPhotos.toList(),
      hasLoadedOnThisDay: _hasLoadedOnThisDay,
      loadedAt: loadedAt,
      recentPage: _recentPage,
      hasMoreRecentPhotos: hasMoreRecentPhotos.value,
    );
    _persistSnapshots();
  }

  void _restoreSnapshots() {
    final raw = StorageHelper.getValue<dynamic>(
      key: StorageKeys.galleryPhotoSnapshots,
    );
    if (raw is! Map) return;

    for (final swami in GallerySwami.values) {
      final entry = raw[swami.apiValue];
      if (entry is! Map) continue;
      final loadedAt = DateTime.tryParse(entry['loaded_at']?.toString() ?? '');
      final bundleRaw = entry['bundle'];
      if (loadedAt == null || bundleRaw is! Map) continue;
      final bundle = GalleryHomeBundle.fromJson(bundleRaw);
      if (!_bundleHasData(bundle)) continue;
      final onThisDayRaw = entry['on_this_day'];
      final hasLoadedOnThisDay = entry.containsKey('on_this_day');
      final restoredOnThisDay = onThisDayRaw is List
          ? onThisDayRaw
                .map((photo) => GalleryPhoto.fromJson(asJsonMap(photo)))
                .toList()
          : <GalleryPhoto>[];
      _tabSnapshots[swami] = _GalleryTabSnapshot(
        bundle: bundle,
        onThisDayPhotos: restoredOnThisDay,
        hasLoadedOnThisDay: hasLoadedOnThisDay,
        loadedAt: loadedAt,
        recentPage: 1,
        hasMoreRecentPhotos: bundle.recent.length >= _recentPerPage,
      );
    }

    final current = _tabSnapshots[selectedSwami.value];
    if (current != null) _applySnapshot(current);
  }

  void _persistSnapshots() {
    StorageHelper.setValue(
      key: StorageKeys.galleryPhotoSnapshots,
      value: {
        for (final entry in _tabSnapshots.entries)
          entry.key.apiValue: {
            'loaded_at': entry.value.loadedAt.toIso8601String(),
            'bundle': entry.value.bundle.toJson(),
            'on_this_day': entry.value.onThisDayPhotos
                .map((photo) => photo.toJson())
                .toList(),
          },
      },
    );
  }

  bool _bundleHasData(GalleryHomeBundle bundle) {
    return bundle.recent.isNotEmpty ||
        bundle.collections.isNotEmpty ||
        bundle.smrutiWith.isNotEmpty ||
        bundle.smrutiOf.isNotEmpty ||
        bundle.locations.isNotEmpty ||
        bundle.albums.isNotEmpty ||
        bundle.subjects.isNotEmpty ||
        bundle.people.isNotEmpty ||
        bundle.wallpapers.isNotEmpty;
  }

  void _rememberPhoto(GalleryPhoto photo) {
    if (photo.id <= 0) return;
    savedPhotos[photo.id] = photo;
    savedPhotos.refresh();
  }

  static const String _userTagFilterSlug = 'user_tag';
  static const String _mySmrutiScopeFilterSlug = 'my_smruti_scope';
  static const String _mySmrutiYearFilterSlug = 'my_smruti_year';
  static const String _mySmrutiWithFilterSlug = 'my_smruti_with';
  static const String _mySmrutiCountryFilterSlug = 'my_smruti_country';
  static const String _mySmrutiLocationFilterSlug = 'my_smruti_location';
  static const String _mySmrutiPlaceFilterSlug = 'my_smruti_place';
  static const String _mySmrutiAlbumFilterSlug = 'my_smruti_album';
  static const String _mySmrutiDarshanOfFilterSlug = 'my_smruti_darshan_of';
  static const String _mySmrutiSmrutiOfFilterSlug = 'my_smruti_smruti_of';
  static const String _mySmrutiTagsFilterSlug = 'my_smruti_tags';
  static const Set<String> _mySmrutiFilterSlugs = {
    _mySmrutiYearFilterSlug,
    _mySmrutiWithFilterSlug,
    _mySmrutiCountryFilterSlug,
    _mySmrutiLocationFilterSlug,
    _mySmrutiPlaceFilterSlug,
    _mySmrutiAlbumFilterSlug,
    _mySmrutiDarshanOfFilterSlug,
    _mySmrutiSmrutiOfFilterSlug,
    _mySmrutiTagsFilterSlug,
  };

  static Map<String, List<String>> _serverFilterSelection(
    Map<String, List<String>> selected,
  ) {
    return Map<String, List<String>>.fromEntries(
      selected.entries.where(
        (entry) =>
            entry.key != _userTagFilterSlug &&
            entry.key != _mySmrutiScopeFilterSlug &&
            !_mySmrutiFilterSlugs.contains(entry.key),
      ),
    );
  }

  List<GalleryFilterGroup> _buildMySmrutiFilterGroups(
    Map<String, List<String>> selected,
  ) {
    if (mySmrutiPhotos.isEmpty && mySmrutiYearOptions.isEmpty) return const [];
    final groups = <GalleryFilterGroup>[];
    for (final definition in const [
      (_mySmrutiYearFilterSlug, 'Year'),
      (_mySmrutiWithFilterSlug, 'With'),
      (_mySmrutiCountryFilterSlug, 'Country'),
      (_mySmrutiLocationFilterSlug, 'Location'),
      (_mySmrutiPlaceFilterSlug, 'Place'),
      (_mySmrutiAlbumFilterSlug, 'Album'),
      (_mySmrutiDarshanOfFilterSlug, 'Darshan Of'),
      (_mySmrutiSmrutiOfFilterSlug, 'Smruti Of'),
      (_mySmrutiTagsFilterSlug, 'Tags'),
    ]) {
      final options = _buildMySmrutiOptions(definition.$1, selected: selected);
      if (options.isNotEmpty) {
        groups.add(
          GalleryFilterGroup(
            slug: definition.$1,
            title: definition.$2,
            options: options,
          ),
        );
      }
    }
    return groups;
  }

  List<GalleryFilterOption> _buildMySmrutiOptions(
    String slug, {
    required Map<String, List<String>> selected,
  }) {
    final labels = <String, String>{};
    final counts = <String, int>{};
    final applicablePhotos = mySmrutiPhotos.where(
      (photo) =>
          _matchesMySmrutiSelections(photo, selected, excludingSlug: slug),
    );
    for (final photo in applicablePhotos) {
      final photoValues = <String>{};
      for (final rawValue in _mySmrutiValuesForPhoto(photo, slug)) {
        final value = rawValue.trim();
        final key = _normalizeFilterValue(value);
        if (key.isEmpty || !photoValues.add(key)) continue;
        labels.putIfAbsent(key, () => value);
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final options = labels.entries
        .map(
          (entry) => GalleryFilterOption(
            value: entry.value,
            label: entry.value,
            count: counts[entry.key] ?? 0,
          ),
        )
        .toList();
    if (slug == _mySmrutiYearFilterSlug) {
      options.sort(
        (first, second) => (int.tryParse(second.value) ?? 0).compareTo(
          int.tryParse(first.value) ?? 0,
        ),
      );
    } else {
      options.sort(_compareGalleryFilterOptions);
    }
    return options;
  }

  static bool _matchesMySmrutiSelections(
    GalleryPhoto photo,
    Map<String, List<String>> selected, {
    String? excludingSlug,
  }) {
    for (final entry in selected.entries) {
      if (entry.key == excludingSlug ||
          !_mySmrutiFilterSlugs.contains(entry.key) ||
          entry.value.isEmpty) {
        continue;
      }
      final wantedValues = entry.value
          .map(_normalizeFilterValue)
          .where((value) => value.isNotEmpty)
          .toSet();
      if (wantedValues.isEmpty) continue;
      final matches = _mySmrutiValuesForPhoto(
        photo,
        entry.key,
      ).map(_normalizeFilterValue).any(wantedValues.contains);
      if (!matches) return false;
    }
    return true;
  }

  static Iterable<String> _mySmrutiValuesForPhoto(
    GalleryPhoto photo,
    String slug,
  ) {
    final Iterable<String?> values = switch (slug) {
      _mySmrutiYearFilterSlug => [
        (photo.takenAt ?? photo.eventDate)?.toLocal().year.toString(),
      ],
      _mySmrutiWithFilterSlug => [photo.smrutiWith],
      _mySmrutiCountryFilterSlug => [photo.country],
      _mySmrutiLocationFilterSlug => [photo.location],
      _mySmrutiPlaceFilterSlug => [
        photo.subLocation,
        ...photo.tags.where(_looksLikeMySmrutiPlaceTag),
      ],
      _mySmrutiAlbumFilterSlug => [photo.album],
      _mySmrutiDarshanOfFilterSlug => [photo.darshanOf],
      _mySmrutiSmrutiOfFilterSlug => [photo.smrutiOf],
      _mySmrutiTagsFilterSlug => _mySmrutiTagValuesForPhoto(photo),
      _ => const <String?>[],
    };
    return values
        .whereType<String>()
        .expand((value) => value.split(RegExp(r'[,;|]')))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
  }

  static Iterable<String> _mySmrutiTagValuesForPhoto(GalleryPhoto photo) {
    // GalleryPhoto.tags also contains the API's typed taxonomy attributes so
    // they remain searchable elsewhere. In the My Smruti filter those values
    // already have dedicated sections and must not be repeated under Tags.
    final typedValues = <String>{
      for (final value in <String?>[
        photo.country,
        photo.location,
        photo.subLocation,
        photo.album,
        photo.smrutiWith,
        photo.darshanOf,
        photo.smrutiOf,
      ])
        if (value != null)
          ...value
              .split(RegExp(r'[,;|]'))
              .map(_normalizeFilterValue)
              .where((value) => value.isNotEmpty),
    };
    return photo.tags.where(
      (tag) =>
          !_looksLikeMySmrutiPlaceTag(tag) &&
          !typedValues.contains(_normalizeFilterValue(tag)),
    );
  }

  static bool _looksLikeMySmrutiPlaceTag(String value) =>
      value.trimLeft().toLowerCase().startsWith('at ');

  static String _normalizeFilterValue(String value) =>
      value.trim().toLowerCase();

  GalleryFilterGroup? _buildUserTagFilterGroup() {
    final tags = allUserTags;
    if (tags.isEmpty) return null;

    final counts = <String, int>{};
    for (final values in userTags.values) {
      for (final tag in values) {
        final key = tag.trim().toLowerCase();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    return GalleryFilterGroup(
      slug: _userTagFilterSlug,
      title: 'My Tags',
      options: tags
          .map(
            (tag) => GalleryFilterOption(
              value: tag,
              label: tag,
              count: counts[tag.toLowerCase()] ?? 0,
            ),
          )
          .toList(),
    );
  }

  static int _compareGalleryFilterOptions(
    GalleryFilterOption first,
    GalleryFilterOption second,
  ) => first.label.toLowerCase().compareTo(second.label.toLowerCase());
}
