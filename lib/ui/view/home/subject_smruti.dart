import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class SubjectSmruti extends StatelessWidget {
  const SubjectSmruti({super.key});

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();

    return Obx(() {
      final items = galleryController.subjects
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
        height: 248 * scale,
        child: ListView.separated(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) => _SubjectRibbonCard(
            card: items[index],
            headers: galleryController.imageHeaders,
            width: (index.isEven ? 214 : 190) * scale,
          ),
        ),
      );
    });
  }
}

class _SubjectRibbonCard extends StatelessWidget {
  final GalleryCard card;
  final Map<String, String>? headers;
  final double width;

  const _SubjectRibbonCard({
    required this.card,
    required this.headers,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final countText = card.count?.toString() ?? card.subtitle;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GalleryDetailScreen.fromCard(card)),
      ),
      child: SizedBox(
        width: width,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withAlpha(20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              NetworkImageWithLoader(
                imageUrl: card.coverUrl,
                title: card.title,
                headers: headers,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(8),
                      Colors.black.withAlpha(30),
                      Colors.black.withAlpha(170),
                    ],
                    stops: const [0.15, 0.55, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(220),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        countText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
