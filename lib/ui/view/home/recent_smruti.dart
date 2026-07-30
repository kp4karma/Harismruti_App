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
        child: GridView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10 * scale,
            crossAxisSpacing: 10 * scale,
            childAspectRatio: 0.82,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            return _RecentPhotoCard(
              photo: photo,
              headers: galleryController.imageHeaders,
              onTap: () => _openDetail(context, galleryController, photo),
            );
          },
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

  void _openDetail(
    BuildContext context,
    GalleryController galleryController,
    GalleryPhoto tappedPhoto,
  ) {
    final recentPhotos = galleryController.recentPhotos.toList(growable: false);
    final tappedIndex = recentPhotos.indexWhere(
      (photo) => tappedPhoto.id > 0
          ? photo.id == tappedPhoto.id
          : photo.thumbnailUrl == tappedPhoto.thumbnailUrl,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Photo Viewer'),
        builder: (_) => GalleryFullscreenViewer(
          photos: recentPhotos,
          initialIndex: tappedIndex >= 0 ? tappedIndex : 0,
          title: 'Recent Smruti',
          isRecentFeed: true,
        ),
      ),
    );
  }
}

class _RecentPhotoCard extends StatelessWidget {
  final GalleryPhoto photo;
  final Map<String, String>? headers;
  final VoidCallback onTap;

  const _RecentPhotoCard({
    required this.photo,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = photo.title ?? 'Recent Smruti';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shadowColor: Colors.black.withAlpha(48),
      child: InkWell(
        onTap: onTap,
        child: NetworkImageWithLoader(
          imageUrl: photo.thumbnailUrl,
          title: title,
          headers: headers,
        ),
      ),
    );
  }
}
