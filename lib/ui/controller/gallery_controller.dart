import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/api/repositories/gallery_repository.dart';

class GalleryController extends GetxController {
  GalleryController({GalleryRepository? repository})
    : _repository = repository ?? const GalleryRepository();

  final GalleryRepository _repository;

  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxString errorMessage = ''.obs;

  final RxList<GalleryPhoto> recentPhotos = <GalleryPhoto>[].obs;
  final RxList<GalleryCard> collections = <GalleryCard>[].obs;
  final RxList<GalleryCard> smrutiOf = <GalleryCard>[].obs;
  final RxList<GalleryCard> locations = <GalleryCard>[].obs;
  final RxList<GalleryCard> albums = <GalleryCard>[].obs;
  final RxList<GalleryCard> people = <GalleryCard>[].obs;
  final RxList<GalleryCard> wallpapers = <GalleryCard>[].obs;

  DateTime? _lastLoadedAt;
  Future<void>? _inFlightLoad;

  Map<String, String> get imageHeaders => _repository.imageHeaders;
  bool get hasAnyData =>
      recentPhotos.isNotEmpty ||
      collections.isNotEmpty ||
      smrutiOf.isNotEmpty ||
      locations.isNotEmpty ||
      albums.isNotEmpty ||
      people.isNotEmpty ||
      wallpapers.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    loadHome();
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

  Future<void> _loadHomeInternal({required bool force}) async {
    if (!hasAnyData) {
      isLoading.value = true;
    }
    errorMessage.value = '';

    try {
      final bundle = await _repository.getHomeBundle(samples: 4);
      recentPhotos.assignAll(bundle.recent);
      collections.assignAll(bundle.collections);
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
}
