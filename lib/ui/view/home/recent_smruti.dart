import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class RecentSmruti extends StatelessWidget {
  final bool autoplay;

  const RecentSmruti({super.key, this.autoplay = true});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GalleryController>();

    return Obx(() {
      final photos = _uniquePhotos(controller.recentPhotos);
      final scale = tabletScale(context);
      if (controller.isLoading.value && photos.isEmpty) {
        return GallerySectionLoader(height: 300 * scale);
      }
      if (photos.isEmpty) {
        return GalleryEmptyState(height: 220 * scale);
      }

      return SizedBox(
        height: 320 * scale,
        child: _AutoSwapRecentCollages(
          photos: photos,
          headers: controller.imageHeaders,
          autoplay: autoplay,
        ),
      );
    });
  }

  List<GalleryPhoto> _uniquePhotos(Iterable<GalleryPhoto> photos) {
    final seen = <String>{};
    final unique = <GalleryPhoto>[];
    for (final photo in photos) {
      final key = photo.id > 0 ? 'id:${photo.id}' : photo.thumbnailUrl;
      if (key.isNotEmpty && seen.add(key)) unique.add(photo);
    }
    return unique;
  }
}

class _AutoSwapRecentCollages extends StatefulWidget {
  final List<GalleryPhoto> photos;
  final Map<String, String>? headers;
  final bool autoplay;

  const _AutoSwapRecentCollages({
    required this.photos,
    required this.headers,
    required this.autoplay,
  });

  @override
  State<_AutoSwapRecentCollages> createState() =>
      _AutoSwapRecentCollagesState();
}

