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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final ratio = constraints.maxWidth / 380;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  if (photos.length > 1)
                    _backCard(
                      photo: photos[1],
                      headers: controller.imageHeaders,
                      left: 6 * ratio,
                      right: 96 * ratio,
                      rotation: -0.07,
                    ),
                  if (photos.length > 2)
                    _backCard(
                      photo: photos[2],
                      headers: controller.imageHeaders,
                      left: 96 * ratio,
                      right: 6 * ratio,
                      rotation: 0.07,
                    ),
                  Positioned(
                    left: 46 * ratio,
                    right: 46 * ratio,
                    top: 0,
                    bottom: 0,
                    child: _RecentMasonryCard(
                      photos: photos,
                      headers: controller.imageHeaders,
                      onTap: (photo) => _openDetail(context, controller, photo),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    });
  }

  Widget _backCard({
    required GalleryPhoto photo,
    required Map<String, String>? headers,
    required double left,
    required double right,
    required double rotation,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: 38,
      bottom: 22,
      child: Transform.rotate(
        angle: rotation,
        child: _StackSurface(
          child: NetworkImageWithLoader(
            imageUrl: photo.thumbnailUrl,
            title: photo.title ?? 'Recent Smruti',
            headers: headers,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
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

  void _openDetail(
    BuildContext context,
    GalleryController controller,
    GalleryPhoto tappedPhoto,
  ) {
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
  final ValueChanged<GalleryPhoto> onTap;

  const _RecentMasonryCard({
    required this.photos,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pageCount = (photos.length / 4).ceil();

    return _StackSurface(
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: PageView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: pageCount,
          itemBuilder: (context, pageIndex) {
            final start = pageIndex * 4;
            final end = (start + 4).clamp(0, photos.length);
            return _MasonryPage(
              photos: photos.sublist(start, end),
              headers: headers,
              onTap: onTap,
            );
          },
        ),
      ),
    );
  }
}

class _MasonryPage extends StatelessWidget {
  final List<GalleryPhoto> photos;
  final Map<String, String>? headers;
  final ValueChanged<GalleryPhoto> onTap;

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
        onTap: () => onTap(photo),
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
