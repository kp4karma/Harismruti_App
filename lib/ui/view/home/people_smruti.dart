import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
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
        height: 250 * tabletScale(context),
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          itemCount: people.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _PersonWiseCard(
              card: people[index],
              headers: galleryController.imageHeaders,
            ),
          ),
        ),
      );
    });
  }
}

class _PersonWiseCard extends StatelessWidget {
  final GalleryCard card;
  final Map<String, String>? headers;

  const _PersonWiseCard({required this.card, required this.headers});

  @override
  Widget build(BuildContext context) {
    final subtitle = card.subtitle.isNotEmpty ? card.subtitle : 'Smruti';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'Gallery Detail'),
          builder: (_) => GalleryDetailScreen.fromCard(card),
        ),
      ),
      child: SizedBox(
        width: 210 * tabletScale(context),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(54),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withAlpha(36),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(52),
                  ),
                  child: card.coverUrl.isEmpty
                      ? ColoredBox(
                          color: secondaryColor.withAlpha(34),
                          child: Center(
                            child: Icon(
                              Icons.person,
                              color: Colors.white.withAlpha(235),
                              size: 42,
                            ),
                          ),
                        )
                      : NetworkImageWithLoader(
                          imageUrl: card.coverUrl,
                          title: card.title,
                          headers: headers,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withAlpha(225),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
