import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/widget/gallery/gallery_card_widgets.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';

class CollectionSmruti extends StatelessWidget {
  const CollectionSmruti({super.key});

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();

    return Obx(() {
      final collections = galleryController.collections;
      if (galleryController.isLoading.value && collections.isEmpty) {
        return const GallerySectionLoader(height: 235);
      }
      if (collections.isEmpty) {
        return const GalleryEmptyState(height: 180);
      }

      return SizedBox(
        height: 235,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: collections.length,
          itemBuilder: (context, index) => GalleryMosaicCard(
            card: collections[index],
            headers: galleryController.imageHeaders,
            width: 210,
          ),
        ),
      );
    });
  }
}
