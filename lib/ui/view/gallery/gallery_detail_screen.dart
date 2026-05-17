import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/home/my_diary_smruti.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';
import 'package:share_plus/share_plus.dart';

const double _homeAppbarBlurSigma = 24;
const int _homeAppbarGlassAlpha = 125;

class GalleryDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? coverUrl;
  final Future<List<GalleryPhoto>> Function() loader;

  const GalleryDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loader,
    this.coverUrl,
  });

  factory GalleryDetailScreen.fromCard(GalleryCard card) {
    final controller = Get.find<GalleryController>();
    return GalleryDetailScreen(
      title: card.title,
      subtitle: card.subtitle,
      coverUrl: card.coverUrl,
      loader: () => controller.loadPhotosForCard(card),
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
    );
  }

  factory GalleryDetailScreen.fromFilters({
    required String title,
    required String subtitle,
    required Map<String, List<String>> selected,
  }) {
    final controller = Get.find<GalleryController>();
    return GalleryDetailScreen(
      title: title,
      subtitle: subtitle,
      loader: () => controller.loadPhotosForFilters(selected: selected),
    );
  }

  @override
  State<GalleryDetailScreen> createState() => _GalleryDetailScreenState();
}

class _GalleryDetailScreenState extends State<GalleryDetailScreen> {
  late final Future<List<GalleryPhoto>> _photosFuture;
  final GalleryController _galleryController = Get.find<GalleryController>();

