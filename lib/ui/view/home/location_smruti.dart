import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/widget/gallery/gallery_card_widgets.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';

class LocationSmruti extends StatefulWidget {
  const LocationSmruti({super.key});

  @override
  State<LocationSmruti> createState() => _LocationSmrutiState();
}

class _LocationSmrutiState extends State<LocationSmruti> {
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 35), (_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0) return;

      final next = position.pixels + 0.45;
      if (next >= position.maxScrollExtent) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.jumpTo(next);
      }
    });
  }

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
        height: 310,
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          itemCount: (locations.length / 3).ceil(),
          itemBuilder: (context, index) {
            final layoutWidth = MediaQuery.of(context).size.width * 0.8;
            final firstIndex = index * 3;
            final secondIndex = firstIndex + 1;
            final thirdIndex = firstIndex + 2;
            final bottomCards = [
              if (secondIndex < locations.length) locations[secondIndex],
              if (thirdIndex < locations.length) locations[thirdIndex],
            ];
            final bigCard = GalleryGridCard(
              card: locations[firstIndex],
              headers: galleryController.imageHeaders,
              aspectRatio: 1,
              fillParent: true,
            );
            final smallRow = Row(
              children: [
                for (var item = 0; item < bottomCards.length; item++) ...[
                  Expanded(
                    child: GalleryGridCard(
                      card: bottomCards[item],
                      headers: galleryController.imageHeaders,
                      aspectRatio: 1,
                      fillParent: true,
                    ),
                  ),
                  if (item != bottomCards.length - 1) const SizedBox(width: 6),
                ],
              ],
            );

            return SizedBox(
              width: layoutWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  children: index.isEven
                      ? [
                          Expanded(flex: 6, child: bigCard),
                          const SizedBox(height: 6),
                          Expanded(flex: 4, child: smallRow),
                        ]
                      : [
                          Expanded(flex: 4, child: smallRow),
                          const SizedBox(height: 6),
                          Expanded(flex: 6, child: bigCard),
                        ],
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
