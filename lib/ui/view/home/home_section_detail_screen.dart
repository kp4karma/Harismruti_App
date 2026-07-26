import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/controller/my_diary_controller.dart';
import 'package:harismruti/ui/controller/my_photos_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/ui/view/gallery/gallery_filter_sheet.dart';
import 'package:harismruti/ui/view/gallery/gallery_location_screen.dart';
import 'package:harismruti/ui/view/gallery/gallery_timeline_screen.dart';
import 'package:harismruti/ui/view/home/my_diary_smruti.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_string.dart';
import 'package:harismruti/widget/appbar/detail_appbar.dart';
import 'package:harismruti/widget/gallery/gallery_card_widgets.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

double _galleryPhotoAspectRatio(GalleryPhoto photo) {
  final width = photo.width;
  final height = photo.height;
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 1.15;
  }
  return (width / height).clamp(0.72, 1.5);
}

String _galleryPhotoTitle(
  GalleryPhoto photo, {
  Iterable<String> additionalTags = const [],
  String fallback = 'Smruti',
}) {
  final title = photo.title?.trim();
  if (title?.isNotEmpty == true) return title!;

  final tags = [
    ...photo.tags,
    ...additionalTags,
  ].map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toSet();
  return tags.isNotEmpty ? tags.join(', ') : fallback;
}

String _normalizeSearchText(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\u0080-\uFFFF]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class HomeSectionDetailScreen extends StatefulWidget {
  final String title;

  const HomeSectionDetailScreen({super.key, required this.title});

  @override
  State<HomeSectionDetailScreen> createState() =>
      _HomeSectionDetailScreenState();
}

class _HomeSectionDetailScreenState extends State<HomeSectionDetailScreen> {
  final GalleryController _controller = Get.find<GalleryController>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoadingRecentSearchPages = false;
  bool _isSearchingRecentTag = false;
  List<GalleryPhoto>? _recentTagSearchResults;
  int _recentTagSearchRequest = 0;

