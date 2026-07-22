import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_location_screen.dart';
import 'package:harismruti/ui/view/home/my_diary_smruti.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const double _homeAppbarBlurSigma = 24;
const int _homeAppbarGlassAlpha = 125;

class GalleryDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? coverUrl;
  final Future<List<GalleryPhoto>> Function() loader;
  final Future<List<GalleryPhoto>> Function(int page)? loadMore;
  final bool showRecentPhotoMetadata;

  const GalleryDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loader,
    this.loadMore,
    this.coverUrl,
    this.showRecentPhotoMetadata = false,
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
      loadMore: (page) => controller.loadPhotosForFilter(
        slug: slug,
        value: value,
        page: page,
      ),
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

  bool _initialLoading = true;
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
      final photos = await widget.loader();
      debugPrint(
        'GalleryDetailScreen[${widget.title}]: initial load returned=${photos.length}',
      );
      if (!mounted) return;
      setState(() {
        _photos
          ..clear()
          ..addAll(_dedupe(photos, existing: const []));
        _page = 1;
        _hasMore = widget.loadMore != null && photos.length >= _perPage;
        _initialLoading = false;
        _failed = false;
      });
    } catch (e) {
      debugPrint('GalleryDetailScreen[${widget.title}]: initial load failed, $e');
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
      final newPhotos = _dedupe(photos, existing: _photos);
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
      return photo.thumbnailUrl.isNotEmpty && existingUrls.add(photo.thumbnailUrl);
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
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _MusicStyleHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            coverUrl: cover,
            headers: _galleryController.imageHeaders,
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
  final bool showRecentPhotoMetadata;

  const _MosaicPhotoSliver({
    required this.photos,
    required this.title,
    required this.headers,
    required this.showRecentPhotoMetadata,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _MosaicTile(
            photo: photos[index],
            allPhotos: photos,
            index: index,
            title: title,
            headers: headers,
            showRecentPhotoMetadata: showRecentPhotoMetadata,
          ),
          childCount: photos.length,
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

  const _MosaicTile({
    required this.photo,
    required this.allPhotos,
    required this.index,
    required this.title,
    required this.headers,
    required this.showRecentPhotoMetadata,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GalleryController>();
    return GestureDetector(
      onTap: () {
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
      child: Hero(
        tag: 'photo-${photo.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: const Color(0xFFF2E9E4),
                child: NetworkImageWithLoader(
                  imageUrl: photo.thumbnailUrl,
                  title: photo.title ?? title,
                  headers: headers,
                  fit: BoxFit.contain,
                ),
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
  final Map<int, Future<GalleryPhotoAttributes>> _attributesCache = {};
  final Map<int, Future<String>> _imageSizeCache = {};
  final Map<int, Future<String>> _storageSizeCache = {};
  bool _showFavoriteBurst = false;
  bool _chromeVisible = true;
  bool _isZoomed = false;
  bool _zoomModeActive = false;
  Offset _lastDoubleTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
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
      widget.isRecentFeed ? _controller.recentPhotos : widget.photos;

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

  void _rememberDoubleTapPosition(TapDownDetails details) {
    _lastDoubleTapPosition = details.localPosition;
  }

  void _handleZoomInteractionStart(ScaleStartDetails details) {
    _zoomAnimationController.stop();
    _clearZoomAnimation();

    if (details.pointerCount < 2 && !_isZoomed) return;
    if (_zoomModeActive && !_chromeVisible) return;

    setState(() {
      _zoomModeActive = true;
      _chromeVisible = false;
    });
  }

  void _handleZoomInteractionUpdate(ScaleUpdateDetails details) {
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

  void _resetZoom({bool animated = true}) {
    if (animated) {
      _animateZoomTo(Matrix4.identity(), isZoomed: false);
    } else {
      _zoomAnimationController.stop();
      _transformationController.value = Matrix4.identity();
      _isZoomed = false;
      _zoomModeActive = false;
      _chromeVisible = true;
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
                _resetZoom(animated: false);
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
                onVerticalDragEnd: _zoomModeActive
                    ? null
                    : (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity > 360) {
                          Navigator.pop(context);
                        }
                      },
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
                      child: _FullscreenImage(
                        photo: photo,
                        title: widget.title,
                        headers: _controller.imageHeaders,
                        chromeVisible: _chromeVisible,
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
                        takenAt: _photo.takenAt,
                        attributesFuture: _attributesFor(_photo.id),
                        onBack: () => Navigator.pop(context),
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
                      _reactive(
                        () => _ViewerThumbStrip(
                          photos: _photosList,
                          selectedIndex: _index,
                          isLoadingMore: widget.isRecentFeed &&
                              _controller.isRecentPageLoading.value,
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
    return AnimatedPadding(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        0,
        chromeVisible ? 96 : 0,
        0,
        chromeVisible ? 132 : 0,
      ),
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
  final DateTime? takenAt;
  final Future<GalleryPhotoAttributes>? attributesFuture;
  final VoidCallback onBack;

  const _ViewerTopBar({
    required this.title,
    required this.position,
    this.takenAt,
    this.attributesFuture,
    required this.onBack,
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
        const SizedBox(width: 54),
      ],
    );
  }

  String? _formatTopDateTime(DateTime? value) {
    if (value == null) return null;
    final date = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final photoDay = DateTime(date.year, date.month, date.day);
    final daysAgo = today.difference(photoDay).inDays;
    final dayLabel = switch (daysAgo) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => _formatShortDate(date),
    };
    // Photos without a real capture time fall back to a date-only value
    // (midnight), so showing a fabricated "12:00 AM" would be misleading.
    final hasKnownTime = date.hour != 0 || date.minute != 0;
    if (!hasKnownTime) return dayLabel;
    return '$dayLabel  ${_formatTime(date)}';
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

  String _formatTime(DateTime date) {
    final hour = date.hour == 0 || date.hour == 12 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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
    return SizedBox(
      height: 34,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          if (index >= photos.length) {
            return const SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
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
                                      _controller
                                          .tagsForPhoto(photo.id)
                                          .contains(tag)
                                      ? const Icon(
                                          CupertinoIcons.xmark_circle_fill,
                                          size: 18,
                                        )
                                      : null,
                                  onDeleted:
                                      _controller
                                          .tagsForPhoto(photo.id)
                                          .contains(tag)
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

    return GestureDetector(
      onTap: () => _openLocationMap(context),
      child: Container(
        height: 166,
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
                        width: 86,
                        height: 86,
                        child: Center(
                          child: Icon(
                            CupertinoIcons.location_solid,
                            color: primaryColor,
                            size: 46,
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
      width: photo.width,
      height: photo.height,
      fileSizeBytes: photo.fileSizeBytes,
      fileSizeLabel: photo.fileSizeLabel,
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
