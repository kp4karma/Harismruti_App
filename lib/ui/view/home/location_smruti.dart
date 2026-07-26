import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/widget/gallery/gallery_card_widgets.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';

class LocationSmruti extends StatefulWidget {
  const LocationSmruti({super.key});

  @override
  State<LocationSmruti> createState() => _LocationSmrutiState();
}

class _LocationSmrutiState extends State<LocationSmruti>
    with SingleTickerProviderStateMixin {
  static const double _autoScrollPixelsPerSecond = 18;
  static const Duration _resumeDelay = Duration(milliseconds: 2500);

  final ScrollController _scrollController = ScrollController();
  late final Ticker _autoScrollTicker;
  Duration? _lastTickElapsed;
  Timer? _resumeTimer;
  bool _pausedByUser = false;

  @override
  void initState() {
    super.initState();
    _autoScrollTicker = createTicker(_handleAutoScrollTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _autoScrollTicker.start();
    });
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _autoScrollTicker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _resumeTimer?.cancel();
      _pausedByUser = true;
    } else if (notification is ScrollEndNotification) {
      _resumeTimer?.cancel();
      _resumeTimer = Timer(_resumeDelay, () {
        if (mounted) _pausedByUser = false;
      });
    }
    return false;
  }

  void _handleAutoScrollTick(Duration elapsed) {
    final lastElapsed = _lastTickElapsed;
    _lastTickElapsed = elapsed;
    if (lastElapsed == null || !_scrollController.hasClients) return;
    if (_pausedByUser) return;

    final position = _scrollController.position;
    if (position.userScrollDirection != ScrollDirection.idle) return;

    final seconds = (elapsed - lastElapsed).inMicroseconds / 1000000;
    final nextOffset = position.pixels + (_autoScrollPixelsPerSecond * seconds);
    position.jumpTo(nextOffset.clamp(0.0, position.maxScrollExtent));
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

      final groupCount = (locations.length / 3).ceil();
      final itemCount = groupCount <= 1 ? groupCount : groupCount * 200;

      return SizedBox(
        height: 310,
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              final layoutWidth = MediaQuery.of(context).size.width * 0.8;
              final groupIndex = index % groupCount;
              final firstIndex = groupIndex * 3;
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
                imageFit: BoxFit.cover,
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
                        imageFit: BoxFit.cover,
                      ),
                    ),
                    if (item != bottomCards.length - 1)
                      const SizedBox(width: 6),
                  ],
                ],
              );

              return SizedBox(
                width: layoutWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    children: groupIndex.isEven
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
        ),
      );
    });
  }
}
