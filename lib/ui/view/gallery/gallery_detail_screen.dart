import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/api/repositories/gallery_repository.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_location_screen.dart';
import 'package:harismruti/ui/view/home/my_diary_smruti.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const double _homeAppbarBlurSigma = 24;
const int _homeAppbarGlassAlpha = 125;

double _galleryPhotoAspectRatio(GalleryPhoto photo) {
  final width = photo.width;
  final height = photo.height;
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 1.15;
  }
  return (width / height).clamp(0.72, 1.5);
}

class GalleryDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? coverUrl;
  final Future<List<GalleryPhoto>> Function() loader;
  final Future<List<GalleryPhoto>> Function(int page)? loadMore;
  final bool showRecentPhotoMetadata;
  final List<String> filterLabels;

  const GalleryDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loader,
    this.loadMore,
    this.coverUrl,
    this.showRecentPhotoMetadata = false,
    this.filterLabels = const [],
  });

  factory GalleryDetailScreen.fromCard(GalleryCard card) {
    final controller = Get.find<GalleryController>();
    return GalleryDetailScreen(
      title: card.title,
      subtitle: card.subtitle,
      coverUrl: card.coverUrl,
      loader: () => controller.loadPhotosForCard(card),
      loadMore: (page) => controller.loadPhotosForCard(card, page: page),
    );
  }

  factory GalleryDetailScreen.fromFilter({
    required String title,
    required String slug,
    required String value,
    required int count,
  }) {
    final controller = Get.find<GalleryController>();
    return GalleryDetailScreen(
      title: value,
      subtitle: '$title - $count Photos',
      loader: () => controller.loadPhotosForFilter(slug: slug, value: value),
      loadMore: (page) =>
          controller.loadPhotosForFilter(slug: slug, value: value, page: page),
    );
  }

  factory GalleryDetailScreen.fromFilters({
    required String title,
    required String subtitle,
    required Map<String, List<String>> selected,
    required List<String> filterLabels,
  }) {
    final controller = Get.find<GalleryController>();
    return GalleryDetailScreen(
      title: title,
      subtitle: subtitle,
      filterLabels: filterLabels,
      loader: () => controller.loadPhotosForFilters(selected: selected),
      loadMore: (page) =>
          controller.loadPhotosForFilters(selected: selected, page: page),
    );
  }

  @override
  State<GalleryDetailScreen> createState() => _GalleryDetailScreenState();
}

class _GalleryDetailScreenState extends State<GalleryDetailScreen> {
  static const int _perPage = 120;

  final GalleryController _galleryController = Get.find<GalleryController>();
  final ScrollController _scrollController = ScrollController();
  final List<GalleryPhoto> _photos = [];
  final GalleryRepository _repository = const GalleryRepository();
  final Set<int> _ignoredPhotoIds = {};
  final Set<int> _selectedPhotoIds = {};

  bool _initialLoading = true;
  bool _allowIgnore = false;
  bool _selectionMode = false;
  bool _isIgnoring = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _failed = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final features = await _repository.getMobileFeatures();
      _allowIgnore = features['allow_ignore'] == true;
      _ignoredPhotoIds.addAll(
        (features['ignored_photo_ids'] is List
                ? features['ignored_photo_ids'] as List
                : const [])
            .map((value) => int.tryParse('$value'))
            .whereType<int>(),
      );
      final photos = await widget.loader();
      debugPrint(
        'GalleryDetailScreen[${widget.title}]: initial load returned=${photos.length}',
      );
      if (!mounted) return;
      setState(() {
        _photos
          ..clear()
          ..addAll(
            _dedupe(
              photos,
              existing: const [],
            ).where((photo) => !_ignoredPhotoIds.contains(photo.id)),
          );
        _page = 1;
        _hasMore = widget.loadMore != null && photos.length >= _perPage;
        _initialLoading = false;
        _failed = false;
      });
    } catch (e) {
      debugPrint(
        'GalleryDetailScreen[${widget.title}]: initial load failed, $e',
      );
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _failed = true;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 600) return;
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || widget.loadMore == null) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    try {
      final photos = await widget.loadMore!(nextPage);
      debugPrint(
        'GalleryDetailScreen[${widget.title}]: page=$nextPage returned=${photos.length}',
      );
      if (!mounted) return;
      final newPhotos = _dedupe(
        photos,
        existing: _photos,
      ).where((photo) => !_ignoredPhotoIds.contains(photo.id));
      setState(() {
        _photos.addAll(newPhotos);
        _page = nextPage;
        _hasMore = photos.length >= _perPage;
        _isLoadingMore = false;
      });
      debugPrint(
        'GalleryDetailScreen[${widget.title}]: page=$nextPage '
        'totalDisplayed=${_photos.length} hasMore=$_hasMore',
      );
    } catch (e) {
      debugPrint(
        'GalleryDetailScreen[${widget.title}]: page=$nextPage failed, $e',
      );
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _toggleSelection(GalleryPhoto photo) {
    if (!_allowIgnore || photo.id <= 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectionMode = true;
      if (!_selectedPhotoIds.add(photo.id)) _selectedPhotoIds.remove(photo.id);
      if (_selectedPhotoIds.isEmpty) _selectionMode = false;
    });
  }

  void _closeSelection() {
    setState(() {
      _selectionMode = false;
      _selectedPhotoIds.clear();
    });
  }

  Future<void> _ignoreSelected() async {
    if (_selectedPhotoIds.isEmpty || _isIgnoring) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Ignore selected photos?'),
        content: Text(
          '${_selectedPhotoIds.length} selected photos will be hidden from your gallery.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ignore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isIgnoring = true);
    try {
      final ignored = await _repository.ignorePhotos(_selectedPhotoIds);
      if (!mounted) return;
      setState(() {
        _ignoredPhotoIds.addAll(ignored);
        _photos.removeWhere((photo) => ignored.contains(photo.id));
        _selectedPhotoIds.clear();
        _selectionMode = false;
      });
      TopNotification.success('${ignored.length} photos ignored');
    } catch (error) {
      TopNotification.error(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isIgnoring = false);
    }
  }

  List<GalleryPhoto> _dedupe(
    List<GalleryPhoto> incoming, {
    required List<GalleryPhoto> existing,
  }) {
    final existingIds = existing
        .where((photo) => photo.id > 0)
        .map((photo) => photo.id)
        .toSet();
    final existingUrls = existing
        .where((photo) => photo.id <= 0)
        .map((photo) => photo.thumbnailUrl)
        .toSet();
    return incoming.where((photo) {
      if (photo.id > 0) return existingIds.add(photo.id);
      return photo.thumbnailUrl.isNotEmpty &&
          existingUrls.add(photo.thumbnailUrl);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cover = widget.coverUrl?.isNotEmpty == true
        ? widget.coverUrl!
        : _photos.isNotEmpty
        ? _photos.first.thumbnailUrl
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F3),
      floatingActionButton: _selectionMode
          ? FloatingActionButton.extended(
              onPressed: _isIgnoring ? null : _ignoreSelected,
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              icon: _isIgnoring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(CupertinoIcons.eye_slash_fill),
              label: Text('Ignore ${_selectedPhotoIds.length}'),
            )
          : null,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _MusicStyleHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            filterLabels: widget.filterLabels,
            coverUrl: cover,
            headers: _galleryController.imageHeaders,
            allowIgnore: _allowIgnore,
            selectionMode: _selectionMode,
            selectedCount: _selectedPhotoIds.length,
            onStartSelection: () => setState(() => _selectionMode = true),
            onCloseSelection: _closeSelection,
          ),
          if (_initialLoading)
            const SliverPadding(
              padding: EdgeInsets.all(16),
              sliver: _DetailShimmerMosaic(),
            )
          else if (_photos.isEmpty)
            SliverToBoxAdapter(
              child: GalleryEmptyState(
                height: 260,
                message: _failed ? 'Unable to load photos' : 'No photos found',
              ),
            )
          else ...[
            _MosaicPhotoSliver(
              photos: _photos,
              title: widget.title,
              headers: _galleryController.imageHeaders,
              showRecentPhotoMetadata: widget.showRecentPhotoMetadata,
              selectionMode: _selectionMode,
              selectedPhotoIds: _selectedPhotoIds,
              onToggleSelection: _toggleSelection,
            ),
            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ],
      ),
    );
  }
}

