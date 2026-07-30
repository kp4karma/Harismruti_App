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

  List<List<GalleryPhoto>> get _groups => [
    for (var index = 0; index < widget.photos.length; index += 4)
      widget.photos.sublist(index, (index + 4).clamp(0, widget.photos.length)),
  ];

  int get _groupCount => _groups.length;

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
    if (photos.length == 1) return _tile(photos.first);
    if (photos.length == 2) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _tile(photos[0])),
          Expanded(child: _tile(photos[1])),
        ],
      );
    }

    final ordered = [...photos]
      ..sort((a, b) => _aspectRatio(a).compareTo(_aspectRatio(b)));
    final hasPortrait = _aspectRatio(ordered.first) < 0.95;

    if (hasPortrait) {
      final feature = ordered.first;
      final remaining = ordered.skip(1).toList(growable: false);
      return LayoutBuilder(
        builder: (context, constraints) {
          final portraitFraction =
              (_aspectRatio(feature) *
                      constraints.maxHeight /
                      constraints.maxWidth)
                  .clamp(0.42, 0.60);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: constraints.maxWidth * portraitFraction,
                height: constraints.maxHeight,
                child: _tile(feature),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final photo in remaining)
                      Expanded(flex: _heightWeight(photo), child: _tile(photo)),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }

    if (ordered.length == 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: _tile(ordered[0])),
          Expanded(
            flex: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _tile(ordered[1])),
                Expanded(child: _tile(ordered[2])),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _tile(ordered[0])),
              Expanded(child: _tile(ordered[3])),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _tile(ordered[1])),
              Expanded(child: _tile(ordered[2])),
            ],
          ),
        ),
      ],
    );
  }

  double _aspectRatio(GalleryPhoto photo) {
    final width = photo.width;
    final height = photo.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 4 / 3;
    }
    return (width / height).clamp(0.55, 1.8);
  }

  int _heightWeight(GalleryPhoto photo) =>
      (100 / _aspectRatio(photo)).round().clamp(55, 180);

  Widget _tile(GalleryPhoto photo) {
    return SizedBox.expand(
      child: ClipRect(
        child: Material(
          color: const Color(0xFFF4F1EC),
          child: InkWell(
            onTap: onTap == null ? null : () => onTap!(photo),
            child: NetworkImageWithLoader(
              imageUrl: photo.thumbnailUrl,
              title: photo.title ?? 'Recent Smruti',
              headers: headers,
              fit: BoxFit.cover,
            ),
          ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(28),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: ColoredBox(color: Colors.white, child: child),
      ),
    );
  }
}