  @override
  void initState() {
    super.initState();
    if (_isMySmrutiTitle(widget.title) &&
        Get.isRegistered<MyPhotosController>()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<MyPhotosController>().refreshSmrutiFlow();
      });
    }
    _controller.loadFilters();
    _searchFocusNode.addListener(() => setState(() {}));
    _searchController.addListener(_handleSearchChanged);
    _scrollController.addListener(_maybeLoadMoreRecent);
  }

  bool _isMySmrutiTitle(String title) =>
      title == SmrutiSectionKeys.myPhotos ||
      title == 'My Phone' ||
      title == 'My Photos';

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    _loadRemainingRecentPhotosForSearch();
    _searchRecentByFilterValue();
  }

  Future<void> _searchRecentByFilterValue() async {
    if (widget.title != SmrutiSectionKeys.recent) return;
    final query = _query;
    final request = ++_recentTagSearchRequest;
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _isSearchingRecentTag = false;
          _recentTagSearchResults = null;
        });
      }
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || request != _recentTagSearchRequest) return;
    if (_controller.filters.isEmpty) {
      await _controller.loadFilters(force: true);
      if (!mounted || request != _recentTagSearchRequest) return;
    }

    final matches = <(String, String)>[];
    for (final group in _controller.filtersWithUserTags) {
      for (final option in group.options) {
        if (option.count <= 0) continue;
        if (_normalizeSearchText(option.label) == query ||
            _normalizeSearchText(option.value) == query) {
          matches.add((group.slug, option.value));
        }
      }
    }
    if (matches.isEmpty) {
      if (mounted && request == _recentTagSearchRequest) {
        setState(() {
          _isSearchingRecentTag = false;
          _recentTagSearchResults = null;
        });
      }
      return;
    }

    setState(() => _isSearchingRecentTag = true);
    try {
      final responses = await Future.wait(
        matches.map(
          (match) => _controller.loadPhotosForFilters(
            selected: {
              match.$1: [match.$2],
            },
          ),
        ),
      );
      if (!mounted || request != _recentTagSearchRequest) return;

      final unique = <int, GalleryPhoto>{};
      for (final photo in responses.expand((photos) => photos)) {
        unique[photo.id] = photo;
      }
      setState(() {
        _recentTagSearchResults = unique.values.toList(growable: false);
      });
    } catch (_) {
      if (mounted && request == _recentTagSearchRequest) {
        setState(() => _recentTagSearchResults = const []);
      }
    } finally {
      if (mounted && request == _recentTagSearchRequest) {
        setState(() => _isSearchingRecentTag = false);
      }
    }
  }

  Future<void> _loadRemainingRecentPhotosForSearch() async {
    if (widget.title != SmrutiSectionKeys.recent ||
        _query.isEmpty ||
        _isLoadingRecentSearchPages) {
      return;
    }

    _isLoadingRecentSearchPages = true;
    try {
      while (mounted &&
          _query.isNotEmpty &&
          _controller.hasMoreRecentPhotos.value) {
        if (_controller.isRecentPageLoading.value) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          continue;
        }

        final countBeforeLoad = _controller.recentPhotos.length;
        await _controller.loadMoreRecentPhotos();
        if (_controller.recentPhotos.length == countBeforeLoad) break;
      }
    } finally {
      _isLoadingRecentSearchPages = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F3),
      appBar: DetailAppbar(title: _appBarTitle()),
      body: ListenableBuilder(
        listenable: _searchController,
        builder: (context, _) => Obx(() {
          final items = _itemsForTitle(widget.title);
          final visibleItems =
              widget.title == SmrutiSectionKeys.recent &&
                  _query.isNotEmpty &&
                  _recentTagSearchResults != null
              ? _recentTagSearchResults!.cast<Object>()
              : _filterItems(items);
          final suggestions = _suggestionsForItems(items);

          return Stack(
            children: [
              Column(
                children: [
                  _SearchFilterBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onFilterTap: () => showGalleryFilterSheet(context),
                  ),
                  Expanded(
                    child: _isSearchingRecentTag
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : visibleItems.isEmpty
                        ? const GalleryEmptyState(
                            height: 260,
                            message: 'No smruti found',
                          )
                        : _buildSectionBody(visibleItems),
                  ),
                ],
              ),
              Positioned(
                left: 16,
                right: 78,
                top: 74,
                child: _SearchSuggestionsList(
                  suggestions: suggestions,
                  isVisible:
                      _searchFocusNode.hasFocus && suggestions.isNotEmpty,
                  onTap: _applySuggestion,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSectionBody(List<Object> visibleItems) {
    final cards = visibleItems.whereType<GalleryCard>().toList(growable: false);
    switch (widget.title) {
      case SmrutiSectionKeys.recent:
        return _buildRecentPhotoGallery(visibleItems);
      case SmrutiSectionKeys.withSmruti:
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => SizedBox(
            height: 255,
            child: GalleryWithFeatureCard(
              card: cards[index],
              headers: _controller.imageHeaders,
              width: double.infinity,
            ),
          ),
        );
      case SmrutiSectionKeys.ofSmruti:
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) => SizedBox(
            height: 248,
            child: _SubjectRibbonDetailCard(
              card: cards[index],
              headers: _controller.imageHeaders,
            ),
          ),
        );
      case SmrutiSectionKeys.ofDarshan:
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) => SizedBox(
            height: 235,
            child: _SmrutiOfGlowDetailCard(
              card: cards[index],
              headers: _controller.imageHeaders,
            ),
          ),
        );
      case SmrutiSectionKeys.location:
        return _buildLocationDetailGroups(cards);
      case SmrutiSectionKeys.album:
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => SizedBox(
            height: 255,
            child: GalleryMosaicCard(
              card: cards[index],
              headers: _controller.imageHeaders,
              width: double.infinity,
            ),
          ),
        );
      case SmrutiSectionKeys.yearCollection:
      case 'Collection':
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => SizedBox(
            height: 255,
            child: GalleryMosaicCard(
              card: cards[index],
              headers: _controller.imageHeaders,
              width: double.infinity,
            ),
          ),
        );
      case SmrutiSectionKeys.myFavorite:
      case 'My Favot':
      case 'My Favorites':
      case SmrutiSectionKeys.myPhotos:
      case 'My Phone':
      case 'My Photos':
        final photos = visibleItems.whereType<GalleryPhoto>().toList(
          growable: false,
        );
        final showPhotoTitles =
            widget.title == SmrutiSectionKeys.myFavorite ||
            widget.title == 'My Favot' ||
            widget.title == 'My Favorites';
        final showMySmrutiMetadata =
            widget.title == SmrutiSectionKeys.myPhotos ||
            widget.title == 'My Phone' ||
            widget.title == 'My Photos';
        return MasonryGridView.count(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: photos.length,
          crossAxisCount: MediaQuery.sizeOf(context).width >= 680 ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          itemBuilder: (context, index) => AspectRatio(
            aspectRatio: _galleryPhotoAspectRatio(photos[index]),
            child: _PhotoPosterCard(
              photo: photos[index],
              headers: _controller.imageHeaders,
              showTitle: showPhotoTitles || showMySmrutiMetadata,
              title: showMySmrutiMetadata
                  ? _galleryPhotoTitle(
                      photos[index],
                      additionalTags: _controller.tagsForPhoto(
                        photos[index].id,
                      ),
                    )
                  : null,
              dateLabel: showMySmrutiMetadata
                  ? _formatDate(
                      photos[index].eventDate ?? photos[index].takenAt,
                    )
                  : null,
              onTap: () => _openPhotoGallery(photos, index),
            ),
          ),
        );
      case SmrutiSectionKeys.myCollection:
      case 'My Collectino':
        final collections = visibleItems
            .whereType<_UserCollectionItem>()
            .toList(growable: false);
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: collections.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _UserCollectionPosterCard(
            item: collections[index],
            headers: _controller.imageHeaders,
            onTap: () => _openUserCollection(collections[index]),
          ),
        );
      case SmrutiSectionKeys.myDiary:
      case 'My Diray':
        final entries = visibleItems.whereType<DiaryEntry>().toList(
          growable: false,
        );
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _DiaryEntryPosterCard(
            entry: entries[index],
            headers: _controller.imageHeaders,
            onTap: () => _openDiaryEntry(entries[index]),
          ),
        );
      default:
        return _buildSimpleCardList(visibleItems);
    }
  }

  Widget _buildLocationDetailGroups(List<GalleryCard> cards) {
    final groupCount = (cards.length / 3).ceil();

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      itemCount: groupCount,
      itemBuilder: (context, index) {
        final firstIndex = index * 3;
        final secondIndex = firstIndex + 1;
        final thirdIndex = firstIndex + 2;
        final bottomCards = [
          if (secondIndex < cards.length) cards[secondIndex],
          if (thirdIndex < cards.length) cards[thirdIndex],
        ];
        final bigCard = GalleryGridCard(
          card: cards[firstIndex],
          headers: _controller.imageHeaders,
          aspectRatio: 1,
          fillParent: true,
          imageFit: BoxFit.fill,
        );
        final smallRow = Row(
          children: [
            for (var item = 0; item < bottomCards.length; item++) ...[
              Expanded(
                child: GalleryGridCard(
                  card: bottomCards[item],
                  headers: _controller.imageHeaders,
                  aspectRatio: 1,
                  fillParent: true,
                  imageFit: BoxFit.fill,
                ),
              ),
              if (item != bottomCards.length - 1) const SizedBox(width: 6),
            ],
          ],
        );

        return SizedBox(
          height: 310,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: index.isEven
                  ? [
                      Expanded(flex: 6, child: bigCard),
                      const SizedBox(height: 6),
                      Expanded(flex: 4, child: smallRow),
                    ]
                  : [
                      Expanded(flex: 4, child: smallRow),
                      const SizedBox(height: 6),
                      Expanded(flex: 6, child: bigCard),
                    ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentPhotoGallery(List<Object> visibleItems) {
    final photos = visibleItems.whereType<GalleryPhoto>().toList(
      growable: false,
    );
    final showFooter = _controller.isRecentPageLoading.value;
    final groupCount = (photos.length / 3).ceil();

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: groupCount + (showFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= groupCount) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          );
        }

        final start = index * 3;
        final groupPhotos = photos.skip(start).take(3).toList(growable: false);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRecentGalleryGroup(
            groupPhotos,
            start,
            index.isOdd,
            photos,
          ),
        );
      },
    );
  }

  Widget _buildRecentGalleryGroup(
    List<GalleryPhoto> groupPhotos,
    int startIndex,
    bool reverse,
    List<GalleryPhoto> allPhotos,
  ) {
    if (groupPhotos.length == 1) {
      return SizedBox(
        height: 232,
        child: _RecentGalleryTile(
          photo: groupPhotos.first,
          headers: _controller.imageHeaders,
          onTap: () => _openPhotoGallery(allPhotos, startIndex),
        ),
      );
    }

    if (groupPhotos.length == 2) {
      final first = Expanded(
        flex: 6,
        child: _RecentGalleryTile(
          photo: groupPhotos[0],
          headers: _controller.imageHeaders,
          onTap: () => _openPhotoGallery(allPhotos, startIndex),
        ),
      );
      final second = Expanded(
        flex: 5,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: 196,
            child: _RecentGalleryTile(
              photo: groupPhotos[1],
              headers: _controller.imageHeaders,
              onTap: () => _openPhotoGallery(allPhotos, startIndex + 1),
            ),
          ),
        ),
      );

      return SizedBox(
        height: 232,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: reverse
              ? [second, const SizedBox(width: 10), first]
              : [first, const SizedBox(width: 10), second],
        ),
      );
    }

    final largeTile = Expanded(
      flex: 7,
      child: _RecentGalleryTile(
        photo: groupPhotos[0],
        headers: _controller.imageHeaders,
        onTap: () => _openPhotoGallery(allPhotos, startIndex),
      ),
    );
    final stackedTiles = Expanded(
      flex: 5,
      child: Column(
        children: [
          Expanded(
            child: _RecentGalleryTile(
              photo: groupPhotos[1],
              headers: _controller.imageHeaders,
              onTap: () => _openPhotoGallery(allPhotos, startIndex + 1),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _RecentGalleryTile(
              photo: groupPhotos[2],
              headers: _controller.imageHeaders,
              onTap: () => _openPhotoGallery(allPhotos, startIndex + 2),
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      height: 276,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: reverse
            ? [stackedTiles, const SizedBox(width: 10), largeTile]
            : [largeTile, const SizedBox(width: 10), stackedTiles],
      ),
    );
  }

  Widget _buildSimpleCardList(List<Object> visibleItems) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: visibleItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = visibleItems[index];
        if (item is GalleryCard) {
          return _SectionCardTile(
            title: item.title,
            subtitle: item.subtitle.isNotEmpty
                ? item.subtitle
                : '${item.count ?? item.photos.length} Photos',
            imageUrl: item.coverUrl,
            headers: _controller.imageHeaders,
            onTap: () => _openCard(item),
          );
        }
        if (item is _UserCollectionItem) {
          return _SectionCardTile(
            title: item.title,
            subtitle: '${item.photos.length} Photos',
            imageUrl: item.coverUrl,
            headers: _controller.imageHeaders,
            onTap: () => _openUserCollection(item),
          );
        }
        if (item is DiaryEntry) {
          return _SectionCardTile(
            title: item.title,
            subtitle: _diarySubtitle(item),
            imageUrl: item.images.isEmpty ? '' : item.images.first,
            headers: _controller.imageHeaders,
            onTap: () => _openDiaryEntry(item),
          );
        }

        final photo = item as GalleryPhoto;
        return _SectionCardTile(
          title: _galleryPhotoTitle(
            photo,
            additionalTags: _controller.tagsForPhoto(photo.id),
          ),
          subtitle: photo.subtitle ?? _formatDate(photo.takenAt),
          imageUrl: photo.thumbnailUrl,
          headers: _controller.imageHeaders,
          onTap: () => _openPhotoList(visibleItems),
        );
      },
    );
  }

  String _appBarTitle() {
    switch (widget.title) {
      case SmrutiSectionKeys.myPhotos:
      case 'My Phone':
      case 'My Photos':
        if (!Get.isRegistered<MyPhotosController>()) return widget.title;
        final count = Get.find<MyPhotosController>().matchedPhotos.length;
        return count > 0 ? '${widget.title} ($count)' : widget.title;
      default:
        return widget.title;
    }
  }

  List<Object> _itemsForTitle(String title) {
    switch (title) {
      case SmrutiSectionKeys.recent:
        return _controller.recentPhotos.toList(growable: false);
      case SmrutiSectionKeys.yearCollection:
      case 'Collection':
        return _controller.collections.toList(growable: false);
      case SmrutiSectionKeys.withSmruti:
        return _controller.smrutiWith.toList(growable: false);
      case SmrutiSectionKeys.ofSmruti:
        return _controller.subjects.toList(growable: false);
      case SmrutiSectionKeys.ofDarshan:
        return _controller.smrutiOf.toList(growable: false);
      case SmrutiSectionKeys.location:
        return _controller.locations.toList(growable: false);
      case SmrutiSectionKeys.album:
        return _controller.albums.toList(growable: false);
      case SmrutiSectionKeys.myFavorite:
      case 'My Favot':
      case 'My Favorites':
        return _controller.favoritePhotos;
      case SmrutiSectionKeys.myCollection:
      case 'My Collectino':
        return _controller.userCollections
            .map(
              (collection) => _UserCollectionItem(
                title: collection.name,
                photos: _controller.photosForCollection(collection),
              ),
            )
            .toList(growable: false);
      case SmrutiSectionKeys.myDiary:
      case 'My Diray':
        if (!Get.isRegistered<MyDiaryController>()) return const [];
        return Get.find<MyDiaryController>().entries.toList(growable: false);
      case SmrutiSectionKeys.myPhotos:
      case 'My Phone':
      case 'My Photos':
        if (!Get.isRegistered<MyPhotosController>()) return const [];
        return Get.find<MyPhotosController>().matchedPhotos.toList(
          growable: false,
        );
      default:
        return const [];
    }
  }

  String get _query => _normalizeSearchText(_searchController.text);

  List<String> _photoTags(GalleryPhoto photo) {
    final tags = <String, String>{};
    for (final tag in [...photo.tags, ..._controller.tagsForPhoto(photo.id)]) {
      final clean = tag.trim();
      if (clean.isNotEmpty) tags.putIfAbsent(clean.toLowerCase(), () => clean);
    }
    return tags.values.toList(growable: false);
  }

  List<Object> _filterItems(List<Object> items) {
    final query = _query;
    if (query.isEmpty) return items;
    return items
        .where((item) {
          final text = switch (item) {
            GalleryCard() => '${item.title} ${item.subtitle}',
            GalleryPhoto() =>
              '${item.title ?? ''} ${item.subtitle ?? ''} '
                  '${_photoTags(item).join(' ')}',
            _UserCollectionItem() => item.title,
            DiaryEntry() => '${item.title} ${item.note} ${item.tags.join(' ')}',
            _ => '',
          };
          return _normalizeSearchText(text).contains(query);
        })
        .toList(growable: false);
  }

  List<_SearchSuggestion> _suggestionsForItems(List<Object> items) {
    final query = _query;
    final suggestions = <String, _SearchSuggestion>{};

    if (widget.title == SmrutiSectionKeys.recent) {
      for (final group in _controller.filtersWithUserTags) {
        for (final option in group.options) {
          if (option.count <= 0) continue;
          final searchable = _normalizeSearchText(option.label);
          if (query.isNotEmpty && !searchable.contains(query)) continue;
          suggestions.putIfAbsent(
            searchable,
            () => _SearchSuggestion(
              title: option.label,
              subtitle: group.title,
              icon: CupertinoIcons.tag,
            ),
          );
        }
      }
      return suggestions.values.toList(growable: false);
    }

    for (final item in items) {
      if (item is GalleryPhoto) {
        for (final tag in _photoTags(item)) {
          final searchable = _normalizeSearchText(tag);
          if (query.isNotEmpty && !searchable.contains(query)) continue;
          suggestions.putIfAbsent(
            searchable,
            () => _SearchSuggestion(
              title: tag,
              subtitle: 'Tag',
              icon: CupertinoIcons.tag,
            ),
          );
        }
        continue;
      }

      final suggestion = _suggestionForItem(item);
      if (suggestion == null) continue;
      final searchable = _normalizeSearchText(
        '${suggestion.title} ${suggestion.subtitle}',
      );
      if (query.isNotEmpty && !searchable.contains(query)) continue;

      final key = suggestion.title.toLowerCase();
      suggestions.putIfAbsent(key, () => suggestion);
    }

    return suggestions.values.toList(growable: false);
  }

  _SearchSuggestion? _suggestionForItem(Object item) {
    return switch (item) {
      GalleryCard() => _SearchSuggestion(
        title: item.title,
        subtitle: item.subtitle.isNotEmpty
            ? item.subtitle
            : '${item.count ?? item.photos.length} Photos',
        icon: CupertinoIcons.photo_on_rectangle,
      ),
      GalleryPhoto() => null,
      _UserCollectionItem() => _SearchSuggestion(
        title: item.title,
        subtitle: '${item.photos.length} Photos',
        icon: CupertinoIcons.collections,
      ),
      DiaryEntry() => _SearchSuggestion(
        title: item.title,
        subtitle: _diarySubtitle(item),
        icon: CupertinoIcons.book,
      ),
      _ => null,
    };
  }

  void _applySuggestion(_SearchSuggestion suggestion) {
    _searchController.text = suggestion.title;
    _searchController.selection = TextSelection.collapsed(
      offset: _searchController.text.length,
    );
    _searchFocusNode.unfocus();
  }

  void _openCard(GalleryCard card) {
    if (card.type == 'collection') {
      final year = int.tryParse(card.value) ?? card.id;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GalleryTimelineScreen(year: year)),
      );
      return;
    }

    if (card.type == 'location') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GalleryLocationScreen(card: card)),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GalleryDetailScreen.fromCard(card)),
    );
  }

  void _openUserCollection(_UserCollectionItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryDetailScreen(
          title: item.title,
          subtitle: '${item.photos.length} Photos',
          coverUrl: item.coverUrl,
          loader: () async => item.photos,
        ),
      ),
    );
  }

  void _openDiaryEntry(DiaryEntry entry) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) =>
            DiaryEntryDetailScreen(date: entry.date, entryId: entry.id),
      ),
    );
  }

  void _openPhotoList(List<Object> items) {
    final photos = items.whereType<GalleryPhoto>().toList(growable: false);
    _openPhotoGallery(photos, 0);
  }

  void _openPhotoGallery(List<GalleryPhoto> photos, int initialIndex) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => GalleryFullscreenViewer(
          photos: photos,
          initialIndex: initialIndex,
          title: widget.title,
          isRecentFeed:
              widget.title == SmrutiSectionKeys.recent && _query.isEmpty,
        ),
      ),
    );
  }

  void _maybeLoadMoreRecent() {
    if (widget.title != SmrutiSectionKeys.recent) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.extentAfter > 420) return;
    _controller.loadMoreRecentPhotos();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Photo';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _diarySubtitle(DiaryEntry entry) {
    final parts = [
      _formatDate(entry.date),
      if (entry.locationName?.trim().isNotEmpty == true) entry.locationName!,
      if (entry.tags.isNotEmpty) entry.tags.take(2).join(', '),
    ];
    return parts.join(' | ');
  }
}

