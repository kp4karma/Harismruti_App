import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/api/repositories/gallery_repository.dart';
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
  final DateTime loadedAt;
  final int recentPage;
  final bool hasMoreRecentPhotos;

  const _GalleryTabSnapshot({
    required this.bundle,
    required this.loadedAt,
    required this.recentPage,
    required this.hasMoreRecentPhotos,
  });
}

class GalleryController extends GetxController {
  GalleryController({GalleryRepository? repository})
    : _repository = repository ?? const GalleryRepository();

  static const int _recentPerPage = 60;

  final GalleryRepository _repository;

  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isRecentPageLoading = false.obs;
  final RxBool hasMoreRecentPhotos = true.obs;
  final Rx<GallerySwami> selectedSwami = GallerySwami.prabodh.obs;

  final RxList<GalleryPhoto> recentPhotos = <GalleryPhoto>[].obs;
  final RxList<GalleryCard> collections = <GalleryCard>[].obs;
  final RxList<GalleryCard> smrutiWith = <GalleryCard>[].obs;
  final RxList<GalleryCard> smrutiOf = <GalleryCard>[].obs;
  final RxList<GalleryCard> locations = <GalleryCard>[].obs;
  final RxList<GalleryCard> albums = <GalleryCard>[].obs;
  final RxList<GalleryCard> subjects = <GalleryCard>[].obs;
  final RxList<GalleryCard> people = <GalleryCard>[].obs;
  final RxList<GalleryCard> wallpapers = <GalleryCard>[].obs;
  final RxList<GalleryFilterGroup> filters = <GalleryFilterGroup>[].obs;
  final RxBool areFiltersLoading = false.obs;
  final RxString filtersError = ''.obs;
  final RxSet<int> favoritePhotoIds = <int>{}.obs;
  final RxMap<int, GalleryPhoto> savedPhotos = <int, GalleryPhoto>{}.obs;
  final RxMap<int, List<String>> userTags = <int, List<String>>{}.obs;
  final RxList<String> userTagNames = <String>[].obs;
  final RxList<UserPhotoCollection> userCollections =
      <UserPhotoCollection>[].obs;

  DateTime? _lastLoadedAt;
  Future<void>? _inFlightLoad;
  int _recentPage = 1;
  final Map<GallerySwami, _GalleryTabSnapshot> _tabSnapshots = {};
  final Map<GallerySwami, List<GalleryFilterGroup>> _filterSnapshots = {};

  Map<String, String> get imageHeaders => _repository.imageHeaders;
  bool get hasAnyData =>
      recentPhotos.isNotEmpty ||
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
    loadHome();
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

  List<GalleryFilterGroup> get filtersWithUserTags {
    final groups = filters.toList();
    final customTagGroup = _buildUserTagFilterGroup();
    if (customTagGroup == null) return groups;

    final tagGroupIndex = groups.indexWhere(
      (group) => _tagFilterSlugs.contains(group.slug.toLowerCase()),
    );
    if (tagGroupIndex == -1) return [customTagGroup, ...groups];

    final existing = groups[tagGroupIndex];
    groups.removeAt(tagGroupIndex);
    return [
      GalleryFilterGroup(
        slug: existing.slug,
        title: 'MyTag',
        options: _mergeFilterOptions(existing.options, customTagGroup.options),
      ),
      ...groups,
    ];
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
    final date = photo.takenAt;
    if (date == null) return false;
    final calendarDate = DateTime(date.year, date.month, date.day);
    final cutoff = DateTime(2022, 4, 21);
    return selectedSwami.value == GallerySwami.hariprasad
        ? calendarDate.isBefore(cutoff)
        : !calendarDate.isBefore(cutoff);
  }

  Future<void> selectSwami(int index) async {
    final next = index == 1 ? GallerySwami.hariprasad : GallerySwami.prabodh;
    if (selectedSwami.value == next) return;

    selectedSwami.value = next;
    GalleryRepository.activeSwami = next;
    StorageHelper.setValue(key: StorageKeys.selectedSwami, value: next.apiValue);

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
    if (selectedSwami.value != next) return;

    await Future.wait([
      loadMyLibrary(),
      loadHome(force: snapshot == null || _isSnapshotStale(snapshot)),
    ]);
  }

