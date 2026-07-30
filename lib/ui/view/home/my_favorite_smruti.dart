import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class MyFavoriteSmruti extends StatelessWidget {
  const MyFavoriteSmruti({super.key});

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();

    return Obx(() {
      final photos = galleryController.orderedSectionPhotos(
        'my_favorite',
        galleryController.favoritePhotos,
      );
      final scale = tabletScale(context);
      if (!StorageHelper.isLogin()) {
        return GestureDetector(
          onTap: AuthRedirectHelper.ensureLoggedIn,
          child: GalleryEmptyState(
            height: 190 * scale,
            message: 'Login to see your favorite photos',
          ),
        );
      }
      if (photos.isEmpty) {
        return GalleryEmptyState(
          height: 190 * scale,
          message: 'Favorite photos will show here',
        );
      }

      return SizedBox(
        height: 230 * scale,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          itemCount: photos.length,
          itemBuilder: (context, index) => _FavoritePhotoCard(
            photo: photos[index],
            photos: photos,
            index: index,
            headers: galleryController.imageHeaders,
          ),
        ),
      );
    });
  }
}

class _FavoritePhotoCard extends StatelessWidget {
  final GalleryPhoto photo;
  final List<GalleryPhoto> photos;
  final int index;
  final Map<String, String>? headers;

  const _FavoritePhotoCard({
    required this.photo,
    required this.photos,
    required this.index,
    required this.headers,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            settings: const RouteSettings(name: 'Favorite Photo Viewer'),
            builder: (_) => GalleryFullscreenViewer(
              photos: photos,
              initialIndex: index,
              title: 'My Favorite',
            ),
          ),
        );
      },
      child: Container(
        width: 168 * tabletScale(context),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetworkImageWithLoader(
              imageUrl: photo.thumbnailUrl,
              title: photo.title ?? 'My Favorite',
              headers: headers,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(18),
                    Colors.black.withAlpha(125),
                  ],
                  stops: const [0.45, 0.72, 1],
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                height: 30 * tabletScale(context),
                width: 30 * tabletScale(context),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(230),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.heart_fill,
                  color: Colors.redAccent,
                  size: 16 * tabletScale(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
