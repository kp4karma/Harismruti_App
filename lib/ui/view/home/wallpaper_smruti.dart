import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/widget/gallery/gallery_card_widgets.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';

class WallpaperSmruti extends StatelessWidget {
  const WallpaperSmruti({super.key});

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();

    return Obx(() {
      final wallpapers = galleryController.wallpapers
          .where((item) => item.coverUrl.isNotEmpty)
          .toList();

      if (galleryController.isLoading.value && wallpapers.isEmpty) {
        return const GallerySectionLoader(height: 300);
      }
      if (wallpapers.isEmpty) {
        return const GalleryEmptyState(height: 180);
      }

      return SizedBox(
        height: 300,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: wallpapers.length,
          itemBuilder: (context, index) => GalleryCoverCard(
            card: wallpapers[index],
            headers: galleryController.imageHeaders,
            width: 170,
            height: 285,
          ),
        ),
      );
    });
  }
}
