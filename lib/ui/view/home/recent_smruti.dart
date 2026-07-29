import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class RecentSmruti extends StatelessWidget {
  final bool autoplay;
  const RecentSmruti({super.key, this.autoplay = true});

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();

    return Obx(() {
      final photos = _uniquePhotos(galleryController.recentPhotos);
      final scale = tabletScale(context);
      if (galleryController.isLoading.value && photos.isEmpty) {
        return GallerySectionLoader(height: 300 * scale);
      }
      if (photos.isEmpty) {
        return GalleryEmptyState(height: 220 * scale);
      }

      return SizedBox(
        height: 320 * scale,
        child: _AutoSwapRecentStack(
          photos: photos,
          headers: galleryController.imageHeaders,
          autoplay: autoplay,
        ),
      );
    });
  }

  List<GalleryPhoto> _uniquePhotos(Iterable<GalleryPhoto> photos) {
    final seen = <String>{};
    final uniquePhotos = <GalleryPhoto>[];

    for (final photo in photos) {
      final key = photo.id > 0 ? 'id:${photo.id}' : photo.thumbnailUrl;
      if (key.isEmpty || !seen.add(key)) continue;
      uniquePhotos.add(photo);
    }

    return uniquePhotos;
  }
}

class _AutoSwapRecentStack extends StatefulWidget {
  final List<GalleryPhoto> photos;
  final Map<String, String>? headers;
  final bool autoplay;

  const _AutoSwapRecentStack({
    required this.photos,
    required this.headers,
    required this.autoplay,
  });

  @override
  State<_AutoSwapRecentStack> createState() => _AutoSwapRecentStackState();
}

class _AutoSwapRecentStackState extends State<_AutoSwapRecentStack> {
  static const _swapDuration = Duration(milliseconds: 650);
  static const _swapInterval = Duration(seconds: 3);

