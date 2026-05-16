import 'dart:convert';

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
    final json = asJsonMap(raw);
    final name = json['name']?.toString().trim() ?? '';
    final ids =
        (json['photo_ids'] is List ? json['photo_ids'] as List : const [])
            .map(
              (value) => value is int ? value : int.tryParse(value.toString()),
            )
            .whereType<int>()
            .toList();
    return UserPhotoCollection(name: name, photoIds: ids);
  }

  Map<String, dynamic> toJson() => {'name': name, 'photo_ids': photoIds};
}

class GalleryController extends GetxController {
  GalleryController({GalleryRepository? repository})
    : _repository = repository ?? const GalleryRepository();

  final GalleryRepository _repository;

  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxString errorMessage = ''.obs;

  final RxList<GalleryPhoto> recentPhotos = <GalleryPhoto>[].obs;
  final RxList<GalleryCard> collections = <GalleryCard>[].obs;
  final RxList<GalleryCard> smrutiWith = <GalleryCard>[].obs;
  final RxList<GalleryCard> smrutiOf = <GalleryCard>[].obs;
  final RxList<GalleryCard> locations = <GalleryCard>[].obs;
  final RxList<GalleryCard> albums = <GalleryCard>[].obs;
  final RxList<GalleryCard> people = <GalleryCard>[].obs;
  final RxList<GalleryCard> wallpapers = <GalleryCard>[].obs;
  final RxList<GalleryFilterGroup> filters = <GalleryFilterGroup>[].obs;
  final RxSet<int> favoritePhotoIds = <int>{}.obs;
  final RxMap<int, GalleryPhoto> savedPhotos = <int, GalleryPhoto>{}.obs;
  final RxMap<int, List<String>> userTags = <int, List<String>>{}.obs;
  final RxList<UserPhotoCollection> userCollections =
      <UserPhotoCollection>[].obs;

  DateTime? _lastLoadedAt;
  Future<void>? _inFlightLoad;

