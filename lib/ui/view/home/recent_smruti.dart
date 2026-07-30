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

class _AutoSwapRecentCollagesState extends State<_AutoSwapRecentCollages> {
  static const _swapInterval = Duration(seconds: 3);
  static const _animationDuration = Duration(milliseconds: 650);

  Timer? _timer;
  int _frontGroup = 0;

  int get _groupCount => (widget.photos.length / 4).ceil();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _AutoSwapRecentCollages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_frontGroup >= _groupCount) _frontGroup = 0;
    if (oldWidget.photos.length != widget.photos.length ||
        oldWidget.autoplay != widget.autoplay) {
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
    if (!widget.autoplay || _groupCount <= 1) return;
    _timer = Timer.periodic(_swapInterval, (_) => _move(1));
  }

  void _move(int direction) {
    if (!mounted || _groupCount <= 1) return;
    setState(() {
      _frontGroup = (_frontGroup + direction + _groupCount) % _groupCount;
    });
  }

  List<GalleryPhoto> _groupAt(int groupIndex) {
    final normalized = groupIndex % _groupCount;
    final start = normalized * 4;
    final end = (start + 4).clamp(0, widget.photos.length);
    return widget.photos.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = _groupCount.clamp(1, 3);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -120) {
          _timer?.cancel();
          _move(1);
        } else if (velocity > 120) {
          _timer?.cancel();
          _move(-1);
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
      key: ValueKey('recent-collage-$groupIndex-$depth'),
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
      child: Padding(
        padding: const EdgeInsets.all(7),
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
    final left = photos.take(2).toList(growable: false);
    final right = photos.skip(2).take(2).toList(growable: false);

    return Row(
      children: [
        Expanded(flex: 6, child: _column(left, reverse: false)),
        if (right.isNotEmpty) const SizedBox(width: 7),
        if (right.isNotEmpty)
          Expanded(flex: 5, child: _column(right, reverse: true)),
      ],
    );
  }

  Widget _column(List<GalleryPhoto> columnPhotos, {required bool reverse}) {
    if (columnPhotos.length == 1) return _tile(columnPhotos.first);

    return Column(
      children: [
        Expanded(flex: reverse ? 4 : 5, child: _tile(columnPhotos.first)),
        const SizedBox(height: 7),
        Expanded(flex: reverse ? 5 : 4, child: _tile(columnPhotos.last)),
      ],
    );
  }

  Widget _tile(GalleryPhoto photo) {
    return Material(
      color: const Color(0xFFF4F1EC),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(photo),
        child: NetworkImageWithLoader(
          imageUrl: photo.thumbnailUrl,
          title: photo.title ?? 'Recent Smruti',
          headers: headers,
          fit: BoxFit.contain,
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
    return Container(
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
      child: child,
    );
  }
}