  Timer? _timer;
  int _frontIndex = 0;
  int _automaticSwapsInDirection = 0;
  bool _automaticSwappingForward = true;
  bool _autoplayStoppedByUser = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _AutoSwapRecentStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_frontIndex >= widget.photos.length) {
      _frontIndex = 0;
    }
    if (oldWidget.autoplay != widget.autoplay ||
        oldWidget.photos.length != widget.photos.length) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_autoplayStoppedByUser ||
        !widget.autoplay ||
        widget.photos.length <= 1) {
      return;
    }
    _timer = Timer.periodic(_swapInterval, (_) => _showAutomaticNext());
  }

  void _showAutomaticNext() {
    if (!mounted || widget.photos.length <= 1) return;

    setState(() {
      if (_automaticSwappingForward) {
        _frontIndex = (_frontIndex + 1) % widget.photos.length;
      } else {
        _frontIndex =
            (_frontIndex - 1 + widget.photos.length) % widget.photos.length;
      }

      _automaticSwapsInDirection++;
      if (_automaticSwapsInDirection == 3) {
        _automaticSwapsInDirection = 0;
        _automaticSwappingForward = !_automaticSwappingForward;
      }
    });
  }

  void _stopAutoplayForUser() {
    if (_autoplayStoppedByUser) return;
    _autoplayStoppedByUser = true;
    _timer?.cancel();
    _timer = null;
  }

  void _showNext() {
    if (!mounted || widget.photos.length <= 1) return;
    setState(() {
      _frontIndex = (_frontIndex + 1) % widget.photos.length;
    });
  }

  void _showPrevious() {
    if (!mounted || widget.photos.length <= 1) return;
    setState(() {
      _frontIndex =
          (_frontIndex - 1 + widget.photos.length) % widget.photos.length;
    });
  }

  void _openDetail(BuildContext context) {
    final galleryController = Get.find<GalleryController>();
    final tappedPhoto = widget.photos[_frontIndex];
    final rawIndex = galleryController.recentPhotos.indexWhere(
      (photo) => tappedPhoto.id > 0
          ? photo.id == tappedPhoto.id
          : photo.thumbnailUrl == tappedPhoto.thumbnailUrl,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Photo Viewer'),
        builder: (_) => GalleryFullscreenViewer(
          photos: galleryController.recentPhotos.toList(growable: false),
          initialIndex: rawIndex >= 0 ? rawIndex : 0,
          title: 'Recent Smruti',
          isRecentFeed: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = widget.photos.length.clamp(1, 4);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -120) {
          _stopAutoplayForUser();
          _showNext();
        } else if (velocity > 120) {
          _stopAutoplayForUser();
          _showPrevious();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var depth = visibleCount - 1; depth >= 0; depth--)
                  _buildPositionedCard(context, depth, constraints.maxWidth),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPositionedCard(
    BuildContext context,
    int depth,
    double availableWidth,
  ) {
    final photo = widget.photos[(_frontIndex + depth) % widget.photos.length];

    return _RecentStackPosition(
      key: ValueKey(_photoKey(photo)),
      depth: depth,
      duration: _swapDuration,
      availableWidth: availableWidth,
      child: _RecentPhotoCard(
        photo: photo,
        headers: widget.headers,
        onTap: depth == 0 ? () => _openDetail(context) : null,
      ),
    );
  }

  String _photoKey(GalleryPhoto photo) {
    if (photo.id > 0) return 'recent-${photo.id}';
    return 'recent-${photo.thumbnailUrl}';
  }
}

class _RecentStackPosition extends StatelessWidget {
  // The pixel insets below were tuned against this available-width baseline
  // (padded phone viewport); scaling by availableWidth/_referenceWidth keeps
  // the overlap proportions consistent instead of the gutters staying
  // pixel-fixed while the card barely shrinks on a much wider tablet.
  static const _referenceWidth = 380.0;

  final int depth;
  final Duration duration;
  final double availableWidth;
  final Widget child;

  const _RecentStackPosition({
    super.key,
    required this.depth,
    required this.duration,
    required this.availableWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final baseLayout = switch (depth) {
      0 => const _StackCardLayout(
        left: 46,
        right: 46,
        top: 0,
        bottom: 0,
        rotation: 0,
        opacity: 1,
      ),
      1 => const _StackCardLayout(
        left: 6,
        right: 96,
        top: 38,
        bottom: 22,
        rotation: -0.07,
        opacity: 0.92,
      ),
      2 => const _StackCardLayout(
        left: 96,
        right: 6,
        top: 38,
        bottom: 22,
        rotation: 0.07,
        opacity: 0.92,
      ),
      _ => const _StackCardLayout(
        left: 68,
        right: 68,
        top: 22,
        bottom: 16,
        rotation: 0,
        opacity: 0.82,
      ),
    };

    final ratio = availableWidth > 0 ? availableWidth / _referenceWidth : 1.0;
    final layout = baseLayout.scaled(ratio);

    return AnimatedPositioned(
      duration: duration,
      curve: Curves.easeOutCubic,
      left: layout.left,
      right: layout.right,
      top: layout.top,
      bottom: layout.bottom,
      child: AnimatedRotation(
        duration: duration,
        curve: Curves.easeOutCubic,
        turns: layout.rotation / 6.283185307179586,
        child: AnimatedOpacity(
          duration: duration,
          curve: Curves.easeOutCubic,
          opacity: layout.opacity,
          child: child,
        ),
      ),
    );
  }
}

class _StackCardLayout {
  final double left;
  final double right;
  final double top;
  final double bottom;
  final double rotation;
  final double opacity;

  const _StackCardLayout({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.rotation,
    required this.opacity,
  });

  /// Scales only the positional insets by [ratio] -- rotation/opacity are
  /// visual constants, not tied to available width.
  _StackCardLayout scaled(double ratio) {
    return _StackCardLayout(
      left: left * ratio,
      right: right * ratio,
      top: top * ratio,
      bottom: bottom * ratio,
      rotation: rotation,
      opacity: opacity,
    );
  }
}

class _RecentPhotoCard extends StatelessWidget {
  final GalleryPhoto photo;
  final Map<String, String>? headers;
  final VoidCallback? onTap;

  const _RecentPhotoCard({
    required this.photo,
    required this.headers,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = photo.title ?? 'Recent Smruti';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(32),
              blurRadius: 24,
              offset: const Offset(0, 12),
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
          ],
        ),
      ),
    );
  }
}