  Future<void> loadMyLibrary() async {
    final requestedSwami = selectedSwami.value;
    if (!StorageHelper.isLogin()) {
      favoritePhotoIds.clear();
      userTags.clear();
      userTagNames.clear();
      userCollections.clear();
      return;
    }
    try {
      final data = await _repository.getMyLibrary();
      if (selectedSwami.value != requestedSwami) return;
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

      favoritePhotoIds.assignAll(favoriteIds);
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
      if (selectedSwami.value != requestedSwami) return;
      favoritePhotoIds.clear();
      userTags.clear();
      userTagNames.clear();
      userCollections.clear();
    }
  }

  void toggleFavorite(GalleryPhoto photo) {
    if (!StorageHelper.isLogin()) return;
    _rememberPhoto(photo);
    if (favoritePhotoIds.contains(photo.id)) {
      favoritePhotoIds.remove(photo.id);
      _repository.removeFavorite(photo.id);
    } else {
      favoritePhotoIds.add(photo.id);
      _repository.addFavorite(photo.id);
    }
    favoritePhotoIds.refresh();
  }

  Future<bool> addTagToPhoto(GalleryPhoto photo, String tag) async {
    if (!StorageHelper.isLogin()) return false;
    final normalized = tag.trim();
    if (normalized.isEmpty) return false;
    _rememberPhoto(photo);
    final current = [...tagsForPhoto(photo.id)];
    final exists = current.any(
      (value) => value.toLowerCase() == normalized.toLowerCase(),
    );
    if (exists) return false;

    current.add(normalized);
    userTags[photo.id] = current;
    userTagNames.assignAll(_uniqueSorted([...userTagNames, normalized]));
    userTags.refresh();

    try {
      await _repository.addTag(photoId: photo.id, tag: normalized);
      return true;
    } catch (_) {
      current.removeWhere(
        (value) => value.toLowerCase() == normalized.toLowerCase(),
      );
      if (current.isEmpty) {
        userTags.remove(photo.id);
      } else {
        userTags[photo.id] = current;
      }
      userTags.refresh();
      return false;
    }
  }

