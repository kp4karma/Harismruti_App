import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/widget/gallery/gallery_card_widgets.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';

class AlbumSmruti extends StatelessWidget {
  const AlbumSmruti({super.key});

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();

    return Obx(() {
      final albums = galleryController.albums;
      if (galleryController.isLoading.value && albums.isEmpty) {
        return const GallerySectionLoader(height: 260);
      }
      if (albums.isEmpty) {
        return const GalleryEmptyState(height: 180);
      }

      return SizedBox(
        height: 255,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
          itemCount: albums.length,
          itemBuilder: (context, index) => GalleryMosaicCard(
            card: albums[index],
            headers: galleryController.imageHeaders,
            width: 230,
          ),
        ),
      );
    });
  }
}
