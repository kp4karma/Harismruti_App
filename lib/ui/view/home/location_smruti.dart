import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/widget/gallery/gallery_card_widgets.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';

class LocationSmruti extends StatelessWidget {
  const LocationSmruti({super.key});

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();

    return Obx(() {
      final locations = galleryController.locations;
      if (galleryController.isLoading.value && locations.isEmpty) {
        return const GallerySectionLoader(height: 250);
      }
      if (locations.isEmpty) {
        return const GalleryEmptyState(height: 180);
      }

      return SizedBox(
        height: 250,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: locations.length,
          itemBuilder: (context, index) => GalleryCoverCard(
            card: locations[index],
            headers: galleryController.imageHeaders,
            width: 180,
            height: 230,
          ),
        ),
      );
    });
  }
}