class _SearchFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onFilterTap;

  const _SearchFilterBar({
    required this.controller,
    required this.focusNode,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search smruti',
                    prefixIcon: Icon(
                      CupertinoIcons.search,
                      color: primaryColor,
                    ),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        return GestureDetector(
                          onTap: controller.clear,
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: Colors.black.withAlpha(95),
                          ),
                        );
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white.withAlpha(230),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSuggestion {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SearchSuggestion({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _SearchSuggestionsList extends StatelessWidget {
  final List<_SearchSuggestion> suggestions;
  final bool isVisible;
  final ValueChanged<_SearchSuggestion> onTap;

  const _SearchSuggestionsList({
    required this.suggestions,
    required this.isVisible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: isVisible
          ? Material(
              key: const ValueKey('search-suggestions'),
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 246),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(238),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: primaryColor.withAlpha(16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: suggestions.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 58,
                        color: primaryColor.withAlpha(12),
                      ),
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        return InkWell(
                          onTap: () => onTap(suggestion),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withAlpha(18),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(
                                    suggestion.icon,
                                    size: 18,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        suggestion.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF322318),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      if (suggestion.subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          suggestion.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.black.withAlpha(120),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(
                                  CupertinoIcons.arrow_up_left,
                                  color: primaryColor.withAlpha(150),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('search-suggestions-empty')),
    );
  }
}

class _SubjectRibbonDetailCard extends StatelessWidget {
  final GalleryCard card;
  final Map<String, String>? headers;

  const _SubjectRibbonDetailCard({required this.card, required this.headers});

  @override
  Widget build(BuildContext context) {
    final countText = card.count?.toString() ?? card.subtitle;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GalleryDetailScreen.fromCard(card)),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withAlpha(20),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetworkImageWithLoader(
              imageUrl: card.coverUrl,
              title: card.title,
              headers: headers,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(8),
                    Colors.black.withAlpha(30),
                    Colors.black.withAlpha(170),
                  ],
                  stops: const [0.15, 0.55, 1],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(220),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      countText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmrutiOfGlowDetailCard extends StatelessWidget {
  final GalleryCard card;
  final Map<String, String>? headers;

  const _SmrutiOfGlowDetailCard({required this.card, required this.headers});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GalleryDetailScreen.fromCard(card)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _SmrutiOfImageGlow(card: card, headers: headers),
          ),
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withAlpha(52),
                    Colors.black.withAlpha(18),
                    Colors.black.withAlpha(72),
                  ],
                ),
                border: Border.all(color: Colors.white.withAlpha(82)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: card.coverUrl.isEmpty
                          ? ColoredBox(
                              color: primaryColor.withAlpha(28),
                              child: Center(
                                child: Icon(
                                  CupertinoIcons.photo,
                                  color: primaryColor,
                                ),
                              ),
                            )
                          : NetworkImageWithLoader(
                              imageUrl: card.coverUrl,
                              title: card.title,
                              headers: headers,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    card.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withAlpha(205),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmrutiOfImageGlow extends StatelessWidget {
  final GalleryCard card;
  final Map<String, String>? headers;

  const _SmrutiOfImageGlow({required this.card, required this.headers});

  @override
  Widget build(BuildContext context) {
    if (card.coverUrl.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: primaryColor.withAlpha(54),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withAlpha(62),
              blurRadius: 22,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Transform.scale(
              scale: 1.18,
              child: Opacity(
                opacity: 0.82,
                child: NetworkImageWithLoader(
                  imageUrl: card.coverUrl,
                  title: card.title,
                  headers: headers,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(36),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCardTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final Map<String, String>? headers;
  final VoidCallback onTap;

  const _SectionCardTile({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 74,
                  height: 74,
                  child: imageUrl.isEmpty
                      ? ColoredBox(
                          color: primaryColor.withAlpha(18),
                          child: Icon(Icons.photo, color: primaryColor),
                        )
                      : NetworkImageWithLoader(
                          imageUrl: imageUrl,
                          title: title,
                          headers: headers,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF322318),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withAlpha(135),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPosterCard extends StatelessWidget {
  final GalleryPhoto photo;
  final Map<String, String>? headers;
  final bool showTitle;
  final String? title;
  final String? dateLabel;
  final VoidCallback onTap;

  const _PhotoPosterCard({
    required this.photo,
    required this.headers,
    this.showTitle = true,
    this.title,
    this.dateLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetworkImageWithLoader(
              imageUrl: photo.thumbnailUrl,
              title: '',
              headers: headers,
            ),
            if (showTitle) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(18),
                      Colors.black.withAlpha(135),
                    ],
                    stops: const [0.45, 0.72, 1],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title ?? _galleryPhotoTitle(photo),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    if (dateLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        dateLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withAlpha(220),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentGalleryTile extends StatelessWidget {
  final GalleryPhoto photo;
  final Map<String, String>? headers;
  final VoidCallback onTap;

  const _RecentGalleryTile({
    required this.photo,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = _galleryPhotoTitle(photo, fallback: 'Recent Smruti');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetworkImageWithLoader(
              imageUrl: photo.thumbnailUrl,
              title: title,
              headers: headers,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(16),
                    Colors.black.withAlpha(132),
                  ],
                  stops: const [0.44, 0.72, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCollectionPosterCard extends StatelessWidget {
  final _UserCollectionItem item;
  final Map<String, String>? headers;
  final VoidCallback onTap;

  const _UserCollectionPosterCard({
    required this.item,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.photos.isEmpty ? null : onTap,
      child: Container(
        height: 218,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.coverUrl.isNotEmpty)
              NetworkImageWithLoader(
                imageUrl: item.coverUrl,
                title: item.title,
                headers: headers,
              )
            else
              ColoredBox(
                color: const Color(0xFFF4F1EE),
                child: Icon(Icons.collections, color: primaryColor, size: 34),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(25),
                    Colors.black.withAlpha(135),
                  ],
                  stops: const [0.42, 0.7, 1],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.photos.length} photos',
                          style: TextStyle(
                            color: Colors.white.withAlpha(215),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryEntryPosterCard extends StatelessWidget {
  final DiaryEntry entry;
  final Map<String, String>? headers;
  final VoidCallback onTap;

  const _DiaryEntryPosterCard({
    required this.entry,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image = entry.images.isEmpty ? '' : entry.images.first;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 106,
              child: image.isEmpty
                  ? ColoredBox(
                      color: primaryColor.withAlpha(18),
                      child: Icon(CupertinoIcons.book, color: primaryColor),
                    )
                  : NetworkImageWithLoader(
                      imageUrl: image,
                      title: entry.title,
                      headers: headers,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF322318),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withAlpha(135),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(CupertinoIcons.chevron_right, color: primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCollectionItem {
  final String title;
  final List<GalleryPhoto> photos;

  const _UserCollectionItem({required this.title, required this.photos});

  String get coverUrl => photos.isEmpty ? '' : photos.first.thumbnailUrl;
}
