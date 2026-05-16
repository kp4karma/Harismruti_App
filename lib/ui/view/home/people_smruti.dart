import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/widget/gallery/gallery_card_widgets.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';

class PeopleSmruti extends StatelessWidget {
  const PeopleSmruti({super.key});

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();
    return Obx(() {
      final people = galleryController.people;
      if (galleryController.isLoading.value && people.isEmpty) {
        return const GallerySectionLoader(height: 300);
      }
      if (people.isEmpty) {
        return const GalleryEmptyState(height: 180);
      }

      return SizedBox(
        height: 205,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
          itemCount: people.length,
          itemBuilder: (context, index) => SizedBox(
            width: 155,
            child: GalleryGridCard(
              card: people[index],
              headers: galleryController.imageHeaders,
              aspectRatio: 0.86,
            ),
          ),
        ),
      );
    });
  }
}
