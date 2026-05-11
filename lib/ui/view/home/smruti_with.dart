import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/widget/gallery/gallery_card_widgets.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';

class SmrutiWith extends StatelessWidget {
  const SmrutiWith({super.key});

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();

    return Obx(() {
      final items = galleryController.people
          .where((item) => item.coverUrl.isNotEmpty)
          .take(8)
          .toList();
      if (galleryController.isLoading.value && items.isEmpty) {
        return const GallerySectionLoader(height: 300);
      }
      if (items.isEmpty) {
        return const GalleryEmptyState(height: 180);
      }

      return SizedBox(
        height: 300,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: items.length,
          itemBuilder: (context, index) => GalleryCoverCard(
            card: items[index],
            headers: galleryController.imageHeaders,
            width: 210,
            height: 285,
          ),
        ),
      );
    });
  }
}
