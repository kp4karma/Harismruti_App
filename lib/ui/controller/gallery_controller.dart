import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/api/repositories/gallery_repository.dart';

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
  final RxBool areFiltersLoading = false.obs;
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
    loadMyLibrary();
    loadHome();
  }

  bool isFavorite(int photoId) => favoritePhotoIds.contains(photoId);

  int get favoriteCount => favoritePhotoIds.length;

  List<GalleryPhoto> get favoritePhotos => favoritePhotoIds
      .map((id) => savedPhotos[id])
      .whereType<GalleryPhoto>()
      .toList();

  List<String> tagsForPhoto(int photoId) => userTags[photoId] ?? const [];
  List<String> get allUserTags {
    final tags = userTags.values.expand((values) => values).toSet().toList();
    tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return tags;
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
        .toList();
  }

  Future<void> loadMyLibrary() async {
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

      final rawTags = asJsonMap(data['tags']);
      userTags.assignAll(
        rawTags.map((key, value) {
          final values = value is List
              ? value.map((item) => item.toString()).toList()
              : <String>[];
          return MapEntry(int.tryParse(key) ?? 0, values);
        })..removeWhere((key, value) => key <= 0),
      );

      final collections =
          (data['collections'] is List ? data['collections'] as List : const [])
              .map(UserPhotoCollection.fromJson)
              .where((collection) => collection.name.isNotEmpty)
              .toList();

      favoritePhotoIds.assignAll(favoriteIds);
      userCollections.assignAll(collections);
      savedPhotos.refresh();
    } catch (_) {
      favoritePhotoIds.clear();
      userTags.clear();
      userCollections.clear();
    }
  }

  void toggleFavorite(GalleryPhoto photo) {
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
      _repository.addTag(photoId: photo.id, tag: normalized);
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
    _repository.removeTag(photoId: photoId, tag: tag);
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
    _repository.addPhotoToCollection(name: name, photoId: photo.id);
  }

  void removeCollection(String collectionName) {
    userCollections.removeWhere(
      (collection) =>
          collection.name.toLowerCase() == collectionName.toLowerCase(),
    );
    userCollections.refresh();
    _repository.removeCollection(collectionName);
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

  Future<void> loadFilters({
    Map<String, List<String>> selected = const {},
    bool force = false,
  }) async {
    if (!force && selected.isEmpty && filters.isNotEmpty) return;
    areFiltersLoading.value = true;
    try {
      filters.assignAll(await _repository.getFilters(selected: selected));
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

  void _rememberPhoto(GalleryPhoto photo) {
    if (photo.id <= 0) return;
    savedPhotos[photo.id] = photo;
    savedPhotos.refresh();
  }
}
