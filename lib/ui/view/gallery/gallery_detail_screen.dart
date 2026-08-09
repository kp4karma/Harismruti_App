import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/api/repositories/gallery_repository.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/services/deep_link_service.dart';
import 'package:harismruti/services/download_library_service.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/controller/my_photos_controller.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/ui/view/gallery/gallery_location_screen.dart';
import 'package:harismruti/ui/view/gallery/gallery_filter_sheet.dart';
import 'package:harismruti/ui/view/home/my_diary_smruti.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/widget/appbar/frosted_appbar.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:share_plus/share_plus.dart';

const double _homeAppbarBlurSigma = 28;
const MethodChannel _wallpaperChannel = MethodChannel(
  'org.hp.harismruti/wallpaper',
);

double _galleryPhotoAspectRatio(GalleryPhoto photo) {
  final width = photo.width;
  final height = photo.height;
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 1.15;
  }
  // Keep the source ratio so masonry tiles never crop portrait or panorama
  // photos just to fit an artificial height range.
  return width / height;
}

int _memorySafeDecodeWidth(
  BuildContext context,
  GalleryPhoto photo, {
  required double widthMultiplier,
  required int maxPixels,
}) {
  final requestedWidth =
      MediaQuery.sizeOf(context).width *
      MediaQuery.devicePixelRatioOf(context) *
      widthMultiplier;
  final sourceAspect = _galleryPhotoAspectRatio(photo);
  // Decoded images use about four bytes per pixel. Bound total pixels as well
  // as width so very tall panoramas cannot bypass the memory guard.
  final pixelBudgetWidth = math.sqrt(maxPixels * sourceAspect);
  return requestedWidth.clamp(1, pixelBudgetWidth).round();
}

