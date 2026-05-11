import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

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
        height: 300,
        child: GridView.builder(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(12),
          itemCount: people.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final person = people[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: NetworkImageWithLoader(
                      imageUrl: person.coverUrl,
                      title: person.title,
                      headers: galleryController.imageHeaders,
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          stops: const [0.1, 0.6],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withAlpha(120),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Text(
                      person.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}
