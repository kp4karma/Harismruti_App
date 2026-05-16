import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
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
        height: 310.h,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
          itemCount: photos.length,
          itemBuilder: (context, index) => _RecentPhotoCard(
            photo: photos[index],
            allPhotos: photos.toList(),
            headers: galleryController.imageHeaders,
            width: index == 0 ? 260.h : 210.h,
          ),
        ),
      );
    });
  }
}

class _RecentPhotoCard extends StatelessWidget {
  final GalleryPhoto photo;
  final List<GalleryPhoto> allPhotos;
  final Map<String, String>? headers;
  final double width;

  const _RecentPhotoCard({
    required this.photo,
    required this.allPhotos,
    required this.headers,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final title = photo.title ?? 'Recent Smruti';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GalleryDetailScreen(
              title: 'Recent Smruti',
              subtitle: '${allPhotos.length} Photos',
              coverUrl: photo.thumbnailUrl,
              loader: () async => allPhotos,
            ),
          ),
        );
      },
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
            NetworkImageWithLoader(
              imageUrl: photo.thumbnailUrl,
              title: title,
              headers: headers,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(20),
                    Colors.black.withAlpha(125),
                  ],
                  stops: const [0.45, 0.72, 1],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                children: [
                  Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(230),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: primaryColor,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
