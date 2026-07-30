import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/api/repositories/gallery_repository.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';

class _FakeGalleryRepository extends GalleryRepository {
  _FakeGalleryRepository();

  Future<List<GalleryFilterGroup>> Function({
    int limit,
    Map<String, List<String>> selected,
    bool includeDates,
  })?
  onGetFilters;

  Future<List<GalleryPhoto>> Function({
    required Map<String, List<String>> selected,
    int page,
    int perPage,
  })?
  onGetFilteredPhotos;

  @override
  Future<List<GalleryFilterGroup>> getFilters({
    int limit = 200,
    Map<String, List<String>> selected = const {},
    bool includeDates = false,
  }) {
    return onGetFilters?.call(
          limit: limit,
          selected: selected,
          includeDates: includeDates,
        ) ??
        Future.value(const []);
  }

  @override
  Future<List<GalleryPhoto>> getFilteredPhotos({
    required Map<String, List<String>> selected,
    int page = 1,
    int perPage = 60,
  }) {
    return onGetFilteredPhotos?.call(
          selected: selected,
          page: page,
          perPage: perPage,
        ) ??
        Future.value(const []);
  }
}

GalleryPhoto _photo(
  int id, {
  String? country,
  String? location,
  String? smrutiWith,
  String? darshanOf,
  String? smrutiOf,
  List<String> tags = const [],
}) {
  return GalleryPhoto(
    id: id,
    thumbnailUrl: 'thumb/$id',
    fullUrl: 'full/$id',
    eventDate: DateTime.utc(2026, 7, id.clamp(1, 28)),
    country: country,
    location: location,
    smrutiWith: smrutiWith,
    darshanOf: darshanOf,
    smrutiOf: smrutiOf,
    tags: tags,
  );
}

