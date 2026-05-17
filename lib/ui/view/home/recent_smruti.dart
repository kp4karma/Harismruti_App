import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class RecentSmruti extends StatelessWidget {
  final bool autoplay;
  const RecentSmruti({super.key, this.autoplay = true});

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();

    return Obx(() {
      final photos = galleryController.recentPhotos;
      if (galleryController.isLoading.value && photos.isEmpty) {
        return GallerySectionLoader(height: 300.h);
      }
      if (photos.isEmpty) {
        return GalleryEmptyState(height: 220.h);
      }

      return SizedBox(
        height: 320.h,
        child: _AutoSwapRecentStack(
          photos: photos.toList(),
          headers: galleryController.imageHeaders,
          autoplay: autoplay,
        ),
      );
    });
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
    if (!widget.autoplay || widget.photos.length <= 1) return;
    _timer = Timer.periodic(_swapInterval, (_) => _showNext());
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

  void _openDetail(BuildContext context, GalleryPhoto photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryDetailScreen(
          title: 'Recent Smruti',
          subtitle: '${widget.photos.length} Photos',
          coverUrl: photo.thumbnailUrl,
          loader: () async => widget.photos,
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
          _showNext();
        } else if (velocity > 120) {
          _showPrevious();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var depth = visibleCount - 1; depth >= 0; depth--)
              _RecentStackPosition(
                depth: depth,
                duration: _swapDuration,
                child: _RecentPhotoCard(
                  key: ValueKey(
                    'recent-${widget.photos[(_frontIndex + depth) % widget.photos.length].id}-$depth',
                  ),
                  photo: widget
                      .photos[(_frontIndex + depth) % widget.photos.length],
                  headers: widget.headers,
                  onTap: depth == 0
                      ? () => _openDetail(context, widget.photos[_frontIndex])
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentStackPosition extends StatelessWidget {
  final int depth;
  final Duration duration;
  final Widget child;

  const _RecentStackPosition({
    required this.depth,
    required this.duration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final layout = switch (depth) {
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
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: Offset(depth == 0 ? 0.10 : 0.03, 0.03),
                end: Offset.zero,
              ).animate(animation);

              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: slide,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: depth == 0 ? 0.96 : 0.98,
                      end: 1,
                    ).animate(animation),
                    child: child,
                  ),
                ),
              );
            },
            child: child,
          ),
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
}

class _RecentPhotoCard extends StatelessWidget {
  final GalleryPhoto photo;
  final Map<String, String>? headers;
  final VoidCallback? onTap;

  const _RecentPhotoCard({
    super.key,
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
