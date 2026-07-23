import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/widget/gallery/gallery_card_widgets.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';

class SmrutiWith extends StatelessWidget {
  const SmrutiWith({super.key});

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();

    return Obx(() {
      final items = galleryController.smrutiWith
          .where((item) => item.coverUrl.isNotEmpty)
          .take(8)
          .toList();
      if (galleryController.isLoading.value && items.isEmpty) {
        return const GallerySectionLoader(height: 300);
      }
      if (items.isEmpty) {
        return const GalleryEmptyState(height: 180);
      }

      final scale = tabletScale(context);
      return SizedBox(
        height: 255 * scale,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
          itemCount: items.length,
          itemBuilder: (context, index) => GalleryWithFeatureCard(
            card: items[index],
            headers: galleryController.imageHeaders,
            width: (index.isEven ? 300 : 276) * scale,
          ),
        ),
      );
    });
  }
}
