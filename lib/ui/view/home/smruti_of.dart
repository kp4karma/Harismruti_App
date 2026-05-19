import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

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
        height: 225,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
          itemCount: cards.length,
          itemBuilder: (context, index) => _SmrutiOfGlowCard(
            card: cards[index],
            headers: galleryController.imageHeaders,
            width: 165,
            height: 205,
          ),
        ),
      );
    });
  }
}

class _SmrutiOfGlowCard extends StatelessWidget {
  final GalleryCard card;
  final Map<String, String>? headers;
  final double width;
  final double height;

  const _SmrutiOfGlowCard({
    required this.card,
    required this.headers,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GalleryDetailScreen.fromCard(card)),
      ),
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: _ImageGlow(card: card, headers: headers),
            ),
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withAlpha(52),
                      Colors.black.withAlpha(18),
                      Colors.black.withAlpha(72),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withAlpha(82)),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: card.coverUrl.isEmpty
                            ? ColoredBox(
                                color: primaryColor.withAlpha(28),
                                child: Center(
                                  child: Icon(
                                    CupertinoIcons.photo,
                                    color: primaryColor,
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
                    const SizedBox(height: 9),
                    Text(
                      card.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      card.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withAlpha(205),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageGlow extends StatelessWidget {
  final GalleryCard card;
  final Map<String, String>? headers;

  const _ImageGlow({required this.card, required this.headers});

  @override
  Widget build(BuildContext context) {
    if (card.coverUrl.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: primaryColor.withAlpha(54),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withAlpha(62),
              blurRadius: 22,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Transform.scale(
              scale: 1.18,
              child: Opacity(
                opacity: 0.82,
                child: NetworkImageWithLoader(
                  imageUrl: card.coverUrl,
                  title: card.title,
                  headers: headers,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(36),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