void main() {
  group('GalleryController filter orchestration', () {
    test('strips custom keys before requesting server facets', () async {
      final repository = _FakeGalleryRepository();
      Map<String, List<String>>? received;
      repository.onGetFilters =
          ({
            int limit = 200,
            Map<String, List<String>> selected = const {},
            bool includeDates = false,
          }) async {
            received = selected;
            return const [];
          };
      final controller = GalleryController(repository: repository);

      await controller.loadFilters(
        selected: const {
          'country': ['India'],
          'user_tag': ['Favorite'],
          'my_smruti_location': ['Ahmedabad'],
        },
        force: true,
      );

      expect(received, {
        'country': ['India'],
      });
    });

    test('only newest overlapping facet response updates state', () async {
      final repository = _FakeGalleryRepository();
      final first = Completer<List<GalleryFilterGroup>>();
      final second = Completer<List<GalleryFilterGroup>>();
      var calls = 0;
      repository.onGetFilters =
          ({
            int limit = 200,
            Map<String, List<String>> selected = const {},
            bool includeDates = false,
          }) {
            calls++;
            return calls == 1 ? first.future : second.future;
          };
      final controller = GalleryController(repository: repository);

      final firstLoad = controller.loadFilters(
        selected: const {
          'country': ['India'],
        },
        force: true,
      );
      final secondLoad = controller.loadFilters(
        selected: const {
          'country': ['USA'],
        },
        force: true,
      );
      second.complete(const [
        GalleryFilterGroup(
          slug: 'location',
          title: 'Location',
          options: [
            GalleryFilterOption(value: 'New York', label: 'New York', count: 4),
          ],
        ),
      ]);
      await secondLoad;
      first.complete(const [
        GalleryFilterGroup(
          slug: 'location',
          title: 'Location',
          options: [
            GalleryFilterOption(
              value: 'Ahmedabad',
              label: 'Ahmedabad',
              count: 9,
            ),
          ],
        ),
      ]);
      await firstLoad;

      expect(controller.filters.single.options.single.value, 'New York');
      expect(controller.areFiltersLoading.value, isFalse);
      expect(controller.areFiltersRefreshing.value, isFalse);
    });

    test('builds My Smruti facets with compatible counts', () {
      final controller = GalleryController(
        repository: _FakeGalleryRepository(),
      );
      controller.mySmrutiPhotos.assignAll([
        _photo(
          1,
          country: 'India',
          location: 'Ahmedabad',
          smrutiWith: 'Saints',
        ),
        _photo(2, country: 'India', location: 'Rajkot', smrutiWith: 'Devotees'),
        _photo(3, country: 'USA', location: 'New York', smrutiWith: 'Saints'),
      ]);

      final groups = controller.filtersWithUserTagsForSelection(const {
        'my_smruti_country': ['India'],
      });
      final location = groups.singleWhere(
        (group) => group.slug == 'my_smruti_location',
      );

      expect(
        location.options.map((option) => option.value),
        unorderedEquals(['Ahmedabad', 'Rajkot']),
      );
      expect(location.options.every((option) => option.count == 1), isTrue);
    });

    test('exposes My Tags with photo counts', () {
      final controller = GalleryController(
        repository: _FakeGalleryRepository(),
      );
      controller.userTagNames.assignAll(['Favorite', 'Family']);
      controller.userTags.assignAll({
        1: ['Favorite'],
        2: ['Favorite', 'Family'],
      });

      final group = controller
          .filtersWithUserTagsForSelection(const {})
          .singleWhere((item) => item.slug == 'user_tag');
      final counts = {
        for (final option in group.options) option.value: option.count,
      };

      expect(group.title, 'My Tags');
      expect(counts, {'Family': 1, 'Favorite': 2});
    });

    test('filters locally by My Smruti subcategories', () async {
      final controller = GalleryController(
        repository: _FakeGalleryRepository(),
      );
      controller.mySmrutiPhotos.assignAll([
        _photo(1, location: 'Ahmedabad', smrutiWith: 'Saints'),
        _photo(2, location: 'Ahmedabad', smrutiWith: 'Devotees'),
        _photo(3, location: 'Rajkot', smrutiWith: 'Saints'),
      ]);

      final photos = await controller.loadPhotosForFilters(
        selected: const {
          'my_smruti_location': ['Ahmedabad'],
          'my_smruti_with': ['Saints'],
        },
      );

      expect(photos.map((photo) => photo.id), [1]);
    });

    test('filters locally by My Tags', () async {
      final controller = GalleryController(
        repository: _FakeGalleryRepository(),
      );
      final first = _photo(1);
      final second = _photo(2);
      controller.savedPhotos.assignAll({1: first, 2: second});
      controller.userTags.assignAll({
        1: ['Favorite'],
        2: ['Family'],
      });

      final photos = await controller.loadPhotosForFilters(
        selected: const {
          'user_tag': ['favorite'],
        },
      );

      expect(photos.map((photo) => photo.id), [1]);
    });

    test('intersects custom My Smruti and normal server filters', () async {
      final repository = _FakeGalleryRepository();
      Map<String, List<String>>? serverSelection;
      repository.onGetFilteredPhotos =
          ({
            required Map<String, List<String>> selected,
            int page = 1,
            int perPage = 60,
          }) async {
            serverSelection = selected;
            return [_photo(1), _photo(3)];
          };
      final controller = GalleryController(repository: repository);
      controller.mySmrutiPhotos.assignAll([
        _photo(1, location: 'Ahmedabad'),
        _photo(2, location: 'Ahmedabad'),
        _photo(3, location: 'Rajkot'),
      ]);

      final photos = await controller.loadPhotosForFilters(
        selected: const {
          'my_smruti_location': ['Ahmedabad'],
          'subject': ['Sabha'],
        },
      );

      expect(serverSelection, {
        'subject': ['Sabha'],
      });
      expect(photos.map((photo) => photo.id), [1]);
    });

    test('date availability request excludes custom keys', () async {
      final repository = _FakeGalleryRepository();
      Map<String, List<String>>? received;
      bool? receivedIncludeDates;
      repository.onGetFilters =
          ({
            int limit = 200,
            Map<String, List<String>> selected = const {},
            bool includeDates = false,
          }) async {
            received = selected;
            receivedIncludeDates = includeDates;
            return const [
              GalleryFilterGroup(
                slug: 'date',
                title: 'Date',
                options: [
                  GalleryFilterOption(
                    value: '2026-07-29',
                    label: '2026-07-29',
                    count: 5,
                  ),
                ],
              ),
            ];
          };
      final controller = GalleryController(repository: repository);

      final dates = await controller.loadAvailableFilterDates(
        selected: const {
          'country': ['India'],
          'my_smruti_location': ['Ahmedabad'],
          'user_tag': ['Favorite'],
        },
      );

      expect(receivedIncludeDates, isTrue);
      expect(received, {
        'country': ['India'],
      });
      expect(dates, {'2026-07-29'});
    });
  });
}
