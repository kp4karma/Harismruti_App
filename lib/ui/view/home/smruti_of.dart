import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/widget/gallery/gallery_card_widgets.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';

class SmrutiOf extends StatelessWidget {
  const SmrutiOf({super.key});

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();
    return Obx(() {
      final cards = galleryController.smrutiOf;
      if (galleryController.isLoading.value && cards.isEmpty) {
        return const GallerySectionLoader(height: 230);
      }
      if (cards.isEmpty) {
        return const GalleryEmptyState(height: 180);
      }
      return SizedBox(
        height: 235,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: cards.length,
          itemBuilder: (context, index) => GalleryCoverCard(
            card: cards[index],
            headers: galleryController.imageHeaders,
            width: 165,
            height: 220,
          ),
        ),
      );
    });
  }
}
