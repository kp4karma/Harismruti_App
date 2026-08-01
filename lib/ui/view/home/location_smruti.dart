import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
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
    Get.find<GalleryController>().loadAllPlaces();
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
      final locations = galleryController.placeCards;
      if (galleryController.isLoading.value && locations.isEmpty) {
        return const GallerySectionLoader(height: 250);
      }
      if (locations.isEmpty) {
        return const GalleryEmptyState(height: 180);
      }

      final itemCount = locations.length <= 1
          ? locations.length
          : locations.length * 200;

      return SizedBox(
        height: 310,
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: MasonryGridView.count(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              final card = locations[index % locations.length];
              final cardWidth = switch (index % 5) {
                0 => 210.0,
                1 => 160.0,
                2 => 188.0,
                3 => 228.0,
                _ => 176.0,
              };
              return SizedBox(
                width: cardWidth,
                child: GalleryGridCard(
                  card: card,
                  headers: galleryController.imageHeaders,
                  fillParent: true,
                  imageFit: BoxFit.cover,
                ),
              );
            },
          ),
        ),
      );
    });
  }
}