  void removeTagFromPhoto(int photoId, String tag) {
    if (!StorageHelper.isLogin()) return;
    final current = [...tagsForPhoto(photoId)];
    current.removeWhere((value) => value.toLowerCase() == tag.toLowerCase());
    if (current.isEmpty) {
      userTags.remove(photoId);
    } else {
      userTags[photoId] = current;
    }
    userTags.refresh();
    _repository.removeTag(photoId: photoId, tag: tag);
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

  void removeCollection(String collectionName) {
    if (!StorageHelper.isLogin()) return;
    userCollections.removeWhere(
      (collection) =>
          collection.name.toLowerCase() == collectionName.toLowerCase(),
    );
    userCollections.refresh();
    _repository.removeCollection(collectionName);
  }

  Map<int, List<String>> _parseUserTags(dynamic raw) {
    final result = <int, List<String>>{};

    void addTags(int photoId, Iterable<dynamic> tags) {
      if (photoId <= 0) return;
      final clean = tags
          .map((tag) => tag.toString().trim())
          .where((tag) => tag.isNotEmpty)
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
      if (name.isNotEmpty) names.add(name);
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

    if (!force && loadedRecently && hasAnyData) {
      return Future.value();
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
    if (!force && selected.isEmpty && filters.isNotEmpty) return;
    areFiltersLoading.value = true;
    filtersError.value = '';
    try {
      final loadedFilters = await _repository.getFilters(selected: selected);
      filters.assignAll(loadedFilters);
      if (selected.isEmpty) {
        _filterSnapshots[selectedSwami.value] = loadedFilters;
      }
    } catch (error) {
      filtersError.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      areFiltersLoading.value = false;
    }
  }

  Future<List<GalleryPhoto>> loadPhotosForCard(GalleryCard card) {
    if (card.type == 'person' && card.id > 0) {
      return _repository.getPersonPhotos(groupId: card.id, perPage: 120);
    }
    if (card.type == 'collection') {
      final year = int.tryParse(card.value) ?? card.id;
      if (year > 0) {
        return _repository.getCollectionYearPhotos(year: year, perPage: 120);
      }
    }
    return _repository.getByAttributePhotos(
      slug: card.type,
      value: card.value,
      perPage: 120,
    );
  }

  Future<List<GalleryPhoto>> loadPhotosForFilter({
    required String slug,
    required String value,
  }) {
    if (slug == 'duration') {
      return _repository.getCollectionYearPhotos(
        year: int.tryParse(value) ?? 0,
        perPage: 120,
      );
    }
    return _repository.getByAttributePhotos(
      slug: slug,
      value: value,
      perPage: 120,
    );
  }

  Future<List<GalleryPhoto>> loadPhotosForFilters({
    required Map<String, List<String>> selected,
  }) {
    return _repository.getFilteredPhotos(selected: selected, perPage: 120);
  }

  Future<GalleryPhotoAttributes> loadPhotoAttributes(int photoId) {
    return _repository.getPhotoAttributes(photoId);
  }

  Future<void> loadMoreRecentPhotos() async {
    if (isRecentPageLoading.value || !hasMoreRecentPhotos.value) return;
    isRecentPageLoading.value = true;
    final nextPage = _recentPage + 1;
    try {
      final photos = await _repository.getRecent(
        page: nextPage,
        perPage: _recentPerPage,
      );
      debugPrint(
        'loadMoreRecentPhotos: page=$nextPage perPage=$_recentPerPage '
        'returned=${photos.length} totalLoaded=${recentPhotos.length + photos.length}',
      );
      if (photos.isEmpty) {
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
      final newPhotos = photos.where((photo) {
        if (photo.id > 0) return existingIds.add(photo.id);
        return photo.thumbnailUrl.isNotEmpty &&
            existingUrls.add(photo.thumbnailUrl);
      }).toList();

      if (newPhotos.isNotEmpty) {
        recentPhotos.addAll(newPhotos);
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

  Future<List<GalleryTimeBucket>> loadMonthsForYear(int year) {
    return _repository.getCollectionMonths(year: year);
  }

  Future<List<GalleryTimeBucket>> loadDaysForMonth({
    required int year,
    required int month,
  }) {
    return _repository.getCollectionDays(year: year, month: month);
  }

  Future<List<GalleryPhoto>> loadPhotosForDay({
    required int year,
    required int month,
    required int day,
  }) {
    return _repository.getCollectionDayPhotos(
      year: year,
      month: month,
      day: day,
    );
  }

  Future<void> _loadHomeInternal({
    required bool force,
    required GallerySwami requestedSwami,
  }) async {
    if (!hasAnyData) {
      isLoading.value = true;
    }
    errorMessage.value = '';

    try {
      final bundle = await _repository.getHomeBundle(
        samples: 4,
        forceRefresh: force,
      );
      if (selectedSwami.value != requestedSwami) return;
      _applyBundle(bundle);
      _recentPage = 1;
      hasMoreRecentPhotos.value = bundle.recent.length >= _recentPerPage;
      _lastLoadedAt = DateTime.now();
      _saveCurrentSnapshot();
    } catch (error) {
      if (selectedSwami.value != requestedSwami) return;
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  void _clearGallerySections() {
    recentPhotos.clear();
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
    _lastLoadedAt = snapshot.loadedAt;
    _recentPage = snapshot.recentPage;
    hasMoreRecentPhotos.value = snapshot.hasMoreRecentPhotos;
  }

  void _applyBundle(GalleryHomeBundle bundle) {
    recentPhotos.assignAll(bundle.recent);
    collections.assignAll(bundle.collections);
    smrutiWith.assignAll(bundle.smrutiWith);
    smrutiOf.assignAll(bundle.smrutiOf);
    locations.assignAll(bundle.locations);
    albums.assignAll(bundle.albums);
    subjects.assignAll(bundle.subjects);
    people.assignAll(bundle.people);
    wallpapers.assignAll(bundle.wallpapers);
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
      _tabSnapshots[swami] = _GalleryTabSnapshot(
        bundle: bundle,
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

  static const Set<String> _tagFilterSlugs = {
    'tag',
    'tags',
    'user_tag',
    'user_tags',
    'custom_tag',
    'custom_tags',
  };

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
      slug: 'tag',
      title: 'MyTag',
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

  List<GalleryFilterOption> _mergeFilterOptions(
    List<GalleryFilterOption> existing,
    List<GalleryFilterOption> custom,
  ) {
    final byValue = <String, GalleryFilterOption>{};
    for (final option in existing) {
      byValue[option.value.toLowerCase()] = option;
    }
    for (final option in custom) {
      byValue.putIfAbsent(option.value.toLowerCase(), () => option);
    }
    final merged = byValue.values.toList();
    merged.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return merged;
  }
}