class _MusicStyleHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String coverUrl;
  final List<String> filterLabels;
  final Map<String, String>? headers;
  final bool allowIgnore;
  final bool selectionMode;
  final int selectedCount;
  final VoidCallback onStartSelection;
  final VoidCallback onCloseSelection;

  const _MusicStyleHeader({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.filterLabels,
    required this.headers,
    required this.allowIgnore,
    required this.selectionMode,
    required this.selectedCount,
    required this.onStartSelection,
    required this.onCloseSelection,
  });

  @override
  Widget build(BuildContext context) {
    const expandedHeight = 430.0;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      centerTitle: true,
      expandedHeight: expandedHeight,
      backgroundColor: Colors.transparent,
      title: selectionMode
          ? Text(
              '$selectedCount selected',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
      surfaceTintColor: Colors.transparent,
      leading: _GlassIconButton(
        icon: selectionMode
            ? CupertinoIcons.xmark
            : CupertinoIcons.chevron_left,
        onTap: selectionMode ? onCloseSelection : () => Navigator.pop(context),
      ),
      actions: [
        if (allowIgnore)
          _GlassIconButton(
            icon: selectionMode
                ? CupertinoIcons.checkmark_alt_circle_fill
                : CupertinoIcons.checkmark_alt_circle,
            onTap: selectionMode ? onCloseSelection : onStartSelection,
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final collapsedHeight =
              MediaQuery.of(context).padding.top + kToolbarHeight + 10;
          final progress =
              ((expandedHeight - constraints.biggest.height) /
                      (expandedHeight - collapsedHeight))
                  .clamp(0.0, 1.0);
          final glassOpacity = ((progress - 0.62) / 0.38).clamp(0.0, 1.0);
          final expandedContentOpacity = (1.0 - (progress / 0.72)).clamp(
            0.0,
            1.0,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl.isNotEmpty)
                NetworkImageWithLoader(
                  imageUrl: coverUrl,
                  title: title,
                  headers: headers,
                )
              else
                const GalleryShimmerBox(borderRadius: 0),
              Container(color: Colors.white.withAlpha(92)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(24),
                      const Color(0xFFF8F6F3),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: IgnorePointer(
                  ignoring: expandedContentOpacity == 0,
                  child: Opacity(
                    opacity: expandedContentOpacity,
                    child: _ExpandedHeroHeaderContent(
                      title: title,
                      subtitle: subtitle,
                      filterLabels: filterLabels,
                      coverUrl: coverUrl,
                      headers: headers,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: collapsedHeight,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: glassOpacity,
                    child: const _HeaderGlassLayer(),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 72,
                right: 72,
                height: kToolbarHeight,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: glassOpacity,
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderGlassLayer extends StatelessWidget {
  const _HeaderGlassLayer();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _homeAppbarBlurSigma,
          sigmaY: _homeAppbarBlurSigma,
        ),
        child: Container(color: Colors.white.withAlpha(_homeAppbarGlassAlpha)),
      ),
    );
  }
}

class _ExpandedHeroHeaderContent extends StatelessWidget {
  final String title;
  final String subtitle;
  final String coverUrl;
  final List<String> filterLabels;
  final Map<String, String>? headers;

  const _ExpandedHeroHeaderContent({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.filterLabels,
    required this.headers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 222,
          height: 222,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(74),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: coverUrl.isEmpty
              ? const GalleryShimmerBox(borderRadius: 28)
              : NetworkImageWithLoader(
                  imageUrl: coverUrl,
                  title: title,
                  headers: headers,
                ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        if (filterLabels.isEmpty)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primaryColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          SizedBox(
            height: 26,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (final label in filterLabels) ...[
                    _SelectedFilterChip(label: label),
                    const SizedBox(width: 5),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectedFilterChip extends StatelessWidget {
  final String label;

  const _SelectedFilterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withAlpha(55)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: primaryColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MosaicPhotoSliver extends StatelessWidget {
  final List<GalleryPhoto> photos;
  final String title;
  final Map<String, String>? headers;
  final bool showRecentPhotoMetadata;
  final bool selectionMode;
  final Set<int> selectedPhotoIds;
  final ValueChanged<GalleryPhoto> onToggleSelection;

  const _MosaicPhotoSliver({
    required this.photos,
    required this.title,
    required this.headers,
    required this.showRecentPhotoMetadata,
    required this.selectionMode,
    required this.selectedPhotoIds,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: isTablet(context) ? 3 : 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childCount: photos.length,
        itemBuilder: (context, index) => AspectRatio(
          aspectRatio: _galleryPhotoAspectRatio(photos[index]),
          child: _MosaicTile(
            photo: photos[index],
            allPhotos: photos,
            index: index,
            title: title,
            headers: headers,
            showRecentPhotoMetadata: showRecentPhotoMetadata,
            selectionMode: selectionMode,
            selected: selectedPhotoIds.contains(photos[index].id),
            onToggleSelection: onToggleSelection,
          ),
        ),
      ),
    );
  }
}

class _MosaicTile extends StatelessWidget {
  final GalleryPhoto photo;
  final List<GalleryPhoto> allPhotos;
  final int index;
  final String title;
  final Map<String, String>? headers;
  final bool showRecentPhotoMetadata;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<GalleryPhoto> onToggleSelection;

  const _MosaicTile({
    required this.photo,
    required this.allPhotos,
    required this.index,
    required this.title,
    required this.headers,
    required this.showRecentPhotoMetadata,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GalleryController>();
    return GestureDetector(
      onTap: () {
        if (selectionMode) {
          onToggleSelection(photo);
          return;
        }
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => GalleryFullscreenViewer(
              photos: allPhotos,
              initialIndex: index,
              title: title,
              showRecentPhotoMetadata: showRecentPhotoMetadata,
            ),
          ),
        );
      },
      onLongPress: () => onToggleSelection(photo),
      child: Hero(
        tag: 'photo-${photo.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: NetworkImageWithLoader(
                  imageUrl: photo.thumbnailUrl,
                  title: photo.title ?? title,
                  headers: headers,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 54,
                child: Obx(() {
                  final tags = _combinedTags(
                    photo.tags,
                    controller.tagsForPhoto(photo.id),
                  );
                  if (tags.isEmpty) return const SizedBox.shrink();
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(35),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              if (selectionMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    selected
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    color: selected ? primaryColor : Colors.white,
                    size: 27,
                    shadows: const [
                      Shadow(color: Colors.black45, blurRadius: 5),
                    ],
                  ),
                ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Obx(() {
                  final tags = _combinedTags(
                    photo.tags,
                    controller.tagsForPhoto(photo.id),
                  );
                  if (tags.isEmpty) return const SizedBox.shrink();
                  return _PhotoTagStrip(tags: tags.take(3).toList());
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _combinedTags(List<String> baseTags, List<String> userTags) {
    final tags = <String, String>{};
    for (final tag in [...baseTags, ...userTags]) {
      final clean = tag.trim();
      if (clean.isEmpty) continue;
      tags.putIfAbsent(clean.toLowerCase(), () => clean);
    }
    return tags.values.toList();
  }
}

class _PhotoTagStrip extends StatelessWidget {
  final List<String> tags;

  const _PhotoTagStrip({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final tag in tags)
            Container(
              constraints: const BoxConstraints(maxWidth: 108),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(224),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withAlpha(180)),
              ),
              child: Text(
                tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GalleryFullscreenViewer extends StatefulWidget {
  final List<GalleryPhoto> photos;
  final int initialIndex;
  final String title;
  final bool showRecentPhotoMetadata;
  final bool isRecentFeed;

  const GalleryFullscreenViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.title,
    this.showRecentPhotoMetadata = false,
    this.isRecentFeed = false,
  });

  @override
  State<GalleryFullscreenViewer> createState() =>
      _GalleryFullscreenViewerState();
}

class _GalleryFullscreenViewerState extends State<GalleryFullscreenViewer>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final ScrollController _thumbnailScrollController;
  late final TransformationController _transformationController;
  late final AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  VoidCallback? _zoomAnimationListener;
  AnimationStatusListener? _zoomAnimationStatusListener;
  late int _index;
  final GalleryController _controller = Get.find<GalleryController>();
  final GalleryRepository _repository = const GalleryRepository();
  final Map<int, Future<GalleryPhotoAttributes>> _attributesCache = {};
  final Map<int, Future<String>> _imageSizeCache = {};
  final Map<int, Future<String>> _storageSizeCache = {};
  bool _showFavoriteBurst = false;
  bool _chromeVisible = true;
  bool _isZoomed = false;
  bool _zoomModeActive = false;
  bool _infoPanelOpen = false;
  bool _allowIgnore = false;
  bool _isIgnoring = false;
  Offset _lastDoubleTapPosition = Offset.zero;
  int _gesturePointerCount = 1;
  late final List<GalleryPhoto> _localPhotos;

  @override
  void initState() {
    super.initState();
    _localPhotos = List<GalleryPhoto>.of(widget.photos);
    _index = widget.initialIndex;
    _loadIgnoreFeature();
    _pageController = PageController(initialPage: widget.initialIndex);
    _thumbnailScrollController = ScrollController();
    _transformationController = TransformationController();
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (widget.isRecentFeed) {
      _thumbnailScrollController.addListener(_onThumbnailScroll);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheAround(_index);
      _centerThumbnail(_index, animated: false);
    });
  }

  void _onThumbnailScroll() {
    if (!_thumbnailScrollController.hasClients) return;
    if (_thumbnailScrollController.position.extentAfter > 200) return;
    _maybeLoadMoreRecent(_photosList.length - 1);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _pageController.dispose();
    if (widget.isRecentFeed) {
      _thumbnailScrollController.removeListener(_onThumbnailScroll);
    }
    _thumbnailScrollController.dispose();
    _clearZoomAnimation();
    _zoomAnimationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  List<GalleryPhoto> get _photosList =>
      widget.isRecentFeed ? _controller.recentPhotos : _localPhotos;

  GalleryPhoto get _photo => _photosList[_index];

  void _maybeLoadMoreRecent(int viewedIndex) {
    if (!widget.isRecentFeed) return;
    if (viewedIndex < _photosList.length - 6) return;
    if (_controller.isRecentPageLoading.value) return;
    if (!_controller.hasMoreRecentPhotos.value) return;
    debugPrint(
      'GalleryFullscreenViewer: requesting more recent photos '
      '(viewedIndex=$viewedIndex, loaded=${_photosList.length})',
    );
    _controller.loadMoreRecentPhotos();
  }

  Future<GalleryPhotoAttributes> _attributesFor(int photoId) {
    return _attributesCache.putIfAbsent(
      photoId,
      () => _controller.loadPhotoAttributes(photoId),
    );
  }

  Future<String> _imageSizeFor(GalleryPhoto photo) {
    return _imageSizeCache.putIfAbsent(photo.id, () async {
      final metadataSize = _formatPhotoDimensions(photo.width, photo.height);
      if (metadataSize != null) return metadataSize;

      final fullImageSize = await _imageDimensionsFromProvider(photo.fullUrl);
      if (fullImageSize != null) return fullImageSize;

      final downloadedFullSize = await _imageDimensionsFromBytes(photo.fullUrl);
      if (downloadedFullSize != null) return downloadedFullSize;

      final thumbnailSize = await _imageDimensionsFromProvider(
        photo.thumbnailUrl,
      );
      if (thumbnailSize != null) return thumbnailSize;

      final downloadedThumbnailSize = await _imageDimensionsFromBytes(
        photo.thumbnailUrl,
      );
      return downloadedThumbnailSize ?? 'Not available';
    });
  }

  Future<String?> _imageDimensionsFromProvider(String url) async {
    if (url.isEmpty || !mounted) return null;

    final completer = Completer<String?>();
    try {
      final provider = CachedNetworkImageProvider(
        url,
        headers: _controller.imageHeaders,
      );
      late final ImageStreamListener listener;
      final stream = provider.resolve(createLocalImageConfiguration(context));
      listener = ImageStreamListener(
        (image, _) {
          stream.removeListener(listener);
          completer.complete(
            _formatPhotoDimensions(image.image.width, image.image.height),
          );
        },
        onError: (error, stackTrace) {
          stream.removeListener(listener);
          completer.complete(null);
        },
      );
      stream.addListener(listener);
      return completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          stream.removeListener(listener);
          return null;
        },
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _imageDimensionsFromBytes(String url) async {
    if (url.isEmpty) return null;
    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(
          headers: _controller.imageHeaders,
          responseType: ResponseType.bytes,
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      final image = await decodeImageFromList(Uint8List.fromList(data));
      return _formatPhotoDimensions(image.width, image.height);
    } catch (_) {
      return null;
    }
  }

  Future<String> _storageSizeFor(GalleryPhoto photo) {
    return _storageSizeCache.putIfAbsent(photo.id, () async {
      final metadataSize = _formatStorageSize(
        fileSizeBytes: photo.fileSizeBytes,
        fileSizeLabel: photo.fileSizeLabel,
      );
      if (metadataSize != null) return metadataSize;

      try {
        final response = await Dio().head(
          photo.fullUrl,
          options: Options(headers: _controller.imageHeaders),
        );
        final contentLength = int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '',
        );
        return _formatBytes(contentLength) ?? 'Not available';
      } catch (_) {
        return 'Not available';
      }
    });
  }

  void _precacheAround(int centerIndex) {
    if (!mounted) return;
    for (final index in [centerIndex - 1, centerIndex, centerIndex + 1]) {
      if (index < 0 || index >= _photosList.length) continue;
      final photo = _photosList[index];
      precacheImage(
        CachedNetworkImageProvider(
          photo.fullUrl,
          headers: _controller.imageHeaders,
        ),
        context,
      );
      _attributesFor(photo.id);
    }
  }

  void _centerThumbnail(int index, {bool animated = true}) {
    if (!_thumbnailScrollController.hasClients) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final target = (index * 34.0) - (screenWidth / 2) + 17;
    final offset = target.clamp(
      0.0,
      _thumbnailScrollController.position.maxScrollExtent,
    );
    if (animated) {
      _thumbnailScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      _thumbnailScrollController.jumpTo(offset);
    }
  }

  Future<void> _sharePhoto() async {
    final url = _photo.fullUrl.isNotEmpty
        ? _photo.fullUrl
        : _photo.thumbnailUrl;
    if (url.isEmpty) {
      TopNotification.error('Photo is not ready to share');
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = _shareFileName(url);
      final filePath = '${tempDir.path}${Platform.pathSeparator}$fileName';
      await Dio().download(
        url,
        filePath,
        options: Options(
          headers: _controller.imageHeaders,
          responseType: ResponseType.bytes,
        ),
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath, mimeType: _shareMimeType(fileName))],
        ),
      );
    } catch (_) {
      TopNotification.error('Unable to share this photo');
    }
  }

  String _shareFileName(String url) {
    final parsed = Uri.tryParse(url);
    final path = parsed?.path ?? '';
    final extension = path.toLowerCase().endsWith('.png')
        ? 'png'
        : path.toLowerCase().endsWith('.webp')
        ? 'webp'
        : 'jpg';
    return 'harismruti-${_photo.id}.$extension';
  }

  String _shareMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _playFavoriteBurst() {
    HapticFeedback.mediumImpact();
    setState(() => _showFavoriteBurst = true);
    Future.delayed(const Duration(milliseconds: 720), () {
      if (mounted) setState(() => _showFavoriteBurst = false);
    });
  }

  void _toggleFavorite() {
    if (!AuthRedirectHelper.ensureLoggedIn()) return;
    final wasFavorite = _controller.isFavorite(_photo.id);
    _controller.toggleFavorite(_photo);
    if (mounted) setState(() {});
    if (!wasFavorite) _playFavoriteBurst();
  }

  Future<void> _loadIgnoreFeature() async {
    try {
      final features = await _repository.getMobileFeatures();
      if (!mounted) return;
      setState(() => _allowIgnore = features['allow_ignore'] == true);
    } catch (_) {
      // Ignore button simply stays hidden if the feature flag can't load.
    }
  }

  Future<void> _ignoreCurrentPhoto() async {
    if (!_allowIgnore || _isIgnoring || _photo.id <= 0) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Ignore this photo?'),
        content: const Text('This photo will be hidden from your gallery.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ignore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isIgnoring = true);
    try {
      final photoId = _photo.id;
      final ignored = await _repository.ignorePhotos({photoId});
      if (!mounted) return;
      if (ignored.isEmpty) {
        TopNotification.error('Unable to ignore this photo');
        return;
      }
      TopNotification.success('Photo ignored');
      final list = _photosList;
      final removedIndex = list.indexWhere((photo) => photo.id == photoId);
      if (removedIndex != -1) {
        list.removeAt(removedIndex);
      }
      if (list.isEmpty) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        if (_index >= list.length) {
          _index = list.length - 1;
        }
        _resetZoom(animated: false);
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_index);
      }
    } catch (error) {
      if (!mounted) return;
      TopNotification.error(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isIgnoring = false);
    }
  }

  void _rememberDoubleTapPosition(TapDownDetails details) {
    _lastDoubleTapPosition = details.localPosition;
  }

  void _handleZoomInteractionStart(ScaleStartDetails details) {
    _zoomAnimationController.stop();
    _clearZoomAnimation();
    _gesturePointerCount = details.pointerCount;

    if (details.pointerCount < 2 && !_isZoomed) return;
    if (_zoomModeActive && !_chromeVisible) return;

    setState(() {
      _zoomModeActive = true;
      _chromeVisible = false;
    });
  }

  void _handleZoomInteractionUpdate(ScaleUpdateDetails details) {
    _gesturePointerCount = details.pointerCount;
    final isZoomed = _transformationController.value.getMaxScaleOnAxis() > 1.05;
    if (!isZoomed || (_isZoomed && _zoomModeActive && !_chromeVisible)) {
      return;
    }

    setState(() {
      _isZoomed = true;
      _zoomModeActive = true;
      _chromeVisible = false;
    });
  }

  void _handleZoomInteractionEnd(ScaleEndDetails details) {
    final isZoomed = _transformationController.value.getMaxScaleOnAxis() > 1.05;
    if (!isZoomed) {
      if (_gesturePointerCount <= 1 &&
          details.velocity.pixelsPerSecond.dy > 360) {
        Navigator.pop(context);
        return;
      }
      _resetZoom();
      return;
    }

    if (_isZoomed && _zoomModeActive && !_chromeVisible) return;
    setState(() {
      _isZoomed = true;
      _zoomModeActive = true;
      _chromeVisible = false;
    });
  }

  void _clearZoomAnimation() {
    final animation = _zoomAnimation;
    final listener = _zoomAnimationListener;
    final statusListener = _zoomAnimationStatusListener;
    if (animation != null && listener != null) {
      animation.removeListener(listener);
    }
    if (animation != null && statusListener != null) {
      animation.removeStatusListener(statusListener);
    }
    _zoomAnimation = null;
    _zoomAnimationListener = null;
    _zoomAnimationStatusListener = null;
  }

  void _animateZoomTo(Matrix4 target, {required bool isZoomed}) {
    _zoomAnimationController.stop();
    _clearZoomAnimation();
    final animation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: target,
        ).animate(
          CurvedAnimation(
            parent: _zoomAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    void listener() {
      _transformationController.value = animation.value;
    }

    void statusListener(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      _clearZoomAnimation();
      if (mounted) {
        setState(() {
          _isZoomed = isZoomed;
          _zoomModeActive = isZoomed;
          _chromeVisible = !isZoomed;
        });
      }
    }

    _zoomAnimation = animation;
    _zoomAnimationListener = listener;
    _zoomAnimationStatusListener = statusListener;
    animation.addListener(listener);
    animation.addStatusListener(statusListener);
    setState(() {
      _isZoomed = isZoomed;
      _zoomModeActive = isZoomed;
      _chromeVisible = !isZoomed;
    });
    _zoomAnimationController.forward(from: 0);
  }

  void _resetZoom({bool animated = true, bool restoreChrome = true}) {
    if (animated) {
      _animateZoomTo(Matrix4.identity(), isZoomed: false);
    } else {
      _zoomAnimationController.stop();
      _transformationController.value = Matrix4.identity();
      _isZoomed = false;
      _zoomModeActive = false;
      if (restoreChrome) _chromeVisible = true;
    }
  }

  Matrix4 _zoomMatrixFor(Offset position, double zoom) {
    final viewport = MediaQuery.sizeOf(context);
    return Matrix4.identity()
      ..setEntry(0, 0, zoom)
      ..setEntry(1, 1, zoom)
      ..setEntry(0, 3, (viewport.width / 2) - (position.dx * zoom))
      ..setEntry(1, 3, (viewport.height / 2) - (position.dy * zoom));
  }

  void _toggleChrome() {
    if (_zoomModeActive) return;
    setState(() {
      _chromeVisible = !_chromeVisible;
    });
  }

  void _toggleZoom() {
    if (_zoomModeActive) {
      _resetZoom();
      return;
    }

    HapticFeedback.selectionClick();
    const zoom = 2.15;
    final target = _zoomMatrixFor(_lastDoubleTapPosition, zoom);
    _animateZoomTo(target, isZoomed: true);
  }

  Future<void> _openAddCollectionSheet() async {
    if (!AuthRedirectHelper.ensureLoggedIn()) return;
    final name = await _askForText(
      title: 'Add To Collection',
      hint: 'Collection name',
      action: 'Save',
      suggestions: _controller.allUserCollectionNames,
      selectedValues: _controller.collectionNamesForPhoto(_photo.id),
    );
    if (name == null) return;
    final saved = await _controller.addPhotoToCollection(_photo, name);
    if (!mounted) return;
    TopNotification.show(
      message: saved ? 'Added to "$name"' : '"$name" is already added',
      type: saved ? AppNotificationType.success : AppNotificationType.info,
    );
  }

  Future<void> _openAddTagSheet() async {
    if (!AuthRedirectHelper.ensureLoggedIn()) return;
    final tag = await _askForText(
      title: 'Add Tag',
      hint: 'Tag name',
      action: 'Add',
      suggestions: _controller.allUserTags,
      selectedValues: _controller.tagsForPhoto(_photo.id),
    );
    if (tag == null) return;
    final saved = await _controller.addTagToPhoto(_photo, tag);
    if (!mounted) return;
    TopNotification.show(
      message: saved ? 'Tag "$tag" added' : 'Tag "$tag" is already added',
      type: saved ? AppNotificationType.success : AppNotificationType.info,
    );
  }

  void _showMoreOptions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Photo options'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _openAddTagSheet();
            },
            child: const Text('Add Tag'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              if (!AuthRedirectHelper.ensureLoggedIn()) return;
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => DiaryEntryDetailScreen(
                    date: DateTime.now(),
                    initialImages: [_photo.fullUrl],
                  ),
                ),
              );
            },
            child: const Text('Add Note in Diary'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<String?> _askForText({
    required String title,
    required String hint,
    required String action,
    List<String> suggestions = const [],
    List<String> selectedValues = const [],
  }) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ResponsiveCenter(
        maxWidth: kSheetMaxWidth,
        child: _TextEntryBottomSheet(
          title: title,
          hint: hint,
          action: action,
          suggestions: suggestions,
          selectedValues: selectedValues,
        ),
      ),
    );
    return value?.trim().isEmpty == true ? null : value?.trim();
  }

  void _toggleInfoPanel() {
    setState(() {
      _infoPanelOpen = !_infoPanelOpen;
      if (_infoPanelOpen) _chromeVisible = true;
    });
  }

  String _formatRecentViewerTitle(GalleryPhoto photo) {
    return photo.title?.trim().isNotEmpty == true
        ? photo.title!.trim()
        : 'Recent Smruti';
  }

  // Obx requires an observable read inside its builder; static (non-recent)
  // galleries have no Rx source, so only wrap reactively for the recent feed.
  Widget _reactive(Widget Function() builder) {
    return widget.isRecentFeed ? Obx(builder) : builder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _zoomModeActive ? Colors.black : Colors.white,
      body: Stack(
        children: [
          _reactive(
            () => PageView.builder(
              controller: _pageController,
              itemCount: _photosList.length,
              allowImplicitScrolling: true,
              physics: _zoomModeActive
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (value) {
                setState(() {
                  _index = value;
                  _resetZoom(animated: false, restoreChrome: false);
                });
                _precacheAround(value);
                _centerThumbnail(value);
                _maybeLoadMoreRecent(value);
              },
              itemBuilder: (context, index) {
                final photo = _photosList[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleChrome,
                  onDoubleTapDown: _rememberDoubleTapPosition,
                  onDoubleTap: _toggleZoom,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 1,
                    maxScale: 5,
                    scaleEnabled: true,
                    panEnabled: _zoomModeActive,
                    boundaryMargin: const EdgeInsets.all(96),
                    clipBehavior: Clip.none,
                    onInteractionStart: _handleZoomInteractionStart,
                    onInteractionUpdate: _handleZoomInteractionUpdate,
                    onInteractionEnd: _handleZoomInteractionEnd,
                    child: Center(
                      child: Hero(
                        tag: 'photo-${photo.id}',
                        child: RepaintBoundary(
                          child: _FullscreenImage(
                            photo: photo,
                            title: widget.title,
                            headers: _controller.imageHeaders,
                            chromeVisible: _chromeVisible,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: _chromeVisible ? Offset.zero : const Offset(0, -1.25),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _chromeVisible ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_chromeVisible,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    child: _reactive(
                      () => _ViewerTopBar(
                        title: widget.showRecentPhotoMetadata
                            ? _formatRecentViewerTitle(_photo)
                            : widget.title,
                        position: '${_index + 1} of ${_photosList.length}',
                        takenAt: _photo.eventDate,
                        attributesFuture: _attributesFor(_photo.id),
                        onBack: () => Navigator.pop(context),
                        allowIgnore: _allowIgnore,
                        isIgnoring: _isIgnoring,
                        onIgnore: _ignoreCurrentPhoto,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showFavoriteBurst ? 1 : 0,
                duration: const Duration(milliseconds: 140),
                child: AnimatedScale(
                  scale: _showFavoriteBurst ? 1 : 0.45,
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    CupertinoIcons.heart_fill,
                    color: Colors.redAccent.withAlpha(225),
                    size: 118,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: _chromeVisible ? Offset.zero : const Offset(0, 1.3),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _chromeVisible ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_chromeVisible,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.bottomCenter,
                        child: _infoPanelOpen
                            ? const SizedBox.shrink()
                            : AnimatedOpacity(
                                duration: const Duration(milliseconds: 160),
                                opacity: _infoPanelOpen ? 0 : 1,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 13),
                                  child: _reactive(
                                    () => _ViewerThumbStrip(
                                      photos: _photosList,
                                      selectedIndex: _index,
                                      isLoadingMore:
                                          widget.isRecentFeed &&
                                          _controller.isRecentPageLoading.value,
                                      controller: _thumbnailScrollController,
                                      headers: _controller.imageHeaders,
                                      onTap: (index) {
                                        _pageController.animateToPage(
                                          index,
                                          duration: const Duration(
                                            milliseconds: 260,
                                          ),
                                          curve: Curves.easeOutCubic,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.bottomCenter,
                        child: _infoPanelOpen
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 13),
                                child: _InlineInfoPanel(
                                  photo: _photo,
                                  attributesFuture: _attributesFor(_photo.id),
                                  imageSizeFuture: _imageSizeFor(_photo),
                                  storageSizeFuture: _storageSizeFor(_photo),
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      _ViewerActions(
                        isFavorite: _controller.isFavorite(_photo.id),
                        onShare: _sharePhoto,
                        onFavorite: _toggleFavorite,
                        onInfo: _toggleInfoPanel,
                        isInfoOpen: _infoPanelOpen,
                        onOptions: _showMoreOptions,
                        onCollection: _openAddCollectionSheet,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextEntryBottomSheet extends StatefulWidget {
  final String title;
  final String hint;
  final String action;
  final List<String> suggestions;
  final List<String> selectedValues;

  const _TextEntryBottomSheet({
    required this.title,
    required this.hint,
    required this.action,
    this.suggestions = const [],
    this.selectedValues = const [],
  });

  @override
  State<_TextEntryBottomSheet> createState() => _TextEntryBottomSheetState();
}

class _TextEntryBottomSheetState extends State<_TextEntryBottomSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  void _submit() {
    final text = _controller.text.trim();
    final alreadySelected = widget.selectedValues.any(
      (value) => value.toLowerCase() == text.toLowerCase(),
    );
    if (text.isNotEmpty && !alreadySelected) {
      Navigator.pop(context, text);
      return;
    }
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final reusable = widget.suggestions
        .where((value) => query.isEmpty || value.toLowerCase().contains(query))
        .toList();
    reusable.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final isCollection = widget.title.toLowerCase().contains('collection');
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6F3).withAlpha(246),
              border: Border(
                top: BorderSide(color: primaryColor.withAlpha(18)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          primaryColor.withAlpha(34),
                          primaryColor.withAlpha(12),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF322318),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 54),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                CupertinoIcons.search,
                                color: primaryColor,
                              ),
                              hintText:
                                  'Search ${isCollection ? 'collection' : 'tag'}',
                              filled: true,
                              fillColor: Colors.white.withAlpha(235),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _submit(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _submit,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withAlpha(42),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.add,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        reusable.isEmpty
                            ? 'No existing items'
                            : widget.title.toLowerCase().contains('collection')
                            ? 'Select Collection'
                            : 'Select Tag',
                        style: TextStyle(
                          color: Colors.black.withAlpha(150),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                      itemCount: reusable.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final value = reusable[index];
                        final selected = widget.selectedValues.any(
                          (selected) =>
                              selected.toLowerCase() == value.toLowerCase(),
                        );
                        return _ReusableValueTile(
                          label: value,
                          subtitle: selected
                              ? 'Already added'
                              : isCollection
                              ? 'Collection'
                              : '',
                          icon: isCollection
                              ? CupertinoIcons.collections
                              : CupertinoIcons.tag,
                          selected: selected,
                          onTap: selected
                              ? null
                              : () => Navigator.pop(context, value),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReusableValueTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _ReusableValueTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(235),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primaryColor.withAlpha(16)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primaryColor.withAlpha(22),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: primaryColor, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF322318),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.black.withAlpha(125),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              selected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: primaryColor,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenImage extends StatelessWidget {
  final GalleryPhoto photo;
  final String title;
  final Map<String, String>? headers;
  final bool chromeVisible;

  const _FullscreenImage({
    required this.photo,
    required this.title,
    required this.headers,
    required this.chromeVisible,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final verticalPadding = chromeVisible ? 96 + 132 : 0;
    // Cap decode resolution so pinch-zoom recompositing a giant source photo
    // doesn't have to raster/scale a huge texture every frame. Sized with
    // headroom above the max pinch scale (5x) so zoomed-in detail still
    // looks sharp; only width is capped so aspect ratio is preserved.
    final cacheWidth =
        (screenSize.width * MediaQuery.devicePixelRatioOf(context) * 3)
            .clamp(600, 3000)
            .round();
    return AnimatedPadding(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        0,
        chromeVisible ? 96 : 0,
        0,
        chromeVisible ? 132 : 0,
      ),
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height - verticalPadding,
        child: CachedNetworkImage(
          imageUrl: photo.fullUrl,
          httpHeaders: headers,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          memCacheWidth: cacheWidth,
          placeholder: (context, url) => CachedNetworkImage(
            imageUrl: photo.thumbnailUrl,
            httpHeaders: headers,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            errorWidget: (_, __, ___) =>
                Icon(CupertinoIcons.photo, color: primaryColor, size: 42),
          ),
          errorWidget: (_, __, ___) =>
              Icon(CupertinoIcons.photo, color: primaryColor, size: 42),
        ),
      ),
    );
  }
}

class _ViewerTopBar extends StatelessWidget {
  final String title;
  final String position;
  final DateTime? takenAt;
  final Future<GalleryPhotoAttributes>? attributesFuture;
  final VoidCallback onBack;
  final bool allowIgnore;
  final bool isIgnoring;
  final VoidCallback onIgnore;

  const _ViewerTopBar({
    required this.title,
    required this.position,
    this.takenAt,
    this.attributesFuture,
    required this.onBack,
    required this.allowIgnore,
    required this.isIgnoring,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ViewerCircleButton(icon: CupertinoIcons.chevron_left, onTap: onBack),
        const SizedBox(width: 10),
        Expanded(
          child: FutureBuilder<GalleryPhotoAttributes>(
            future: attributesFuture,
            builder: (context, snapshot) {
              final attrs = snapshot.data;
              final placeParts = [
                attrs?.location,
                attrs?.subLocation,
              ].where((value) => value?.trim().isNotEmpty == true).toList();
              final place = placeParts.isNotEmpty
                  ? placeParts.join(' - ')
                  : attrs?.country?.trim() ?? '';
              final displayTitle = place.isNotEmpty ? place : 'Location';
              final displaySubtitle = _formatTopDateTime(takenAt) ?? '';

              return ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(178),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withAlpha(210)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          displaySubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.black.withAlpha(166),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (allowIgnore)
          isIgnoring
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                )
              : _GlassIconButton(
                  icon: CupertinoIcons.eye_slash_fill,
                  onTap: onIgnore,
                )
        else
          const SizedBox(width: 54),
      ],
    );
  }

  String? _formatTopDateTime(DateTime? value) {
    if (value == null) return null;
    return _formatShortDate(value.toLocal());
  }

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _ViewerThumbStrip extends StatelessWidget {
  final List<GalleryPhoto> photos;
  final int selectedIndex;
  final ScrollController controller;
  final Map<String, String>? headers;
  final ValueChanged<int> onTap;
  final bool isLoadingMore;

  const _ViewerThumbStrip({
    required this.photos,
    required this.selectedIndex,
    required this.controller,
    required this.headers,
    required this.onTap,
    this.isLoadingMore = false,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = photos.length + (isLoadingMore ? 1 : 0);
    final scale = tabletScale(context);
    return SizedBox(
      height: 34 * scale,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          if (index >= photos.length) {
            return SizedBox(
              width: 24 * scale,
              height: 24 * scale,
              child: Center(
                child: SizedBox(
                  width: 16 * scale,
                  height: 16 * scale,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: (isSelected ? 34 : 24) * scale,
              height: (isSelected ? 34 : 29) * scale,
              margin: EdgeInsets.symmetric(horizontal: isSelected ? 5 : 0),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: CachedNetworkImage(
                imageUrl: photos[index].thumbnailUrl,
                httpHeaders: headers,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ViewerActions extends StatelessWidget {
  final bool isFavorite;
  final bool isInfoOpen;
  final VoidCallback onShare;
  final VoidCallback onFavorite;
  final VoidCallback onInfo;
  final VoidCallback onOptions;
  final VoidCallback onCollection;

  const _ViewerActions({
    required this.isFavorite,
    required this.isInfoOpen,
    required this.onShare,
    required this.onFavorite,
    required this.onInfo,
    required this.onOptions,
    required this.onCollection,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        children: [
          _ViewerCircleButton(
            icon: CupertinoIcons.square_arrow_up,
            onTap: onShare,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _ViewerPlainButton(
                  icon: isFavorite
                      ? CupertinoIcons.heart_fill
                      : CupertinoIcons.heart,
                  color: isFavorite ? Colors.redAccent : Colors.black,
                  onTap: onFavorite,
                ),
                _InfoToggleButton(isOpen: isInfoOpen, onTap: onInfo),
                _ViewerPlainButton(
                  icon: CupertinoIcons.slider_horizontal_3,
                  onTap: onOptions,
                ),
              ],
            ),
          ),
          const Spacer(),
          _ViewerCircleButton(
            icon: CupertinoIcons.collections,
            onTap: onCollection,
          ),
        ],
      ),
    );
  }
}

class _ViewerCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ViewerCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(235),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black, size: 22),
      ),
    );
  }
}

class _ViewerPlainButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ViewerPlainButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 40,
        child: Icon(icon, color: color, size: 23),
      ),
    );
  }
}

class _InfoToggleButton extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onTap;

  const _InfoToggleButton({required this.isOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 40,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOpen ? primaryColor : Colors.transparent,
            ),
            alignment: Alignment.center,
            child: Icon(
              isOpen
                  ? CupertinoIcons.info_circle_fill
                  : CupertinoIcons.info_circle,
              color: isOpen ? Colors.white : primaryColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

String? _formatPhotoDimensions(int? width, int? height) {
  return width != null && height != null && width > 0 && height > 0
      ? '$width x $height'
      : null;
}

String? _formatStorageSize({
  required int? fileSizeBytes,
  required String? fileSizeLabel,
}) {
  return fileSizeLabel?.trim().isNotEmpty == true
      ? fileSizeLabel!.trim()
      : _formatBytes(fileSizeBytes);
}

String? _formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return null;
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final decimals = value >= 10 || unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
}

class _InlineInfoPanel extends StatelessWidget {
  final GalleryPhoto photo;
  final Future<GalleryPhotoAttributes> attributesFuture;
  final Future<String> imageSizeFuture;
  final Future<String> storageSizeFuture;
  final GalleryController _controller = Get.find<GalleryController>();

  _InlineInfoPanel({
    required this.photo,
    required this.attributesFuture,
    required this.imageSizeFuture,
    required this.storageSizeFuture,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.42,
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: FutureBuilder<GalleryPhotoAttributes>(
        future: attributesFuture,
        builder: (context, snapshot) {
          final attrs = snapshot.data;
          final entries = attrs?.entries ?? const [];
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Photo Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  _formatDateTime(photo.eventDate) ?? 'Not available',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                FutureBuilder<List<String>>(
                  future: Future.wait([imageSizeFuture, storageSizeFuture]),
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    final parts = [
                      if (data != null && data[0] != 'Not available') data[0],
                      if (data != null && data[1] != 'Not available') data[1],
                    ];
                    return Text(
                      parts.isEmpty ? 'Loading...' : parts.join(' • '),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withAlpha(135),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                if (kDebugMode) ...[
                  _TagInfoCard(
                    label: 'Image Name',
                    value: _debugImageFileName(photo),
                    color: const Color(0xFF5965D8),
                  ),
                  const SizedBox(height: 14),
                ],
                const Text(
                  'Image Tags',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Obx(() {
                  final userTags = _mergedPhotoTags(
                    photo.tags,
                    _controller.tagsForPhoto(photo.id),
                  );
                  if (userTags.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in userTags)
                          Chip(
                            label: Text(tag),
                            deleteIcon:
                                _controller.tagsForPhoto(photo.id).contains(tag)
                                ? const Icon(
                                    CupertinoIcons.xmark_circle_fill,
                                    size: 18,
                                  )
                                : null,
                            onDeleted:
                                _controller.tagsForPhoto(photo.id).contains(tag)
                                ? () {
                                    _controller.removeTagFromPhoto(
                                      photo.id,
                                      tag,
                                    );
                                  }
                                : null,
                            backgroundColor: primaryColor.withAlpha(24),
                            labelStyle: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w800,
                            ),
                            side: BorderSide(color: primaryColor.withAlpha(45)),
                          ),
                      ],
                    ),
                  );
                }),
                if (snapshot.connectionState != ConnectionState.done)
                  const GalleryShimmerBox(height: 86, borderRadius: 18)
                else if (entries.isEmpty)
                  Text(
                    'No tags added',
                    style: TextStyle(
                      color: Colors.black.withAlpha(135),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Column(
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == entries.length - 1 ? 0 : 10,
                          ),
                          child: _TagInfoCard(
                            label: entries[i].key,
                            value: entries[i].value,
                            color: _tagColors[i % _tagColors.length],
                          ),
                        ),
                    ],
                  ),
                if ((attrs?.placeLabel ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Location',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  _InfoMapCard(attrs: attrs!, photo: photo),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _debugImageFileName(GalleryPhoto photo) {
    final apiName = photo.fileName?.trim();
    if (apiName != null && apiName.isNotEmpty) return apiName;
    final uri = Uri.tryParse(photo.fullUrl);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final lastSegment = uri.pathSegments.last.trim();
      if (lastSegment.isNotEmpty && lastSegment.contains('.')) {
        return Uri.decodeComponent(lastSegment);
      }
    }
    return 'Not available';
  }

  String? _formatDateTime(DateTime? date) {
    if (date == null) return null;
    final localDate = date.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${localDate.day} ${months[localDate.month - 1]} ${localDate.year}';
  }

  List<String> _mergedPhotoTags(List<String> baseTags, List<String> userTags) {
    final tags = <String, String>{};
    for (final tag in [...baseTags, ...userTags]) {
      final clean = tag.trim();
      if (clean.isEmpty) continue;
      tags.putIfAbsent(clean.toLowerCase(), () => clean);
    }
    return tags.values.toList();
  }
}

class _TagInfoCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TagInfoCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white, color, 0.16),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(28),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color.withAlpha(220),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 7,
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoMapCard extends StatelessWidget {
  final GalleryPhotoAttributes attrs;
  final GalleryPhoto photo;

  const _InfoMapCard({required this.attrs, required this.photo});

  @override
  Widget build(BuildContext context) {
    final point = _photoPoint(photo, attrs);
    final scale = tabletScale(context);

    return GestureDetector(
      onTap: () => _openLocationMap(context),
      child: Container(
        height: 166 * scale,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFFEAF2EC),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (point == null)
              CustomPaint(painter: _SoftMapPainter())
            else
              FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    fallbackUrl:
                        'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.harismruti.app',
                    maxZoom: 18,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 86 * scale,
                        height: 86 * scale,
                        child: Center(
                          child: Icon(
                            CupertinoIcons.location_solid,
                            color: primaryColor,
                            size: 46 * scale,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            Container(color: Colors.white.withAlpha(34)),
            Center(
              child: Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withAlpha(55),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: photo.thumbnailUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(205),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withAlpha(220)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.map_pin_ellipse,
                          color: primaryColor,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            attrs.placeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          CupertinoIcons.chevron_right,
                          color: primaryColor,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LatLng? _photoPoint(GalleryPhoto photo, GalleryPhotoAttributes attrs) {
    final lat = photo.latitude ?? attrs.latitude;
    final lng = photo.longitude ?? attrs.longitude;
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  GalleryPhoto _photoWithAttributeLocation() {
    return GalleryPhoto(
      id: photo.id,
      thumbnailUrl: photo.thumbnailUrl,
      fullUrl: photo.fullUrl,
      title: photo.title,
      subtitle: photo.subtitle,
      takenAt: photo.takenAt,
      eventDate: photo.eventDate,
      width: photo.width,
      height: photo.height,
      fileSizeBytes: photo.fileSizeBytes,
      fileSizeLabel: photo.fileSizeLabel,
      fileName: photo.fileName,
      latitude: photo.latitude ?? attrs.latitude,
      longitude: photo.longitude ?? attrs.longitude,
    );
  }

  GalleryCard _locationCard() {
    final displayTitle = attrs.location?.trim().isNotEmpty == true
        ? attrs.location!.trim()
        : attrs.placeLabel;
    return GalleryCard(
      id: photo.id,
      title: displayTitle,
      subtitle: '1 Photo',
      type: 'location',
      value: displayTitle,
      count: 1,
      photos: [_photoWithAttributeLocation()],
    );
  }

  void _openLocationMap(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      CupertinoPageRoute(
        builder: (_) => GalleryLocationScreen(card: _locationCard()),
      ),
    );
  }
}

class _SoftMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withAlpha(160)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final road = Paint()
      ..color = primaryColor.withAlpha(42)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 4; i++) {
      final y = i * size.height / 4 + 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 20), line);
    }
    for (var i = 0; i < 4; i++) {
      final x = i * size.width / 4 + 18;
      canvas.drawLine(Offset(x, 0), Offset(x - 18, size.height), line);
    }
    final path = Path()
      ..moveTo(-10, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.42,
        size.width * 0.62,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.7,
        size.width + 16,
        size.height * 0.34,
      );
    canvas.drawPath(path, road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _tagColors = [
  Color(0xFF7B3F98),
  Color(0xFF1F7A8C),
  Color(0xFF9A5A17),
  Color(0xFF2F7D52),
  Color(0xFFB23A48),
  Color(0xFF4062BB),
];

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: Colors.white.withAlpha(180),
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(icon, color: primaryColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailShimmerMosaic extends StatelessWidget {
  const _DetailShimmerMosaic();

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: 4,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GalleryShimmerBox(
          height: index.isEven ? 260 : 210,
          borderRadius: 18,
        ),
      ),
    );
  }
}