  Map<String, String> get imageHeaders => _repository.imageHeaders;
  bool get hasAnyData =>
      recentPhotos.isNotEmpty ||
      collections.isNotEmpty ||
      smrutiWith.isNotEmpty ||
      smrutiOf.isNotEmpty ||
      locations.isNotEmpty ||
      albums.isNotEmpty ||
      people.isNotEmpty ||
      wallpapers.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    _loadLocalLibrary();
    loadHome();
  }

  bool isFavorite(int photoId) => favoritePhotoIds.contains(photoId);

  int get favoriteCount => favoritePhotoIds.length;

  List<GalleryPhoto> get favoritePhotos => favoritePhotoIds
      .map((id) => savedPhotos[id])
      .whereType<GalleryPhoto>()
      .toList();

  List<String> tagsForPhoto(int photoId) => userTags[photoId] ?? const [];

  List<GalleryPhoto> photosForCollection(UserPhotoCollection collection) {
    return collection.photoIds
        .map((id) => savedPhotos[id])
        .whereType<GalleryPhoto>()
        .toList();
  }

  void toggleFavorite(GalleryPhoto photo) {
    _rememberPhoto(photo);
    if (favoritePhotoIds.contains(photo.id)) {
      favoritePhotoIds.remove(photo.id);
    } else {
      favoritePhotoIds.add(photo.id);
    }
    favoritePhotoIds.refresh();
    _saveFavoriteIds();
  }

  void addTagToPhoto(GalleryPhoto photo, String tag) {
    final normalized = tag.trim();
    if (normalized.isEmpty) return;
    _rememberPhoto(photo);
    final current = [...tagsForPhoto(photo.id)];
    final exists = current.any(
      (value) => value.toLowerCase() == normalized.toLowerCase(),
    );
    if (!exists) {
      current.add(normalized);
      userTags[photo.id] = current;
      userTags.refresh();
      _saveUserTags();
    }
  }

  void removeTagFromPhoto(int photoId, String tag) {
    final current = [...tagsForPhoto(photoId)];
    current.removeWhere((value) => value.toLowerCase() == tag.toLowerCase());
    if (current.isEmpty) {
      userTags.remove(photoId);
    } else {
      userTags[photoId] = current;
    }
    userTags.refresh();
    _saveUserTags();
  }

  void addPhotoToCollection(GalleryPhoto photo, String collectionName) {
    final name = collectionName.trim();
    if (name.isEmpty) return;
    _rememberPhoto(photo);
    final index = userCollections.indexWhere(
      (collection) => collection.name.toLowerCase() == name.toLowerCase(),
    );
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
    _saveUserCollections();
  }

  void removeCollection(String collectionName) {
    userCollections.removeWhere(
      (collection) =>
          collection.name.toLowerCase() == collectionName.toLowerCase(),
    );
    userCollections.refresh();
    _saveUserCollections();
  }

  Future<void> loadHome({bool force = false}) {
    final loadedRecently =
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) < const Duration(minutes: 10);

    if (!force && loadedRecently && hasAnyData) {
      return Future.value();
    }

    if (_inFlightLoad != null) return _inFlightLoad!;

    _inFlightLoad = _loadHomeInternal(force: force).whenComplete(() {
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

  Future<void> loadFilters() async {
    if (filters.isNotEmpty) return;
    filters.assignAll(await _repository.getFilters());
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

  Future<GalleryPhotoAttributes> loadPhotoAttributes(int photoId) {
    return _repository.getPhotoAttributes(photoId);
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

  Future<void> _loadHomeInternal({required bool force}) async {
    if (!hasAnyData) {
      isLoading.value = true;
    }
    errorMessage.value = '';

    try {
      final bundle = await _repository.getHomeBundle(samples: 4);
      recentPhotos.assignAll(bundle.recent);
      collections.assignAll(bundle.collections);
      smrutiWith.assignAll(bundle.smrutiWith);
      smrutiOf.assignAll(bundle.smrutiOf);
      locations.assignAll(bundle.locations);
      albums.assignAll(bundle.albums);
      people.assignAll(bundle.people);
      wallpapers.assignAll(bundle.wallpapers);
      _lastLoadedAt = DateTime.now();
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  void _loadLocalLibrary() {
    final favorites =
        StorageHelper.getValue<List>(key: StorageKeys.favoritePhotos) ??
        const [];
    favoritePhotoIds.assignAll(
      favorites
          .map((value) => value is int ? value : int.tryParse(value.toString()))
          .whereType<int>(),
    );

    final snapshots = StorageHelper.getValue<String>(
      key: StorageKeys.galleryPhotoSnapshots,
    );
    if (snapshots?.isNotEmpty == true) {
      try {
        final decoded = jsonDecode(snapshots!);
        if (decoded is Map) {
          savedPhotos.assignAll(
            decoded.map(
              (key, value) => MapEntry(
                int.tryParse(key.toString()) ?? 0,
                GalleryPhoto.fromJson(value),
              ),
            )..removeWhere((key, value) => key <= 0),
          );
        }
      } catch (_) {
        savedPhotos.clear();
      }
    }

    final tags = StorageHelper.getValue<String>(key: StorageKeys.photoUserTags);
    if (tags?.isNotEmpty == true) {
      try {
        final decoded = jsonDecode(tags!);
        if (decoded is Map) {
          userTags.assignAll(
            decoded.map((key, value) {
              final values = value is List
                  ? value.map((item) => item.toString()).toList()
                  : <String>[];
              return MapEntry(int.tryParse(key.toString()) ?? 0, values);
            })..removeWhere((key, value) => key <= 0),
          );
        }
      } catch (_) {
        userTags.clear();
      }
    }

    final collections =
        StorageHelper.getValue<List>(key: StorageKeys.userCollections) ??
        const [];
    userCollections.assignAll(
      collections
          .map(UserPhotoCollection.fromJson)
          .where((collection) => collection.name.isNotEmpty),
    );
  }

  void _rememberPhoto(GalleryPhoto photo) {
    if (photo.id <= 0) return;
    savedPhotos[photo.id] = photo;
    savedPhotos.refresh();
    StorageHelper.setValue(
      key: StorageKeys.galleryPhotoSnapshots,
      value: jsonEncode(
        savedPhotos.map(
          (key, value) => MapEntry(key.toString(), value.toJson()),
        ),
      ),
    );
  }

  void _saveFavoriteIds() {
    StorageHelper.setValue(
      key: StorageKeys.favoritePhotos,
      value: favoritePhotoIds.toList(),
    );
  }

  void _saveUserTags() {
    StorageHelper.setValue(
      key: StorageKeys.photoUserTags,
      value: jsonEncode(
        userTags.map((key, value) => MapEntry(key.toString(), value)),
      ),
    );
  }

  void _saveUserCollections() {
    StorageHelper.setValue(
      key: StorageKeys.userCollections,
      value: userCollections.map((collection) => collection.toJson()).toList(),
    );
  }
}