Widget _transparentPhotoHeroFlight(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext, {
  required GalleryPhoto photo,
  required Map<String, String>? headers,
}) {
  // A hero flight is short-lived and never needs the original camera
  // resolution. Without this cap it can decode a second full-size bitmap on
  // top of the viewer image, which is enough to exhaust RAM on many phones.
  final decodeWidth = _memorySafeDecodeWidth(
    flightContext,
    photo,
    widthMultiplier: 2,
    maxPixels: 3000000,
  );
  final image = Material(
    type: MaterialType.transparency,
    child: CachedNetworkImage(
      imageUrl: photo.fullUrl,
      httpHeaders: headers,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: decodeWidth,
      placeholder: (_, __) => CachedNetworkImage(
        imageUrl: photo.thumbnailUrl,
        httpHeaders: headers,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        memCacheWidth: decodeWidth,
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      ),
      errorWidget: (_, __, ___) => const SizedBox.shrink(),
    ),
  );
  final radiusTween = direction == HeroFlightDirection.push
      ? Tween<double>(begin: 14, end: 0)
      : Tween<double>(begin: 0, end: 14);

  return AnimatedBuilder(
    animation: animation,
    child: image,
    builder: (_, child) => ClipRRect(
      borderRadius: BorderRadius.circular(radiusTween.evaluate(animation)),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );
}

Widget _themedPhotoActionSheet(BuildContext context, Widget child) {
  final materialTheme = Theme.of(context);
  final scheme = materialTheme.colorScheme;
  final isDark = materialTheme.brightness == Brightness.dark;
  final foregroundColor = isDark ? Colors.white : primaryColor;
  return CupertinoTheme(
    data: CupertinoThemeData(
      brightness: materialTheme.brightness,
      primaryColor: foregroundColor,
      scaffoldBackgroundColor: scheme.surface,
      barBackgroundColor: scheme.surfaceContainerHigh,
      textTheme: CupertinoTextThemeData(
        primaryColor: foregroundColor,
        textStyle: TextStyle(color: isDark ? Colors.white : scheme.onSurface),
        actionTextStyle: TextStyle(
          color: foregroundColor,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    child: child,
  );
}

class GalleryDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? coverUrl;
  final Future<List<GalleryPhoto>> Function() loader;
  final Future<List<GalleryPhoto>> Function(int page)? loadMore;
  final bool showRecentPhotoMetadata;
  final List<String> filterLabels;
  final Map<String, List<String>>? selectedFilters;

  const GalleryDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loader,
    this.loadMore,
    this.coverUrl,
    this.showRecentPhotoMetadata = false,
    this.filterLabels = const [],
    this.selectedFilters,
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
      selectedFilters: selected,
      loader: () => controller.loadPhotosForFilters(selected: selected),
      loadMore: (page) =>
          controller.loadPhotosForFilters(selected: selected, page: page),
    );
  }

  @override
  State<GalleryDetailScreen> createState() => _GalleryDetailScreenState();
}

class _GalleryDetailScreenState extends State<GalleryDetailScreen> {
  final GalleryController _galleryController = Get.find<GalleryController>();
  final ScrollController _scrollController = ScrollController();
  final List<GalleryPhoto> _photos = [];
  final GalleryRepository _repository = const GalleryRepository();
  final Set<int> _ignoredPhotoIds = {};
  final Set<int> _selectedPhotoIds = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _initialLoading = true;
  bool _mobileFeatureAllowsIgnore = false;
  bool _selectionMode = false;
  bool _isIgnoring = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _failed = false;
  bool _showBottomBar = true;
  double _lastScrollOffset = 0;
  double _downwardTravel = 0;
  double _upwardTravel = 0;
  int _page = 1;
  late String _title;
  late List<String> _filterLabels;
  Map<String, List<String>>? _selectedFilters;

  bool get _isMySmrutiFilter =>
      _selectedFilters?.keys.any(
        (slug) => slug == 'my_smruti_scope' || slug.startsWith('my_smruti_'),
      ) ??
      false;

  bool get _allowIgnore => _isMySmrutiFilter || _mobileFeatureAllowsIgnore;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _filterLabels = List<String>.of(widget.filterLabels);
    _selectedFilters = widget.selectedFilters == null
        ? null
        : {
            for (final entry in widget.selectedFilters!.entries)
              entry.key: List<String>.of(entry.value),
          };
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  void _onSearchFocusChanged() {
    if (!mounted) return;
    if (_searchFocusNode.hasFocus) {
      _showBottomBar = true;
      _downwardTravel = 0;
      _upwardTravel = 0;
    }
    setState(() {});
  }

  Future<void> _loadInitial() async {
    try {
      // Ignoring is an optional enhancement. A missing/older features endpoint
      // must never prevent the gallery itself from opening.
      try {
        final features = await _repository.getMobileFeatures(
          forMySmruti: _isMySmrutiFilter,
        );
        _mobileFeatureAllowsIgnore = features['allow_ignore'] == true;
        _ignoredPhotoIds.addAll(
          (features['ignored_photo_ids'] is List
                  ? features['ignored_photo_ids'] as List
                  : const [])
              .map((value) => int.tryParse('$value'))
              .whereType<int>(),
        );
      } catch (error) {
        debugPrint(
          'GalleryDetailScreen[${widget.title}]: optional features failed, $error',
        );
      }
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
        _hasMore = widget.loadMore != null && photos.isNotEmpty;
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

  Future<void> _openFilters() async {
    final result = await showGalleryFilterSheet(
      context,
      initialSelected: _selectedFilters ?? const {},
      initialFilterLabels: _filterLabels,
      openResultScreen: _selectedFilters == null,
    );
    if (!mounted || result == null || _selectedFilters == null) return;
    if (result.cleared) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _selectedFilters = result.selected;
      _filterLabels = result.filterLabels;
      _title = 'Filtered Smruti (${result.selectedCount})';
      _initialLoading = true;
      _failed = false;
      _photos.clear();
      _page = 1;
      _hasMore = false;
    });
    try {
      final photos = await _galleryController.loadPhotosForFilters(
        selected: result.selected,
      );
      if (!mounted) return;
      setState(() {
        _photos.addAll(_dedupe(photos, existing: const []));
        _initialLoading = false;
        _hasMore = photos.isNotEmpty;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _failed = true;
        });
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final currentOffset = position.pixels.clamp(0.0, position.maxScrollExtent);
    final delta = currentOffset - _lastScrollOffset;
    _lastScrollOffset = currentOffset;

    if (!_searchFocusNode.hasFocus) {
      if (currentOffset <= 32) {
        _downwardTravel = 0;
        _upwardTravel = 0;
        if (!_showBottomBar) setState(() => _showBottomBar = true);
      } else if (delta > 0) {
        _downwardTravel += delta;
        _upwardTravel = 0;
        if (_showBottomBar && _downwardTravel >= 28) {
          _downwardTravel = 0;
          setState(() => _showBottomBar = false);
        }
      } else if (delta < 0) {
        _upwardTravel -= delta;
        _downwardTravel = 0;
        if (!_showBottomBar && _upwardTravel >= 20) {
          _upwardTravel = 0;
          setState(() => _showBottomBar = true);
        }
      }
    }
    if (_scrollController.position.extentAfter > 600) return;
    _loadMore();
  }

  List<GalleryPhoto> get _visiblePhotos {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _photos;
    return _photos
        .where((photo) {
          final searchable = [
            photo.title,
            photo.subtitle,
            photo.fileName,
            photo.country,
            photo.location,
            photo.subLocation,
            photo.album,
            photo.smrutiWith,
            photo.darshanOf,
            photo.smrutiOf,
            ...photo.tags,
          ].whereType<String>().join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || widget.loadMore == null) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    try {
      final photos = _selectedFilters == null
          ? await widget.loadMore!(nextPage)
          : await _galleryController.loadPhotosForFilters(
              selected: _selectedFilters!,
              page: nextPage,
            );
      debugPrint(
        'GalleryDetailScreen[${widget.title}]: page=$nextPage returned=${photos.length}',
      );
      if (!mounted) return;
      final newPhotos = _dedupe(
        photos,
        existing: _photos,
      ).where((photo) => !_ignoredPhotoIds.contains(photo.id)).toList();
      setState(() {
        _photos.addAll(newPhotos);
        _page = nextPage;
        _hasMore = photos.isNotEmpty && newPhotos.isNotEmpty;
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
          _isMySmrutiFilter
              ? '${_selectedPhotoIds.length} selected photos will be hidden only from your My Smruti section.'
              : '${_selectedPhotoIds.length} selected photos will be hidden from your gallery.',
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
      final ignored = await _repository.ignorePhotos(
        _selectedPhotoIds,
        forMySmruti: _isMySmrutiFilter,
      );
      if (!mounted) return;
      if (_isMySmrutiFilter) {
        _galleryController.mySmrutiPhotos.removeWhere(
          (photo) => ignored.contains(photo.id),
        );
      }
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
    final visiblePhotos = _visiblePhotos;
    final cover = widget.coverUrl?.isNotEmpty == true
        ? widget.coverUrl!
        : _photos.isNotEmpty
        ? _photos.first.thumbnailUrl
        : '';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              _MusicStyleHeader(
                title: _title,
                subtitle: widget.subtitle,
                filterLabels: _filterLabels,
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
              else if (visiblePhotos.isEmpty)
                SliverToBoxAdapter(
                  child: GalleryEmptyState(
                    height: 260,
                    message: _failed
                        ? 'Unable to load photos'
                        : _searchController.text.trim().isNotEmpty
                        ? 'No matching photos found'
                        : 'No photos found',
                  ),
                )
              else ...[
                _MosaicPhotoSliver(
                  photos: visiblePhotos,
                  title: _title,
                  headers: _galleryController.imageHeaders,
                  showRecentPhotoMetadata: widget.showRecentPhotoMetadata,
                  isMySmruti: _isMySmrutiFilter,
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
                const SliverToBoxAdapter(child: SizedBox(height: 112)),
              ],
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: _showBottomBar || _searchFocusNode.hasFocus
                  ? Offset.zero
                  : const Offset(0, 1.15),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _showBottomBar || _searchFocusNode.hasFocus ? 1 : 0,
                child: _GalleryBottomSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onFilterTap: _openFilters,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryBottomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onFilterTap;

  const _GalleryBottomSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            28,
            16,
            MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            backgroundBlendMode: BlendMode.dstOut,
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              stops: const [0.5, 0.7, 0.9, 1],
              colors: [
                Colors.transparent,
                scheme.surface.withAlpha(60),
                scheme.surface,
                scheme.surface,
              ],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onTapOutside: (_) => focusNode.unfocus(),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search smruti',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    prefixIcon: Icon(
                      CupertinoIcons.search,
                      color: primaryColor,
                      size: 19,
                    ),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: controller.clear,
                            icon: const Icon(
                              CupertinoIcons.xmark_circle_fill,
                              size: 18,
                            ),
                          ),
                    filled: true,
                    fillColor: scheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: scheme.outlineVariant.withAlpha(80),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: primaryColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onFilterTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      centerTitle: true,
      expandedHeight: expandedHeight,
      backgroundColor: Colors.transparent,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      title: selectionMode
          ? Text(
              '$selectedCount selected',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
      surfaceTintColor: Colors.transparent,
      leading: FrostedAppBarIconButton(
        icon: selectionMode
            ? CupertinoIcons.xmark
            : CupertinoIcons.chevron_left,
        tooltip: selectionMode ? 'Close selection' : 'Back',
        onPressed: selectionMode
            ? onCloseSelection
            : () => Navigator.pop(context),
      ),
      actions: [
        if (allowIgnore)
          FrostedAppBarIconButton(
            icon: selectionMode
                ? CupertinoIcons.checkmark_alt_circle_fill
                : CupertinoIcons.checkmark_alt_circle,
            tooltip: selectionMode ? 'Done' : 'Select photos',
            onPressed: selectionMode ? onCloseSelection : onStartSelection,
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
              Container(
                color: Theme.of(context).colorScheme.surface.withAlpha(105),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(24),
                      Theme.of(context).colorScheme.surface,
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
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
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF171211).withAlpha(220)
                : const Color(0xFFFFFBF8).withAlpha(218),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withAlpha(22)
                    : Colors.black.withAlpha(16),
              ),
            ),
          ),
        ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFFFFB59F) : primaryColor;
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
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            height: 1.08,
            shadows: [
              Shadow(color: scheme.surface.withAlpha(190), blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (filterLabels.isEmpty)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withAlpha(55)),
      ),
      child: Text(
        label,
        maxLines: 1,
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
  final bool isMySmruti;
  final bool selectionMode;
  final Set<int> selectedPhotoIds;
  final ValueChanged<GalleryPhoto> onToggleSelection;

  const _MosaicPhotoSliver({
    required this.photos,
    required this.title,
    required this.headers,
    required this.showRecentPhotoMetadata,
    required this.isMySmruti,
    required this.selectionMode,
    required this.selectedPhotoIds,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: responsiveImageColumnCount(context),
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
            isMySmruti: isMySmruti,
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
  final bool isMySmruti;
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
    required this.isMySmruti,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (selectionMode) {
          onToggleSelection(photo);
          return;
        }
        Navigator.push(
          context,
          CupertinoPageRoute(
            settings: const RouteSettings(name: 'Photo Viewer'),
            builder: (_) => GalleryFullscreenViewer(
              photos: allPhotos,
              initialIndex: index,
              title: title,
              showRecentPhotoMetadata: showRecentPhotoMetadata,
              isMySmruti: isMySmruti,
            ),
          ),
        );
      },
      onLongPress: () => onToggleSelection(photo),
      child: Hero(
        tag: 'photo-${photo.id}',
        flightShuttleBuilder:
            (flightContext, animation, direction, fromContext, toContext) =>
                _transparentPhotoHeroFlight(
                  flightContext,
                  animation,
                  direction,
                  fromContext,
                  toContext,
                  photo: photo,
                  headers: headers,
                ),
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
                  fit: BoxFit.contain,
                ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class GalleryFullscreenViewer extends StatefulWidget {
  final List<GalleryPhoto> photos;
  final List<GalleryPhoto> leadingPhotos;
  final int initialIndex;
  final String title;
  final bool showRecentPhotoMetadata;
  final bool isRecentFeed;
  final bool isMySmruti;

  const GalleryFullscreenViewer({
    super.key,
    required this.photos,
    this.leadingPhotos = const [],
    required this.initialIndex,
    required this.title,
    this.showRecentPhotoMetadata = false,
    this.isRecentFeed = false,
    this.isMySmruti = false,
  });

  @override
  State<GalleryFullscreenViewer> createState() =>
      _GalleryFullscreenViewerState();
}

class _GalleryFullscreenViewerState extends State<GalleryFullscreenViewer>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final ScrollController _thumbnailScrollController;
  late final TransformationController _transformationController;
  late final AnimationController _zoomAnimationController;
  late final AnimationController _dismissAnimationController;
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
  bool _isSettingWallpaper = false;
  bool _isDownloading = false;
  bool _isSlideshowPlaying = false;
  Timer? _slideshowTimer;
  late final AudioPlayer _musicPlayer;
  List<SlideshowTrack> _musicTracks = const [];
  int _musicIndex = 0;
  bool _musicLoading = false;
  String? _musicError;
  StreamSubscription<int?>? _musicIndexSubscription;
  StreamSubscription<Duration>? _musicPositionSubscription;
  Timer? _musicFadeTimer;
  bool _musicTransitioning = false;
  Offset _lastDoubleTapPosition = Offset.zero;
  int _gesturePointerCount = 1;
  double _dismissDragOffset = 0;
  double _dismissDragStartOffset = 0;
  double _dismissGestureDx = 0;
  double _dismissGestureDy = 0;
  bool _draggingToDismiss = false;
  final Set<int> _activeViewerPointers = <int>{};
  late final List<GalleryPhoto> _localPhotos;
  bool get _isMySmruti =>
      widget.isMySmruti || widget.title.trim().toLowerCase() == 'my smruti';

  @override
  void initState() {
    super.initState();
    _localPhotos = List<GalleryPhoto>.of(widget.photos);
    _musicPlayer = AudioPlayer();
    _musicIndexSubscription = _musicPlayer.currentIndexStream.listen((index) {
      if (!mounted || index == null) return;
      setState(() => _musicIndex = index);
    });
    _musicPositionSubscription = _musicPlayer.positionStream.listen(
      _handleMusicPosition,
    );
    _index = widget.initialIndex;
    _allowIgnore = _isMySmruti;
    _loadIgnoreFeature();
    _pageController = PageController(initialPage: widget.initialIndex);
    _thumbnailScrollController = ScrollController();
    _transformationController = TransformationController();
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _dismissAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          if (!mounted) return;
          setState(() {
            _dismissDragOffset =
                _dismissDragStartOffset *
                (1 -
                    Curves.easeOutCubic.transform(
                      _dismissAnimationController.value,
                    ));
          });
        });
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
    _slideshowTimer?.cancel();
    _musicIndexSubscription?.cancel();
    _musicPositionSubscription?.cancel();
    _musicFadeTimer?.cancel();
    _musicPlayer.dispose();
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
    _dismissAnimationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  List<GalleryPhoto> get _photosList {
    final photos = widget.isRecentFeed
        ? _controller.recentPhotos
        : _localPhotos;
    if (widget.leadingPhotos.isEmpty) return photos;
    final leadingUrls = widget.leadingPhotos
        .expand((photo) => [photo.fullUrl, photo.thumbnailUrl])
        .where((url) => url.isNotEmpty)
        .toSet();
    return <GalleryPhoto>[
      ...widget.leadingPhotos,
      ...photos.where(
        (photo) =>
            !leadingUrls.contains(photo.fullUrl) &&
            !leadingUrls.contains(photo.thumbnailUrl),
      ),
    ];
  }

  GalleryPhoto get _photo => _photosList[_index];

  Future<void> _toggleSlideshow() async {
    if (_photosList.length < 2) return;

    if (_isSlideshowPlaying) {
      _slideshowTimer?.cancel();
      _slideshowTimer = null;

      if (_pageController.hasClients) {
        _pageController.jumpToPage(_index);
      }

      setState(() {
        _isSlideshowPlaying = false;
        _chromeVisible = true;
      });
      await _musicPlayer.pause();
      return;
    }

    setState(() {
      _isSlideshowPlaying = true;
      _infoPanelOpen = false;
      _chromeVisible = true;
    });
    await _startSlideshowMusic();

    _slideshowTimer?.cancel();
    _slideshowTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_isSlideshowPlaying || _photosList.length < 2) {
        return;
      }

      final nextIndex = (_index + 1) % _photosList.length;
      setState(() => _index = nextIndex);
      _precacheAround(nextIndex);
      _maybeLoadMoreRecent(nextIndex);
    });
  }

  Future<void> _startSlideshowMusic() async {
    if (_musicTracks.isNotEmpty) {
      _musicFadeTimer?.cancel();
      _musicTransitioning = false;
      await _musicPlayer.setVolume(1);
      unawaited(_musicPlayer.play());
      return;
    }
    if (_musicLoading) return;
    setState(() {
      _musicLoading = true;
      _musicError = null;
    });
    try {
      final tracks = await _repository.getSlideshowMusic();
      if (!mounted) return;
      if (tracks.isEmpty) {
        setState(() => _musicError = 'No music found');
        return;
      }
      final initialIndex = math.Random().nextInt(tracks.length);
      await _musicPlayer.setAudioSources(
        tracks.map((track) => AudioSource.uri(Uri.parse(track.url))).toList(),
        initialIndex: initialIndex,
      );
      await _musicPlayer.setLoopMode(LoopMode.all);
      if (!mounted) return;
      setState(() {
        _musicTracks = tracks;
        _musicIndex = initialIndex;
      });
      if (_isSlideshowPlaying) unawaited(_musicPlayer.play());
    } catch (error) {
      if (mounted) setState(() => _musicError = 'Music is unavailable');
      debugPrint('Unable to load slideshow music: $error');
    } finally {
      if (mounted) setState(() => _musicLoading = false);
    }
  }

  Future<void> _selectMusicTrack(int index) async {
    if (index < 0 || index >= _musicTracks.length) return;
    _musicFadeTimer?.cancel();
    _musicTransitioning = false;
    await _musicPlayer.setVolume(1);
    await _musicPlayer.seek(Duration.zero, index: index);
    unawaited(_musicPlayer.play());
  }

  Future<void> _previousMusicTrack() async {
    if (_musicTracks.isEmpty) return;
    final previous =
        (_musicIndex - 1 + _musicTracks.length) % _musicTracks.length;
    await _selectMusicTrack(previous);
  }

  Future<void> _nextMusicTrack() async {
    if (_musicTracks.isEmpty) return;
    await _selectMusicTrack((_musicIndex + 1) % _musicTracks.length);
  }

  void _handleMusicPosition(Duration position) {
    if (_musicTransitioning || !_musicPlayer.playing) return;
    final duration = _musicPlayer.duration;
    if (duration == null || duration <= const Duration(seconds: 5)) return;

    final remaining = duration - position;
    const fadeWindow = Duration(seconds: 5);
    if (remaining <= fadeWindow &&
        remaining > const Duration(milliseconds: 900)) {
      final volume = (remaining.inMilliseconds / fadeWindow.inMilliseconds)
          .clamp(.18, 1.0)
          .toDouble();
      unawaited(_musicPlayer.setVolume(volume));
    }

    if (remaining <= const Duration(milliseconds: 900)) {
      unawaited(_transitionToNextMusicTrack());
    }
  }

  Future<void> _transitionToNextMusicTrack() async {
    if (_musicTransitioning || _musicTracks.length < 2) return;
    _musicTransitioning = true;
    _musicFadeTimer?.cancel();
    final nextIndex = (_musicIndex + 1) % _musicTracks.length;
    try {
      await _musicPlayer.setVolume(0);
      await _musicPlayer.seek(Duration.zero, index: nextIndex);
      unawaited(_musicPlayer.play());

      const steps = 24;
      var step = 0;
      _musicFadeTimer = Timer.periodic(const Duration(milliseconds: 75), (
        timer,
      ) {
        if (!_musicPlayer.playing) {
          timer.cancel();
          _musicTransitioning = false;
          return;
        }
        step++;
        final progress = (step / steps).clamp(0.0, 1.0);
        final eased = Curves.easeInOutCubic.transform(progress);
        unawaited(_musicPlayer.setVolume(eased));
        if (step >= steps) {
          timer.cancel();
          _musicTransitioning = false;
        }
      });
    } catch (error) {
      _musicTransitioning = false;
      await _musicPlayer.setVolume(1);
      debugPrint('Unable to transition slideshow music: $error');
    }
  }

  Future<void> _showMusicPicker() async {
    if (_musicTracks.isEmpty) {
      await _startSlideshowMusic();
      if (_musicTracks.isEmpty || !mounted) return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _MusicPickerSheet(tracks: _musicTracks, selectedIndex: _musicIndex),
    );
    if (selected != null) await _selectMusicTrack(selected);
  }

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

      // Never decode the original merely to discover its dimensions. A large
      // photo can require hundreds of MB once expanded to RGBA. The API should
      // normally provide width/height; the thumbnail is a safe fallback.
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
      final decodeWidth = _memorySafeDecodeWidth(
        context,
        photo,
        widthMultiplier: 2,
        maxPixels: 3000000,
      );
      precacheImage(
        ResizeImage(
          CachedNetworkImageProvider(
            photo.fullUrl,
            headers: _controller.imageHeaders,
          ),
          width: decodeWidth,
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
    try {
      final attributes = await _attributesFor(_photo.id);
      final name = _firstShareValue([
        _photo.darshanOf,
        _photo.smrutiOf,
        attributes.person,
        _photo.title,
      ]);
      final date = _shareDate(
        _photo.eventDate ?? _photo.takenAt ?? _photo.createdAt,
      );
      final location = _shareLocation(attributes);
      final link = DeepLinkService.photoUri(_photo);

      await SharePlus.instance.share(
        ShareParams(
          text:
              '📲 HariPrabodham Smruti\n\n'
              '🙏 Darshan of: $name\n'
              '📅 $date\n'
              '📍 $location\n\n'
              '🔗 Open Smruti Darshan:\n$link',
          subject: 'HariPrabodham Smruti',
        ),
      );
    } catch (_) {
      TopNotification.error('Unable to share this photo');
    }
  }

  String _firstShareValue(List<String?> values) {
    for (final value in values) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return 'HariPrabodham';
  }

  String _shareDate(DateTime? date) {
    if (date == null) return 'Date not available';
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

  String _shareLocation(GalleryPhotoAttributes attributes) {
    final parts = <String>[];
    for (final value in [
      attributes.location,
      _photo.location,
      attributes.country,
      _photo.country,
    ]) {
      final text = value?.trim();
      if (text == null || text.isEmpty) continue;
      if (parts.any((part) => part.toLowerCase() == text.toLowerCase())) {
        continue;
      }
      parts.add(text);
    }
    return parts.isEmpty ? 'Location not available' : parts.join(', ');
  }

  Future<void> _showDownloadOptions() async {
    if (_isDownloading) return;
    if (!AuthRedirectHelper.ensureLoggedIn()) return;
    final allowEnhancement = Get.find<SmrutiSectionController>()
        .isFeatureEnabled('ai_enhancement');
    final quality = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => _themedPhotoActionSheet(
        context,
        CupertinoActionSheet(
          title: const Text('Download quality'),
          message: const Text(
            'Enhanced versions are prepared only when requested and expire automatically.',
          ),
          actions: [
            const _DownloadQualityAction(
              value: 'original',
              title: 'Original',
              subtitle: 'No enhancement',
            ),
            if (allowEnhancement)
              const _DownloadQualityAction(
                value: 'sd',
                title: 'SD',
                subtitle: 'Smaller download',
              ),
            if (allowEnhancement)
              const _DownloadQualityAction(
                value: 'hd',
                title: 'HD',
                subtitle: 'Up to 1280 px',
              ),
            if (allowEnhancement)
              const _DownloadQualityAction(
                value: 'fhd',
                title: 'Full HD',
                subtitle: 'Enhanced up to 1920 px',
              ),
            if (allowEnhancement)
              const _DownloadQualityAction(
                value: '2k',
                title: 'Enhanced 2K',
                subtitle: 'Prepared on demand',
              ),
            if (allowEnhancement)
              const _DownloadQualityAction(
                value: '4k',
                title: 'Enhanced 4K',
                subtitle: 'Largest file · prepared on demand',
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ),
      ),
    );
    if (quality == null || !mounted) return;
    await _downloadQuality(quality);
  }

  Future<void> _downloadQuality(String quality) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      if (quality != 'original') {
        final job = await _repository.createPhotoEnhancement(
          photoId: _photo.id,
          quality: quality,
        );
        final position = int.tryParse('${job['queue_position']}');
        if (!mounted) return;
        TopNotification.success(
          position == null
              ? 'Download request added to the queue. We will notify you when it is ready.'
              : 'Download request queued at position $position. We will notify you when it is ready.',
          title: 'Enhancement requested',
        );
        return;
      }

      final downloadUrl = _photo.fullUrl;
      final tempDir = await getTemporaryDirectory();
      final fileName = 'harismruti-${_photo.id}-original.jpg';
      final filePath = '${tempDir.path}${Platform.pathSeparator}$fileName';
      await Dio().download(
        downloadUrl,
        filePath,
        options: Options(
          headers: _controller.imageHeaders,
          responseType: ResponseType.bytes,
        ),
      );
      const albumName = 'HariPrabodham Smruti';
      var hasGalleryAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasGalleryAccess) {
        hasGalleryAccess = await Gal.requestAccess(toAlbum: true);
      }
      if (!hasGalleryAccess) {
        throw Exception('Gallery permission is required to save the photo');
      }
      await Gal.putImage(filePath, album: albumName);
      DownloadLibraryService.recordOriginal(_photo);
      if (!mounted) return;
      TopNotification.success('Photo saved to the "$albumName" album');
    } catch (error) {
      if (!mounted) return;
      TopNotification.error(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
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

  Future<void> _showWallpaperOptions() async {
    if (Platform.isIOS) {
      await _openIosWallpaperFlow();
      return;
    }
    if (!Platform.isAndroid) {
      TopNotification.error('Wallpaper setup is not supported on this device');
      return;
    }

    final destination = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => _themedPhotoActionSheet(
        context,
        CupertinoActionSheet(
          title: const Text('Set as wallpaper'),
          message: const Text('Choose where this photo should appear.'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _showDownloadOptions();
              },
              child: Text(_isDownloading ? 'Preparing Download…' : 'Download'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'editor'),
              child: const Text('Crop & Adjust with Phone'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'home'),
              child: const Text('Home Screen'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'lock'),
              child: const Text('Lock Screen'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'both'),
              child: const Text('Home & Lock Screens'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
    if (destination == null) return;
    if (destination == 'editor') {
      await _openSystemWallpaperEditor();
    } else {
      await _setWallpaper(destination);
    }
  }

  Future<void> _openIosWallpaperFlow() async {
    if (_isSettingWallpaper) return;
    final continueToShare = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Set as Wallpaper'),
        content: const Text(
          'On the next screen, scroll down and tap “Use as Wallpaper”. '
          'If that option is not shown, tap “Save Image”, then open the photo '
          'in Photos and choose Share > Use as Wallpaper.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (continueToShare != true || !mounted) return;

    final url = _photo.fullUrl.isNotEmpty
        ? _photo.fullUrl
        : _photo.thumbnailUrl;
    if (url.isEmpty) {
      TopNotification.error('Photo is not ready to use as wallpaper');
      return;
    }

    setState(() => _isSettingWallpaper = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = _shareFileName(url);
      final wallpaperFile = File(
        '${tempDir.path}${Platform.pathSeparator}ios-wallpaper-$fileName',
      );
      await Dio().download(
        url,
        wallpaperFile.path,
        options: Options(
          headers: _controller.imageHeaders,
          responseType: ResponseType.bytes,
        ),
      );
      await _wallpaperChannel.invokeMethod<bool>('saveToPhotos', {
        'path': wallpaperFile.path,
      });
      if (!mounted) return;
      TopNotification.success('Wallpaper saved to Photos');
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              wallpaperFile.path,
              mimeType: _shareMimeType(wallpaperFile.path),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      TopNotification.error('Unable to prepare this wallpaper');
    } finally {
      if (mounted) setState(() => _isSettingWallpaper = false);
    }
  }

  Future<void> _openSystemWallpaperEditor() async {
    if (_isSettingWallpaper) return;
    final url = _photo.fullUrl.isNotEmpty
        ? _photo.fullUrl
        : _photo.thumbnailUrl;
    if (url.isEmpty) {
      TopNotification.error('Photo is not ready to use as wallpaper');
      return;
    }

    setState(() => _isSettingWallpaper = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final wallpaperFile = File(
        '${tempDir.path}${Platform.pathSeparator}'
        'wallpaper-editor-${_photo.id}-${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await Dio().download(
        url,
        wallpaperFile.path,
        options: Options(
          headers: _controller.imageHeaders,
          responseType: ResponseType.bytes,
        ),
      );
      await _wallpaperChannel.invokeMethod<bool>('openWallpaperEditor', {
        'path': wallpaperFile.path,
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      TopNotification.error(
        error.message ?? 'Unable to open the phone wallpaper editor',
      );
    } catch (_) {
      if (!mounted) return;
      TopNotification.error('Unable to open the phone wallpaper editor');
    } finally {
      if (mounted) setState(() => _isSettingWallpaper = false);
    }
  }

  Future<void> _openPhotoEditor() async {
    if (_isDownloading) return;
    final url = _photo.fullUrl.isNotEmpty
        ? _photo.fullUrl
        : _photo.thumbnailUrl;
    if (url.isEmpty) {
      TopNotification.error('Photo is not ready to edit');
      return;
    }

    setState(() => _isDownloading = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final sourcePath =
          '${tempDir.path}${Platform.pathSeparator}edit-${_shareFileName(url)}';
      await Dio().download(
        url,
        sourcePath,
        options: Options(
          headers: _controller.imageHeaders,
          responseType: ResponseType.bytes,
        ),
      );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (editorContext) => ProImageEditor.file(
            File(sourcePath),
            configs: _photoEditorConfigs(editorContext),
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (bytes) async {
                try {
                  const albumName = 'HariPrabodham Smruti';
                  var hasGalleryAccess = await Gal.hasAccess(toAlbum: true);
                  if (!hasGalleryAccess) {
                    hasGalleryAccess = await Gal.requestAccess(toAlbum: true);
                  }
                  if (!hasGalleryAccess) {
                    throw Exception(
                      'Gallery permission is required to save the photo',
                    );
                  }
                  final editedPath =
                      '${tempDir.path}${Platform.pathSeparator}'
                      'edited-${_photo.id}-${DateTime.now().millisecondsSinceEpoch}.jpg';
                  await File(editedPath).writeAsBytes(bytes, flush: true);
                  await Gal.putImage(editedPath, album: albumName);
                  if (editorContext.mounted) Navigator.pop(editorContext);
                  if (mounted) {
                    TopNotification.success(
                      'Edited photo saved to "$albumName"',
                    );
                  }
                } catch (error) {
                  if (mounted) {
                    TopNotification.error(
                      error.toString().replaceFirst('Exception: ', ''),
                    );
                  }
                }
              },
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      TopNotification.error(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  ProImageEditorConfigs _photoEditorConfigs(BuildContext context) {
    const cream = Color(0xFFF8F3EC);
    const warmSurface = Color(0xFFFFFBF7);
    const ink = Color(0xFF3B2418);
    const canvas = Color(0xFF171311);
    final baseTheme = Theme.of(context);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      surface: warmSurface,
    );

    return ProImageEditorConfigs(
      designMode: Platform.isIOS
          ? ImageEditorDesignMode.cupertino
          : ImageEditorDesignMode.material,
      theme: baseTheme.copyWith(
        brightness: Brightness.light,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: cream,
        canvasColor: cream,
        dividerColor: primaryColor.withAlpha(28),
        appBarTheme: const AppBarTheme(
          backgroundColor: cream,
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: warmSurface,
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
        ),
        sliderTheme: baseTheme.sliderTheme.copyWith(
          activeTrackColor: primaryColor,
          thumbColor: primaryColor,
          overlayColor: primaryColor.withAlpha(24),
          inactiveTrackColor: primaryColor.withAlpha(48),
        ),
      ),
      mainEditor: MainEditorConfigs(
        style: MainEditorStyle(
          background: canvas,
          appBarBackground: cream,
          appBarColor: ink,
          bottomBarBackground: cream,
          bottomBarColor: ink,
          uiOverlayStyle: SystemUiOverlayStyle.dark,
          outsideCaptureAreaLayerOpacity: 0.72,
        ),
      ),
      paintEditor: PaintEditorConfigs(
        style: PaintEditorStyle(
          background: canvas,
          appBarBackground: cream,
          appBarColor: ink,
          bottomBarBackground: cream,
          bottomBarActiveItemColor: primaryColor,
          bottomBarInactiveItemColor: ink,
          lineWidthBottomSheetBackground: warmSurface,
          opacityBottomSheetBackground: warmSurface,
          editSheetBackgroundColor: cream,
          editSheetPreviewAreaColor: warmSurface,
          initialColor: primaryColor,
          uiOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),
      textEditor: TextEditorConfigs(
        initialPrimaryColor: primaryColor,
        style: TextEditorStyle(
          appBarBackground: cream,
          appBarColor: ink,
          bottomBarBackground: cream,
          background: Color(0xC4171311),
          inputHintColor: Color(0xFF8E7A6D),
          inputCursorColor: primaryColor,
          fontScaleBottomSheetBackground: warmSurface,
        ),
      ),
      cropRotateEditor: CropRotateEditorConfigs(
        style: CropRotateEditorStyle(
          appBarBackground: cream,
          appBarColor: ink,
          bottomBarBackground: cream,
          bottomBarColor: ink,
          background: canvas,
          cropCornerColor: primaryColor,
          helperLineColor: primaryColor,
          aspectRatioSheetBackgroundColor: warmSurface,
          aspectRatioSheetForegroundColor: ink,
          uiOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),
      tuneEditor: TuneEditorConfigs(
        style: TuneEditorStyle(
          appBarBackground: cream,
          appBarColor: ink,
          bottomBarBackground: cream,
          bottomBarActiveItemColor: primaryColor,
          bottomBarInactiveItemColor: ink,
          background: canvas,
          uiOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),
      filterEditor: FilterEditorConfigs(
        style: FilterEditorStyle(
          appBarBackground: cream,
          appBarColor: ink,
          background: canvas,
          previewTextColor: Color(0xFFE6DAD0),
          previewSelectedTextColor: primaryColor,
          uiOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),
      blurEditor: BlurEditorConfigs(
        style: BlurEditorStyle(
          appBarBackgroundColor: cream,
          appBarForegroundColor: ink,
          background: canvas,
          uiOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),
    );
  }

  Future<void> _setWallpaper(String destination) async {
    if (_isSettingWallpaper) return;
    final url = _photo.fullUrl.isNotEmpty
        ? _photo.fullUrl
        : _photo.thumbnailUrl;
    if (url.isEmpty) {
      TopNotification.error('Photo is not ready to use as wallpaper');
      return;
    }

    setState(() => _isSettingWallpaper = true);
    File? wallpaperFile;
    try {
      final tempDir = await getTemporaryDirectory();
      wallpaperFile = File(
        '${tempDir.path}${Platform.pathSeparator}wallpaper-${_photo.id}.jpg',
      );
      await Dio().download(
        url,
        wallpaperFile.path,
        options: Options(
          headers: _controller.imageHeaders,
          responseType: ResponseType.bytes,
        ),
      );
      await _wallpaperChannel.invokeMethod<bool>('setWallpaper', {
        'path': wallpaperFile.path,
        'destination': destination,
      });
      if (!mounted) return;
      TopNotification.success('Wallpaper set successfully');
    } on PlatformException catch (error) {
      if (!mounted) return;
      TopNotification.error(error.message ?? 'Unable to set wallpaper');
    } catch (_) {
      if (!mounted) return;
      TopNotification.error('Unable to set wallpaper');
    } finally {
      if (wallpaperFile?.existsSync() == true) {
        wallpaperFile!.deleteSync();
      }
      if (mounted) setState(() => _isSettingWallpaper = false);
    }
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
      final features = await _repository.getMobileFeatures(
        forMySmruti: _isMySmruti,
      );
      if (!mounted) return;
      setState(
        () => _allowIgnore = _isMySmruti || features['allow_ignore'] == true,
      );
    } catch (_) {
      // My Smruti ignore is a standard self-service action. Other sections
      // remain hidden when their admin-controlled feature flag cannot load.
      if (mounted && _isMySmruti) setState(() => _allowIgnore = true);
    }
  }

  Future<void> _ignoreCurrentPhoto() async {
    if (!_allowIgnore || _isIgnoring || _photo.id <= 0) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Ignore this photo?'),
        content: Text(
          _isMySmruti
              ? 'This photo will be hidden only from your My Smruti section.'
              : 'This photo will be hidden from your gallery.',
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
      final photoId = _photo.id;
      final ignored = await _repository.ignorePhotos({
        photoId,
      }, forMySmruti: _isMySmruti);
      if (!mounted) return;
      if (ignored.isEmpty) {
        TopNotification.error('Unable to ignore this photo');
        return;
      }
      if (_isMySmruti && Get.isRegistered<MyPhotosController>()) {
        Get.find<MyPhotosController>().matchedPhotos.removeWhere(
          (photo) => ignored.contains(photo.id),
        );
      }
      if (_isMySmruti) {
        _controller.mySmrutiPhotos.removeWhere(
          (photo) => ignored.contains(photo.id),
        );
      }
      TopNotification.success(
        _isMySmruti ? 'Photo hidden from your My Smruti' : 'Photo ignored',
      );
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

  void _handleViewerPointerDown(PointerDownEvent event) {
    _activeViewerPointers.add(event.pointer);
    if (_activeViewerPointers.length != 2 || _zoomModeActive) return;

    // Lock the PageView as soon as the second finger lands. Waiting for
    // InteractiveViewer's scale recognizer allows a horizontal page drag to
    // move briefly before the pinch gesture wins the arena.
    setState(() => _zoomModeActive = true);
  }

  void _handleViewerPointerEnd(PointerEvent event) {
    _activeViewerPointers.remove(event.pointer);
    if (_activeViewerPointers.isNotEmpty ||
        _isZoomed ||
        !_zoomModeActive ||
        !mounted) {
      return;
    }

    setState(() => _zoomModeActive = false);
  }

  void _handleZoomInteractionStart(ScaleStartDetails details) {
    _zoomAnimationController.stop();
    _clearZoomAnimation();
    _gesturePointerCount = details.pointerCount;
    _dismissAnimationController.stop();
    _dismissGestureDx = 0;
    _dismissGestureDy = 0;
    _draggingToDismiss = false;

    if (details.pointerCount < 2 && !_isZoomed) return;
    if (_zoomModeActive && !_chromeVisible) return;

    setState(() {
      _zoomModeActive = true;
      _chromeVisible = false;
    });
  }

  void _handleZoomInteractionUpdate(ScaleUpdateDetails details) {
    _gesturePointerCount = details.pointerCount;
    if (details.pointerCount == 1 && !_isZoomed && !_zoomModeActive) {
      _dismissGestureDx += details.focalPointDelta.dx;
      _dismissGestureDy += details.focalPointDelta.dy;
      final verticalIntent =
          _dismissGestureDy > 8 &&
          _dismissGestureDy.abs() > _dismissGestureDx.abs() * 1.15;
      if (_draggingToDismiss || verticalIntent) {
        setState(() {
          _draggingToDismiss = true;
          _dismissDragOffset = _dismissGestureDy.clamp(0.0, 360.0);
          _chromeVisible = false;
        });
        return;
      }
    }
    _clampZoomTranslation();
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
    if (_draggingToDismiss) {
      final velocity = details.velocity.pixelsPerSecond.dy;
      final shouldDismiss = _dismissDragOffset > 110 || velocity > 700;
      if (shouldDismiss) {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      } else {
        _dismissDragStartOffset = _dismissDragOffset;
        _dismissAnimationController.forward(from: 0).whenComplete(() {
          if (!mounted) return;
          setState(() {
            _dismissDragOffset = 0;
            _draggingToDismiss = false;
            _chromeVisible = true;
          });
        });
      }
      return;
    }
    _clampZoomTranslation();
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

  void _clampZoomTranslation([Matrix4? candidate]) {
    final matrix = candidate ?? _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    if (scale <= 1) return;

    final viewport = MediaQuery.sizeOf(context);
    final sourceWidth = _photo.width?.toDouble() ?? viewport.width;
    final sourceHeight = _photo.height?.toDouble() ?? viewport.height;
    if (sourceWidth <= 0 || sourceHeight <= 0) return;

    final sourceAspect = sourceWidth / sourceHeight;
    final viewportAspect = viewport.width / viewport.height;
    final fittedWidth = sourceAspect > viewportAspect
        ? viewport.width
        : viewport.height * sourceAspect;
    final fittedHeight = sourceAspect > viewportAspect
        ? viewport.width / sourceAspect
        : viewport.height;
    final fittedLeft = (viewport.width - fittedWidth) / 2;
    final fittedTop = (viewport.height - fittedHeight) / 2;
    final storage = matrix.storage;

    double constrainedTranslation({
      required double translation,
      required double contentStart,
      required double contentSize,
      required double viewportSize,
    }) {
      final scaledSize = contentSize * scale;
      if (scaledSize <= viewportSize) {
        return (viewportSize - scaledSize) / 2 - contentStart * scale;
      }
      final minimum = viewportSize - (contentStart + contentSize) * scale;
      final maximum = -contentStart * scale;
      return translation.clamp(minimum, maximum).toDouble();
    }

    final x = constrainedTranslation(
      translation: storage[12],
      contentStart: fittedLeft,
      contentSize: fittedWidth,
      viewportSize: viewport.width,
    );
    final y = constrainedTranslation(
      translation: storage[13],
      contentStart: fittedTop,
      contentSize: fittedHeight,
      viewportSize: viewport.height,
    );
    if ((x - storage[12]).abs() < 0.01 && (y - storage[13]).abs() < 0.01) {
      return;
    }

    final clamped = matrix.clone()..setTranslationRaw(x, y, storage[14]);
    if (candidate != null) {
      candidate.setFrom(clamped);
    } else {
      _transformationController.value = clamped;
    }
  }

  void _animateZoomTo(Matrix4 target, {required bool isZoomed}) {
    _zoomAnimationController.stop();
    _clearZoomAnimation();
    if (isZoomed) _clampZoomTranslation(target);
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

  Future<void> _openRemoveTagSheet() async {
    if (!AuthRedirectHelper.ensureLoggedIn()) return;
    final appliedTags = _controller.tagsForPhoto(_photo.id);
    if (appliedTags.isEmpty) return;

    final tag = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => _themedPhotoActionSheet(
        context,
        CupertinoActionSheet(
          title: const Text('Remove Tag'),
          message: const Text('Choose a tag to remove from this image.'),
          actions: [
            for (final tag in appliedTags)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(context, tag),
                child: Text(tag),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
    if (tag == null) return;

    final removed = await _controller.removeTagFromPhoto(_photo.id, tag);
    if (!mounted) return;
    TopNotification.show(
      message: removed
          ? 'Tag "$tag" removed from this image'
          : 'Could not remove tag "$tag"',
      type: removed ? AppNotificationType.success : AppNotificationType.error,
    );
  }

  void _showMoreOptions() {
    final showAddNoteInDiary =
        !Get.isRegistered<SmrutiSectionController>() ||
        Get.find<SmrutiSectionController>().isSectionVisible('my_diary');
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => _themedPhotoActionSheet(
        context,
        CupertinoActionSheet(
          title: const Text('Photo options'),
          actions: [
            if (_photosList.length > 1)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _toggleSlideshow();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isSlideshowPlaying
                          ? CupertinoIcons.pause
                          : CupertinoIcons.play,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isSlideshowPlaying
                          ? 'Pause Slideshow'
                          : 'Start Slideshow',
                    ),
                  ],
                ),
              ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _openPhotoEditor();
              },
              child: const Text('Edit Photo'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _showDownloadOptions();
              },
              child: Text(_isDownloading ? 'Preparing Download…' : 'Download'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _showWallpaperOptions();
              },
              child: const Text('Set as Wallpaper'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _openAddTagSheet();
              },
              child: const Text('Add Tag'),
            ),
            if (_controller.tagsForPhoto(_photo.id).isNotEmpty)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(context);
                  _openRemoveTagSheet();
                },
                child: const Text('Remove Tag'),
              ),
            if (showAddNoteInDiary)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  if (!AuthRedirectHelper.ensureLoggedIn()) return;
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      settings: const RouteSettings(name: 'Diary Entry Detail'),
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
      builder: (context) => ResponsiveBottomCenter(
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
    final dismissProgress = (_dismissDragOffset / 320).clamp(0.0, 1.0);
    final dismissScale = 1 - (dismissProgress * 0.12);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewerBackground = _zoomModeActive
        ? Colors.black
        : isDark
        ? scheme.surface
        : Colors.white;
    final topBarVisible = _chromeVisible && !_isSlideshowPlaying;
    final bottomControlsVisible = _chromeVisible || _isSlideshowPlaying;
    return Scaffold(
      backgroundColor: Color.lerp(
        viewerBackground,
        Colors.black,
        dismissProgress * 0.7,
      ),
      body: Stack(
        children: [
          Transform.translate(
            offset: Offset(0, _dismissDragOffset),
            child: Transform.scale(
              scale: dismissScale,
              child: _reactive(
                () => _isSlideshowPlaying
                    ? _CinematicSlideshowPhoto(
                        photo: _photo,
                        title: widget.title,
                        headers: _controller.imageHeaders,
                        transitionIndex: _index,
                        topControlInset: 0,
                        bottomControlInset:
                            66 + MediaQuery.paddingOf(context).bottom,
                      )
                    : Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: _handleViewerPointerDown,
                        onPointerUp: _handleViewerPointerEnd,
                        onPointerCancel: _handleViewerPointerEnd,
                        child: PageView.builder(
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
                            return ClipRect(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onDoubleTapDown: _rememberDoubleTapPosition,
                                onDoubleTap: _toggleZoom,
                                child: InteractiveViewer(
                                  transformationController:
                                      _transformationController,
                                  minScale: 1,
                                  maxScale: 5,
                                  scaleEnabled: true,
                                  panEnabled: _zoomModeActive,
                                  boundaryMargin: EdgeInsets.zero,
                                  clipBehavior: Clip.hardEdge,
                                  onInteractionStart:
                                      _handleZoomInteractionStart,
                                  onInteractionUpdate:
                                      _handleZoomInteractionUpdate,
                                  onInteractionEnd: _handleZoomInteractionEnd,
                                  child: Center(
                                    child: Hero(
                                      tag: 'photo-${photo.id}',
                                      flightShuttleBuilder:
                                          (
                                            flightContext,
                                            animation,
                                            direction,
                                            fromContext,
                                            toContext,
                                          ) => _transparentPhotoHeroFlight(
                                            flightContext,
                                            animation,
                                            direction,
                                            fromContext,
                                            toContext,
                                            photo: photo,
                                            headers: _controller.imageHeaders,
                                          ),
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
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ),
          SafeArea(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: topBarVisible ? Offset.zero : const Offset(0, -1.25),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: topBarVisible ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !topBarVisible,
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
          if (_isSlideshowPlaying)
            Positioned(
              left: 18,
              right: 18,
              bottom: 8 + MediaQuery.paddingOf(context).bottom,
              child: _SlideshowMusicBar(
                player: _musicPlayer,
                track: _musicTracks.isEmpty
                    ? null
                    : _musicTracks[_musicIndex.clamp(
                        0,
                        _musicTracks.length - 1,
                      )],
                isLoading: _musicLoading,
                error: _musicError,
                onChooseTrack: _showMusicPicker,
                onPrevious: _previousMusicTrack,
                onNext: _nextMusicTrack,
                onRetry: _startSlideshowMusic,
                onStop: _toggleSlideshow,
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
              offset: bottomControlsVisible
                  ? Offset.zero
                  : const Offset(0, 1.3),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: bottomControlsVisible ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !bottomControlsVisible,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isSlideshowPlaying)
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
                                            _controller
                                                .isRecentPageLoading
                                                .value,
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
                      if (!_isSlideshowPlaying)
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
                                    onDismiss: _toggleInfoPanel,
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      if (!_isSlideshowPlaying)
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

class _CinematicSlideshowPhoto extends StatelessWidget {
  const _CinematicSlideshowPhoto({
    required this.photo,
    required this.title,
    required this.headers,
    required this.transitionIndex,
    required this.topControlInset,
    required this.bottomControlInset,
  });

  final GalleryPhoto photo;
  final String title;
  final Map<String, String>? headers;
  final int transitionIndex;
  final double topControlInset;
  final double bottomControlInset;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 1050),
        reverseDuration: const Duration(milliseconds: 850),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        transitionBuilder: (child, animation) {
          final fade = FadeTransition(opacity: animation, child: child);
          return switch (transitionIndex % 3) {
            0 => ScaleTransition(
              scale: Tween<double>(begin: 1.12, end: 1).animate(animation),
              child: fade,
            ),
            1 => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .055),
                end: Offset.zero,
              ).animate(animation),
              child: ScaleTransition(
                scale: Tween<double>(begin: .96, end: 1).animate(animation),
                child: fade,
              ),
            ),
            _ => RotationTransition(
              turns: Tween<double>(begin: -.008, end: 0).animate(animation),
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.06, end: 1).animate(animation),
                child: fade,
              ),
            ),
          };
        },
        child: RepaintBoundary(
          key: ValueKey('slideshow-${photo.id}'),
          child: _FullscreenImage(
            photo: photo,
            title: title,
            headers: headers,
            chromeVisible: false,
            topInset: topControlInset,
            bottomInset: bottomControlInset,
          ),
        ),
      ),
    );
  }
}

class _DownloadQualityAction extends StatelessWidget {
  final String value;
  final String title;
  final String subtitle;

  const _DownloadQualityAction({
    required this.value,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoActionSheetAction(
      onPressed: () => Navigator.pop(context, value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Kept temporarily for compatibility with older routes during staged rollout.
// ignore: unused_element
class _EnhancementProgressDialog extends StatelessWidget {
  final ValueListenable<int> progress;

  const _EnhancementProgressDialog({required this.progress});

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('Enhancing photo'),
      content: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, value, __) => Column(
            children: [
              const CupertinoActivityIndicator(radius: 13),
              const SizedBox(height: 12),
              Text('$value% · You can keep the app open while it is prepared.'),
            ],
          ),
        ),
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
              color: Theme.of(context).colorScheme.surface.withAlpha(246),
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
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
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
                              hintText: isCollection
                                  ? 'Search or Create Collection'
                                  : 'Search or Create Tag',
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withAlpha(18)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  final double topInset;
  final double bottomInset;

  const _FullscreenImage({
    required this.photo,
    required this.title,
    required this.headers,
    required this.chromeVisible,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final effectiveTopInset = chromeVisible ? 96.0 : topInset;
    final effectiveBottomInset = chromeVisible ? 132.0 : bottomInset;
    final verticalPadding = effectiveTopInset + effectiveBottomInset;
    // Cap decode resolution so pinch-zoom recompositing a giant source photo
    // doesn't have to raster/scale a huge texture every frame. Sized with
    // headroom above the max pinch scale (5x) so zoomed-in detail still
    // looks sharp. The width is derived from a total-pixel budget so portrait
    // and panorama images receive the same memory protection.
    final cacheWidth = _memorySafeDecodeWidth(
      context,
      photo,
      widthMultiplier: 3,
      maxPixels: 6000000,
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        0,
        effectiveTopInset,
        0,
        effectiveBottomInset,
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
          // Use the exact same bounds and BoxFit as the final image so loading
          // never jumps from a small thumbnail to a large full-resolution
          // photo. The thumbnail may be softer briefly, but layout is stable.
          placeholder: (_, __) => Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(child: ColoredBox(color: Colors.white)),
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: photo.thumbnailUrl,
                  httpHeaders: headers,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const CupertinoActivityIndicator(
                radius: 14,
                color: CupertinoColors.systemGrey,
              ),
            ],
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
        FrostedAppBarIconButton(
          icon: CupertinoIcons.chevron_left,
          tooltip: 'Back',
          onPressed: onBack,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: FutureBuilder<GalleryPhotoAttributes>(
            future: attributesFuture,
            builder: (context, snapshot) {
              final scheme = Theme.of(context).colorScheme;
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final attrs = snapshot.data;
              final placeParts = [
                attrs?.location,
                attrs?.subLocation,
              ].where((value) => value?.trim().isNotEmpty == true).toList();
              final place = placeParts.isNotEmpty
                  ? placeParts.join(' - ')
                  : attrs?.country?.trim() ?? '';
              final displayTitle = place.isNotEmpty ? place : 'No Location';
              final displaySubtitle = _formatTopDateTime(takenAt) ?? '';

              return ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                Colors.white.withAlpha(24),
                                scheme.surface.withAlpha(108),
                              ]
                            : [
                                Colors.white.withAlpha(238),
                                scheme.surfaceContainerHigh.withAlpha(214),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withAlpha(42)
                            : scheme.outlineVariant.withAlpha(115),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withAlpha(isDark ? 55 : 36),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.onSurface,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                )
              : FrostedAppBarIconButton(
                  icon: CupertinoIcons.eye_slash_fill,
                  tooltip: 'Ignore photo',
                  onPressed: onIgnore,
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

class _AnimatedMusicEqualizer extends StatefulWidget {
  const _AnimatedMusicEqualizer({required this.player});

  final AudioPlayer player;

  @override
  State<_AnimatedMusicEqualizer> createState() =>
      _AnimatedMusicEqualizerState();
}

class _AnimatedMusicEqualizerState extends State<_AnimatedMusicEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool _playing = false;

  static const _colors = [
    Color(0xFFD7DF16),
    Color(0xFFF5B719),
    Color(0xFFF07A3F),
    Color(0xFFE74D68),
    Color(0xFFC63691),
    Color(0xFF744DA4),
    Color(0xFF2997C8),
    Color(0xFF11A9C2),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    _playing = widget.player.playing;
    if (_playing) _controller.repeat();
    _playerStateSubscription = widget.player.playerStateStream.listen((state) {
      if (!mounted || state.playing == _playing) return;
      setState(() => _playing = state.playing);
      if (_playing) {
        _controller.repeat();
      } else {
        _controller.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 40,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(13, (index) {
            final centerShape = 1 - ((index - 6).abs() / 8);
            final wave =
                (math.sin((_controller.value * math.pi * 2) + (index * .82)) +
                    1) /
                2;
            final energy = _playing ? (.42 + wave * .58) : .22;
            final height = 5 + (30 * centerShape.clamp(.2, 1) * energy);
            final colorIndex = (index * (_colors.length - 1) / 12).round();
            return AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              width: 3.4,
              height: height,
              decoration: BoxDecoration(
                color: _colors[colorIndex],
                borderRadius: BorderRadius.circular(3),
                boxShadow: _playing
                    ? [
                        BoxShadow(
                          color: _colors[colorIndex].withAlpha(70),
                          blurRadius: 5,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _SlideshowMusicBar extends StatelessWidget {
  const _SlideshowMusicBar({
    required this.player,
    required this.track,
    required this.isLoading,
    required this.error,
    required this.onChooseTrack,
    required this.onPrevious,
    required this.onNext,
    required this.onRetry,
    required this.onStop,
  });

  final AudioPlayer player;
  final SlideshowTrack? track;
  final bool isLoading;
  final String? error;
  final VoidCallback onChooseTrack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withAlpha(150)
                : Colors.white.withAlpha(225),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withAlpha(isDark ? 45 : 210),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(32),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: isLoading
              ? const SizedBox(
                  height: 54,
                  child: Center(child: CupertinoActivityIndicator()),
                )
              : error != null
              ? Row(
                  children: [
                    Icon(
                      CupertinoIcons.music_note_2,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                )
              : Row(
                  children: [
                    _AnimatedMusicEqualizer(player: player),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: onChooseTrack,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track?.name ?? 'Choose music',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              track?.folder ?? 'Smruti music',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onPrevious,
                      icon: const Icon(CupertinoIcons.backward_end_fill),
                      visualDensity: VisualDensity.compact,
                    ),
                    StreamBuilder<PlayerState>(
                      stream: player.playerStateStream,
                      builder: (context, snapshot) {
                        final playing = snapshot.data?.playing ?? false;
                        return IconButton(
                          onPressed: () =>
                              playing ? player.pause() : player.play(),
                          icon: Icon(
                            playing
                                ? CupertinoIcons.pause_circle_fill
                                : CupertinoIcons.play_circle_fill,
                            size: 34,
                            color: const Color(0xFF8B5CF6),
                          ),
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
                    IconButton(
                      onPressed: onNext,
                      icon: const Icon(CupertinoIcons.forward_end_fill),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      onPressed: onStop,
                      tooltip: 'Stop slideshow',
                      icon: Container(
                        width: 31,
                        height: 31,
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withAlpha(28),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.redAccent.withAlpha(75),
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.stop_fill,
                          color: Colors.redAccent,
                          size: 12,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MusicPickerSheet extends StatefulWidget {
  const _MusicPickerSheet({required this.tracks, required this.selectedIndex});

  final List<SlideshowTrack> tracks;
  final int selectedIndex;

  @override
  State<_MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<_MusicPickerSheet> {
  List<String> _currentPath = const [];

  SlideshowTrack? get _selectedTrack {
    if (widget.selectedIndex < 0 ||
        widget.selectedIndex >= widget.tracks.length) {
      return null;
    }
    return widget.tracks[widget.selectedIndex];
  }

  List<String> _folderParts(SlideshowTrack track) {
    final normalized = track.folder.replaceAll('\\', '/').trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'smruti') {
      return const [];
    }
    return normalized
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
  }

  bool _startsWithPath(List<String> parts) {
    if (parts.length < _currentPath.length) return false;
    for (var index = 0; index < _currentPath.length; index++) {
      if (parts[index] != _currentPath[index]) return false;
    }
    return true;
  }

  List<String> get _childFolders {
    final folders = <String>{};
    for (final track in widget.tracks) {
      final parts = _folderParts(track);
      if (_startsWithPath(parts) && parts.length > _currentPath.length) {
        folders.add(parts[_currentPath.length]);
      }
    }
    final sorted = folders.toList()..sort((a, b) => a.compareTo(b));
    return sorted;
  }

  List<SlideshowTrack> get _tracksHere => widget.tracks
      .where((track) {
        if (identical(track, _selectedTrack)) return false;
        final parts = _folderParts(track);
        if (parts.length != _currentPath.length) return false;
        return _startsWithPath(parts);
      })
      .toList(growable: false);

  int _folderTrackCount(String folder) {
    final path = [..._currentPath, folder];
    return widget.tracks.where((track) {
      final parts = _folderParts(track);
      if (parts.length < path.length) return false;
      for (var index = 0; index < path.length; index++) {
        if (parts[index] != path[index]) return false;
      }
      return true;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * .68,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                children: [
                  if (_currentPath.isEmpty)
                    const Icon(
                      CupertinoIcons.music_note_list,
                      color: Color(0xFF8B5CF6),
                    )
                  else
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 36,
                      ),
                      onPressed: () => setState(
                        () => _currentPath = _currentPath.sublist(
                          0,
                          _currentPath.length - 1,
                        ),
                      ),
                      icon: const Icon(CupertinoIcons.back, size: 22),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentPath.isEmpty
                              ? 'Slideshow music'
                              : _currentPath.last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (_currentPath.isNotEmpty)
                          Text(
                            'Smruti / ${_currentPath.join(' / ')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark_circle_fill),
                  ),
                ],
              ),
            ),
            if (_selectedTrack case final track?)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withAlpha(28),
                      const Color(0xFFEC4899).withAlpha(18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withAlpha(55),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        CupertinoIcons.speaker_2_fill,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NOW PLAYING',
                            style: TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            track.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            track.folder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      color: Color(0xFF8B5CF6),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: ListView(
                  key: ValueKey(_currentPath.join('/')),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                  children: [
                    for (final folder in _childFolders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(
                              0xFF8B5CF6,
                            ).withAlpha(24),
                            child: const Icon(
                              CupertinoIcons.folder_fill,
                              color: Color(0xFF8B5CF6),
                              size: 19,
                            ),
                          ),
                          title: Text(
                            folder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${_folderTrackCount(folder)} music files',
                          ),
                          trailing: const Icon(
                            CupertinoIcons.chevron_forward,
                            size: 18,
                          ),
                          onTap: () => setState(
                            () => _currentPath = [..._currentPath, folder],
                          ),
                        ),
                      ),
                    for (final track in _tracksHere)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Builder(
                          builder: (context) {
                            final index = widget.tracks.indexOf(track);
                            final selected = index == widget.selectedIndex;
                            return ListTile(
                              selected: selected,
                              selectedTileColor: const Color(
                                0xFF8B5CF6,
                              ).withAlpha(24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: selected
                                    ? const Color(0xFF8B5CF6)
                                    : scheme.surfaceContainerHighest,
                                child: Icon(
                                  selected
                                      ? CupertinoIcons.speaker_2_fill
                                      : CupertinoIcons.music_note,
                                  color: selected
                                      ? Colors.white
                                      : scheme.onSurfaceVariant,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                track.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: const Text('Music file'),
                              trailing: selected
                                  ? const Icon(
                                      CupertinoIcons.check_mark_circled_solid,
                                      color: Color(0xFF8B5CF6),
                                    )
                                  : null,
                              onTap: () => Navigator.pop(context, index),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        children: [
          FrostedAppBarIconButton(
            icon: CupertinoIcons.square_arrow_up,
            tooltip: 'Share',
            onPressed: onShare,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                Colors.white.withAlpha(24),
                                scheme.surface.withAlpha(105),
                              ]
                            : [
                                Colors.white.withAlpha(170),
                                scheme.surface.withAlpha(88),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withAlpha(40)
                            : Colors.white.withAlpha(205),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 45 : 20),
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
                          color: isFavorite
                              ? Colors.redAccent
                              : scheme.onSurface,
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
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FrostedAppBarIconButton(
            icon: CupertinoIcons.collections,
            tooltip: 'Add to collection',
            onPressed: onCollection,
          ),
        ],
      ),
    );
  }
}

class _ViewerPlainButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _ViewerPlainButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 40,
        child: Icon(
          icon,
          color: color ?? Theme.of(context).colorScheme.onSurface,
          size: 23,
        ),
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

class _InlineInfoPanel extends StatefulWidget {
  final GalleryPhoto photo;
  final Future<GalleryPhotoAttributes> attributesFuture;
  final Future<String> imageSizeFuture;
  final Future<String> storageSizeFuture;
  final VoidCallback onDismiss;

  const _InlineInfoPanel({
    required this.photo,
    required this.attributesFuture,
    required this.imageSizeFuture,
    required this.storageSizeFuture,
    required this.onDismiss,
  });

  @override
  State<_InlineInfoPanel> createState() => _InlineInfoPanelState();
}

class _InlineInfoPanelState extends State<_InlineInfoPanel> {
  double _downwardDrag = 0;

  void _handleDragUpdate(DragUpdateDetails details) {
    _downwardDrag = (_downwardDrag + details.delta.dy).clamp(0.0, 120.0);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldDismiss = _downwardDrag > 45 || velocity > 350;
    _downwardDrag = 0;
    if (shouldDismiss) widget.onDismiss();
  }

  void _handleDragCancel() => _downwardDrag = 0;

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final attributesFuture = widget.attributesFuture;
    final imageSizeFuture = widget.imageSizeFuture;
    final storageSizeFuture = widget.storageSizeFuture;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const borderRadius = BorderRadius.vertical(top: Radius.circular(20));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      onVerticalDragCancel: _handleDragCancel,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.42,
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            decoration: BoxDecoration(
              color: isDark
                  ? scheme.surfaceContainerHigh.withAlpha(190)
                  : scheme.surfaceContainerHigh,
              borderRadius: borderRadius,
              border: isDark
                  ? Border(top: BorderSide(color: Colors.white.withAlpha(28)))
                  : null,
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
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
                        future: Future.wait([
                          imageSizeFuture,
                          storageSizeFuture,
                        ]),
                        builder: (context, snapshot) {
                          final data = snapshot.data;
                          final parts = [
                            if (data != null && data[0] != 'Not available')
                              data[0],
                            if (data != null && data[1] != 'Not available')
                              data[1],
                          ];
                          return Text(
                            parts.isEmpty ? 'Loading...' : parts.join(' • '),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (snapshot.connectionState != ConnectionState.done)
                        const GalleryShimmerBox(height: 86, borderRadius: 18)
                      else if (entries.isEmpty)
                        Text(
                          'No tags added',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _InfoMapCard(attrs: attrs!, photo: photo),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
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
        color: Color.lerp(
          Theme.of(context).colorScheme.surfaceContainer,
          color,
          0.16,
        ),
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
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
          color: Theme.of(context).colorScheme.surfaceContainer,
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
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
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
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHigh.withAlpha(225),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
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
        settings: const RouteSettings(name: 'Gallery Location'),
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