  @override
  void initState() {
    super.initState();
    _photosFuture = widget.loader();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F3),
      body: FutureBuilder<List<GalleryPhoto>>(
        future: _photosFuture,
        builder: (context, snapshot) {
          final photos = snapshot.data ?? const <GalleryPhoto>[];
          final cover = widget.coverUrl?.isNotEmpty == true
              ? widget.coverUrl!
              : photos.isNotEmpty
              ? photos.first.thumbnailUrl
              : '';

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _MusicStyleHeader(
                title: widget.title,
                subtitle: widget.subtitle,
                coverUrl: cover,
                headers: _galleryController.imageHeaders,
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const SliverPadding(
                  padding: EdgeInsets.all(16),
                  sliver: _DetailShimmerMosaic(),
                )
              else if (photos.isEmpty)
                const SliverToBoxAdapter(
                  child: GalleryEmptyState(
                    height: 260,
                    message: 'No photos found',
                  ),
                )
              else ...[
                _MosaicPhotoSliver(
                  photos: photos,
                  title: widget.title,
                  headers: _galleryController.imageHeaders,
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MusicStyleHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String coverUrl;
  final Map<String, String>? headers;

  const _MusicStyleHeader({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.headers,
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
      surfaceTintColor: Colors.transparent,
      leading: _GlassIconButton(
        icon: CupertinoIcons.chevron_left,
        onTap: () => Navigator.pop(context),
      ),
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
  final Map<String, String>? headers;

  const _ExpandedHeroHeaderContent({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
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
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: primaryColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MosaicPhotoSliver extends StatelessWidget {
  final List<GalleryPhoto> photos;
  final String title;
  final Map<String, String>? headers;

  const _MosaicPhotoSliver({
    required this.photos,
    required this.title,
    required this.headers,
  });

  @override
  Widget build(BuildContext context) {
    final rows = (photos.length / 3).ceil();
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList.builder(
        itemCount: rows,
        itemBuilder: (context, rowIndex) {
          final start = rowIndex * 3;
          final rowPhotos = photos.skip(start).take(3).toList();
          return _MosaicRow(
            photos: rowPhotos,
            allPhotos: photos,
            startIndex: start,
            title: title,
            headers: headers,
            reversed: rowIndex.isOdd,
          );
        },
      ),
    );
  }
}

class _MosaicRow extends StatelessWidget {
  final List<GalleryPhoto> photos;
  final List<GalleryPhoto> allPhotos;
  final int startIndex;
  final String title;
  final Map<String, String>? headers;
  final bool reversed;

  const _MosaicRow({
    required this.photos,
    required this.allPhotos,
    required this.startIndex,
    required this.title,
    required this.headers,
    required this.reversed,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.length == 1) {
      return SizedBox(
        height: 240,
        child: _MosaicTile(
          photo: photos.first,
          allPhotos: allPhotos,
          index: startIndex,
          title: title,
          headers: headers,
        ),
      );
    }

    final bigTile = Expanded(
      flex: 6,
      child: _MosaicTile(
        photo: photos.first,
        allPhotos: allPhotos,
        index: startIndex,
        title: title,
        headers: headers,
      ),
    );
    final stack = Expanded(
      flex: 4,
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: _MosaicTile(
              photo: photos[1],
              allPhotos: allPhotos,
              index: startIndex + 1,
              title: title,
              headers: headers,
            ),
          ),
          if (photos.length > 2) ...[
            const SizedBox(height: 6),
            Expanded(
              flex: 7,
              child: _MosaicTile(
                photo: photos[2],
                allPhotos: allPhotos,
                index: startIndex + 2,
                title: title,
                headers: headers,
              ),
            ),
          ],
        ],
      ),
    );

    return SizedBox(
      height: 268,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: reversed
              ? [stack, const SizedBox(width: 6), bigTile]
              : [bigTile, const SizedBox(width: 6), stack],
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

  const _MosaicTile({
    required this.photo,
    required this.allPhotos,
    required this.index,
    required this.title,
    required this.headers,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => GalleryFullscreenViewer(
              photos: allPhotos,
              initialIndex: index,
              title: title,
            ),
          ),
        );
      },
      child: Hero(
        tag: 'photo-${photo.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              NetworkImageWithLoader(
                imageUrl: photo.thumbnailUrl,
                title: photo.title ?? title,
                headers: headers,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withAlpha(35)],
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

class GalleryFullscreenViewer extends StatefulWidget {
  final List<GalleryPhoto> photos;
  final int initialIndex;
  final String title;

  const GalleryFullscreenViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.title,
  });

  @override
  State<GalleryFullscreenViewer> createState() =>
      _GalleryFullscreenViewerState();
}

class _GalleryFullscreenViewerState extends State<GalleryFullscreenViewer> {
  late final PageController _pageController;
  late final ScrollController _thumbnailScrollController;
  late int _index;
  final GalleryController _controller = Get.find<GalleryController>();
  final Map<int, Future<GalleryPhotoAttributes>> _attributesCache = {};
  final Map<int, Future<String>> _imageSizeCache = {};
  final Map<int, Future<String>> _storageSizeCache = {};
  bool _showFavoriteBurst = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _thumbnailScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheAround(_index);
      _centerThumbnail(_index, animated: false);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  GalleryPhoto get _photo => widget.photos[_index];

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

      final completer = Completer<String>();
      final provider = CachedNetworkImageProvider(
        photo.fullUrl,
        headers: _controller.imageHeaders,
      );
      late final ImageStreamListener listener;
      final stream = provider.resolve(createLocalImageConfiguration(context));
      listener = ImageStreamListener(
        (image, _) {
          stream.removeListener(listener);
          completer.complete(
            _formatPhotoDimensions(image.image.width, image.image.height) ??
                'Not available',
          );
        },
        onError: (error, stackTrace) {
          stream.removeListener(listener);
          completer.complete('Not available');
        },
      );
      stream.addListener(listener);
      return completer.future;
    });
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
      if (index < 0 || index >= widget.photos.length) continue;
      final photo = widget.photos[index];
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
    await SharePlus.instance.share(ShareParams(uri: Uri.tryParse(url)));
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

  void _favoriteCurrentPhoto() {
    if (!AuthRedirectHelper.ensureLoggedIn()) return;
    if (!_controller.isFavorite(_photo.id)) {
      _controller.toggleFavorite(_photo);
    }
    _playFavoriteBurst();
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
      builder: (context) => _TextEntryBottomSheet(
        title: title,
        hint: hint,
        action: action,
        suggestions: suggestions,
        selectedValues: selectedValues,
      ),
    );
    return value?.trim().isEmpty == true ? null : value?.trim();
  }

  void _openInfoSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoInfoBottomSheet(
        photo: _photo,
        attributesFuture: _attributesFor(_photo.id),
        imageSizeFuture: _imageSizeFor(_photo),
        storageSizeFuture: _storageSizeFor(_photo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            allowImplicitScrolling: true,
            onPageChanged: (value) {
              setState(() => _index = value);
              _precacheAround(value);
              _centerThumbnail(value);
            },
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _favoriteCurrentPhoto,
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) < -240) {
                    _openInfoSheet();
                  }
                },
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Hero(
                      tag: 'photo-${photo.id}',
                      child: _FullscreenImage(
                        photo: photo,
                        title: widget.title,
                        headers: _controller.imageHeaders,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: _ViewerTopBar(
                title: widget.title,
                position: '${_index + 1} of ${widget.photos.length}',
                onBack: () => Navigator.pop(context),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ViewerThumbStrip(
                  photos: widget.photos,
                  selectedIndex: _index,
                  controller: _thumbnailScrollController,
                  headers: _controller.imageHeaders,
                  onTap: (index) {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
                const SizedBox(height: 13),
                _ViewerActions(
                  isFavorite: _controller.isFavorite(_photo.id),
                  onShare: _sharePhoto,
                  onFavorite: _toggleFavorite,
                  onInfo: _openInfoSheet,
                  onOptions: _showMoreOptions,
                  onCollection: _openAddCollectionSheet,
                ),
              ],
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
                          onTap: _openCreateSheet,
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

  Future<void> _openCreateSheet() async {
    final isCollection = widget.title.toLowerCase().contains('collection');
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateValueBottomSheet(
        title: isCollection ? 'New Collection' : 'New Tag',
        hint: widget.hint,
        action: isCollection ? 'Add Collection' : 'Add Tag',
        existingValues: [...widget.suggestions, ...widget.selectedValues],
      ),
    );
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return;
    if (!mounted) return;
    Navigator.pop(context, clean);
  }
}

class _CreateValueBottomSheet extends StatefulWidget {
  final String title;
  final String hint;
  final String action;
  final List<String> existingValues;

  const _CreateValueBottomSheet({
    required this.title,
    required this.hint,
    required this.action,
    required this.existingValues,
  });

  @override
  State<_CreateValueBottomSheet> createState() =>
      _CreateValueBottomSheetState();
}

class _CreateValueBottomSheetState extends State<_CreateValueBottomSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(() {
      if (_error != null) setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Please enter a name');
      _focusNode.requestFocus();
      return;
    }
    final exists = widget.existingValues.any(
      (item) => item.toLowerCase() == value.toLowerCase(),
    );
    if (exists) {
      setState(() => _error = 'This already exists');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6F3).withAlpha(248),
              border: Border(
                top: BorderSide(color: primaryColor.withAlpha(18)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
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
                  const SizedBox(height: 18),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      errorText: _error,
                      filled: true,
                      fillColor: Colors.white.withAlpha(235),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(widget.action),
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

  const _FullscreenImage({
    required this.photo,
    required this.title,
    required this.headers,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 96, 0, 132),
      child: Center(
        child: SizedBox(
          width: double.infinity,
          child: CachedNetworkImage(
            imageUrl: photo.fullUrl,
            httpHeaders: headers,
            fit: BoxFit.fitWidth,
            alignment: Alignment.center,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (context, url) => CachedNetworkImage(
              imageUrl: photo.thumbnailUrl,
              httpHeaders: headers,
              fit: BoxFit.fitWidth,
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
      ),
    );
  }
}

class _ViewerTopBar extends StatelessWidget {
  final String title;
  final String position;
  final VoidCallback onBack;

  const _ViewerTopBar({
    required this.title,
    required this.position,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ViewerCircleButton(icon: CupertinoIcons.chevron_left, onTap: onBack),
        const Spacer(),
        Container(
          constraints: const BoxConstraints(minWidth: 112),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(235),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
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
                position,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.black.withAlpha(155),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        const SizedBox(width: 44),
      ],
    );
  }
}

class _ViewerThumbStrip extends StatelessWidget {
  final List<GalleryPhoto> photos;
  final int selectedIndex;
  final ScrollController controller;
  final Map<String, String>? headers;
  final ValueChanged<int> onTap;

  const _ViewerThumbStrip({
    required this.photos,
    required this.selectedIndex,
    required this.controller,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isSelected ? 34 : 24,
              height: isSelected ? 34 : 29,
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
  final VoidCallback onShare;
  final VoidCallback onFavorite;
  final VoidCallback onInfo;
  final VoidCallback onOptions;
  final VoidCallback onCollection;

  const _ViewerActions({
    required this.isFavorite,
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
                _ViewerPlainButton(
                  icon: CupertinoIcons.info_circle,
                  onTap: onInfo,
                ),
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

class _PhotoInfoBottomSheet extends StatelessWidget {
  final GalleryPhoto photo;
  final Future<GalleryPhotoAttributes> attributesFuture;
  final Future<String> imageSizeFuture;
  final Future<String> storageSizeFuture;
  final GalleryController _controller = Get.find<GalleryController>();

  _PhotoInfoBottomSheet({
    required this.photo,
    required this.attributesFuture,
    required this.imageSizeFuture,
    required this.storageSizeFuture,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.34,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              color: Colors.white.withAlpha(238),
              child: FutureBuilder<GalleryPhotoAttributes>(
                future: attributesFuture,
                builder: (context, snapshot) {
                  final attrs = snapshot.data;
                  final entries = attrs?.entries ?? const [];
                  return ListView(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Photo Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _InfoRow(
                        icon: CupertinoIcons.calendar,
                        label: 'Image Date',
                        value: _formatDate(photo.takenAt) ?? 'Not available',
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<String>(
                        future: imageSizeFuture,
                        builder: (context, snapshot) {
                          return _InfoRow(
                            icon: CupertinoIcons.photo,
                            label: 'Image Size',
                            value: snapshot.data ?? 'Loading...',
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<String>(
                        future: storageSizeFuture,
                        builder: (context, snapshot) {
                          return _InfoRow(
                            icon: CupertinoIcons.archivebox,
                            label: 'Storage Size',
                            value: snapshot.data ?? 'Loading...',
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Image Tags',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Obx(() {
                        final userTags = _controller.tagsForPhoto(photo.id);
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
                                  deleteIcon: const Icon(
                                    CupertinoIcons.xmark_circle_fill,
                                    size: 18,
                                  ),
                                  onDeleted: () {
                                    _controller.removeTagFromPhoto(
                                      photo.id,
                                      tag,
                                    );
                                  },
                                  backgroundColor: primaryColor.withAlpha(24),
                                  labelStyle: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  side: BorderSide(
                                    color: primaryColor.withAlpha(45),
                                  ),
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
                        const SizedBox(height: 18),
                        const Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _InfoMapCard(attrs: attrs!, photo: photo),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
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
    return Container(
      height: 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFFEAF2EC),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _SoftMapPainter()),
          Positioned(
            right: 20,
            top: 18,
            child: Icon(CupertinoIcons.location_solid, color: primaryColor),
          ),
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
            left: 16,
            right: 16,
            bottom: 14,
            child: Text(
              attrs.placeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1EE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.black.withAlpha(120),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
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