class _AutoSwapRecentCollagesState extends State<_AutoSwapRecentCollages>
    with WidgetsBindingObserver {
  static const _swapInterval = Duration(seconds: 6);
  static const _animationDuration = Duration(milliseconds: 650);
  static const _maximumAutomaticSwaps = 5;

  Timer? _timer;
  int _frontGroup = 0;
  bool _didPrecache = false;
  bool _isMoving = false;
  int _automaticSwapCount = 0;

  List<List<GalleryPhoto>> get _groups => [
    for (final photo in widget.photos) [photo],
  ];

  int get _groupCount => _groups.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecache) {
      _didPrecache = true;
      _precachePhotos();
    }
  }

  @override
  void didUpdateWidget(covariant _AutoSwapRecentCollages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_frontGroup >= _groupCount) _frontGroup = 0;
    if (oldWidget.photos.length != widget.photos.length ||
        oldWidget.autoplay != widget.autoplay) {
      _automaticSwapCount = 0;
      _startTimer();
    }
    if (oldWidget.photos != widget.photos ||
        oldWidget.headers != widget.headers) {
      _precachePhotos();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!widget.autoplay ||
        _groupCount <= 1 ||
        _automaticSwapCount >= _maximumAutomaticSwaps) {
      return;
    }
    _timer = Timer.periodic(_swapInterval, (timer) async {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      final moved = await _move(1);
      if (!moved) return;
      _automaticSwapCount++;
      if (_automaticSwapCount >= _maximumAutomaticSwaps) timer.cancel();
    });
  }

  Future<bool> _move(int direction) async {
    if (!mounted || _groupCount <= 1 || _isMoving) return false;
    _isMoving = true;
    final nextFront = (_frontGroup + direction + _groupCount) % _groupCount;
    await _precacheVisibleGroups(nextFront);
    if (!mounted) return false;
    setState(() {
      _frontGroup = nextFront;
    });
    _isMoving = false;
    return true;
  }

  Future<void> _precacheVisibleGroups(int frontGroup) async {
    final visibleCount = _groupCount.clamp(1, 3);
    await Future.wait([
      for (var depth = 0; depth < visibleCount; depth++)
        _precachePhoto(_groups[(frontGroup + depth) % _groupCount].first),
    ]);
  }

  Future<void> _precachePhoto(GalleryPhoto photo) async {
    if (photo.thumbnailUrl.isEmpty) return;
    try {
      await precacheImage(
        CachedNetworkImageProvider(photo.thumbnailUrl, headers: widget.headers),
        context,
      );
    } catch (_) {
      // Let the image widget show its normal error state after the transition.
    }
  }

  void _precachePhotos() {
    for (final photo in widget.photos.take(6)) {
      if (photo.thumbnailUrl.isEmpty) continue;
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(
            photo.thumbnailUrl,
            headers: widget.headers,
          ),
          context,
        ),
      );
    }
  }

  List<GalleryPhoto> _groupAt(int groupIndex) {
    return _groups[groupIndex % _groupCount];
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = _groupCount.clamp(1, 3);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -120) {
          _timer?.cancel();
          unawaited(_move(1).then<void>((_) {}));
        } else if (velocity > 120) {
          _timer?.cancel();
          unawaited(_move(-1).then<void>((_) {}));
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ratio = constraints.maxWidth / 380;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var depth = visibleCount - 1; depth >= 0; depth--)
                  _positionedCollage(depth, ratio),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _positionedCollage(int depth, double ratio) {
    final layout = switch (depth) {
      0 => (46.0, 46.0, 0.0, 0.0, 0.0, 1.0),
      1 => (6.0, 96.0, 38.0, 22.0, -0.07, 0.92),
      _ => (96.0, 6.0, 38.0, 22.0, 0.07, 0.92),
    };
    final groupIndex = (_frontGroup + depth) % _groupCount;

    return AnimatedPositioned(
      // Keep each image widget alive while it moves through the stack. A key
      // tied to depth recreated the image on every swap and briefly showed its
      // loading state again.
      key: ValueKey('recent-collage-$groupIndex'),
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      left: layout.$1 * ratio,
      right: layout.$2 * ratio,
      top: layout.$3 * ratio,
      bottom: layout.$4 * ratio,
      child: AnimatedRotation(
        duration: _animationDuration,
        turns: layout.$5 / 6.283185307179586,
        child: AnimatedOpacity(
          duration: _animationDuration,
          opacity: layout.$6,
          child: _RecentMasonryCard(
            photos: _groupAt(groupIndex),
            headers: widget.headers,
            onTap: depth == 0 ? (photo) => _openDetail(context, photo) : null,
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, GalleryPhoto tappedPhoto) {
    final controller = Get.find<GalleryController>();
    final photos = controller.recentPhotos.toList(growable: false);
    final index = photos.indexWhere(
      (photo) => tappedPhoto.id > 0
          ? photo.id == tappedPhoto.id
          : photo.thumbnailUrl == tappedPhoto.thumbnailUrl,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Photo Viewer'),
        builder: (_) => GalleryFullscreenViewer(
          photos: photos,
          initialIndex: index < 0 ? 0 : index,
          title: 'Recent Smruti',
          isRecentFeed: true,
        ),
      ),
    );
  }
}

class _RecentMasonryCard extends StatelessWidget {
  final List<GalleryPhoto> photos;
  final Map<String, String>? headers;
  final ValueChanged<GalleryPhoto>? onTap;

  const _RecentMasonryCard({
    required this.photos,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _StackSurface(
      child: SizedBox.expand(
        child: _MasonryPage(photos: photos, headers: headers, onTap: onTap),
      ),
    );
  }
}

class _MasonryPage extends StatelessWidget {
  final List<GalleryPhoto> photos;
  final Map<String, String>? headers;
  final ValueChanged<GalleryPhoto>? onTap;

  const _MasonryPage({
    required this.photos,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _tile(context, photos.first);
  }

  Widget _tile(BuildContext context, GalleryPhoto photo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(photo),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/recent_smruti_pattern.jpg',
              fit: BoxFit.cover,
              color: isDark ? const Color(0xFF3A302A) : null,
              colorBlendMode: isDark ? BlendMode.multiply : null,
              filterQuality: FilterQuality.medium,
            ),
            NetworkImageWithLoader(
              imageUrl: photo.thumbnailUrl,
              title: photo.title ?? 'Recent Smruti',
              headers: headers,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}

class _StackSurface extends StatelessWidget {
  final Widget child;

  const _StackSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(22));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 28 : 34),
            blurRadius: isDark ? 26 : 22,
            offset: const Offset(0, 10),
          ),
          if (!isDark)
            BoxShadow(
              color: primaryColor.withAlpha(15),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(34)
                : primaryColor.withAlpha(45),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}
