import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

class AutoScrollCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double viewportFraction;
  final double height;
  final double width;

  const AutoScrollCarousel({
    super.key,
    required this.imageUrls,
    this.viewportFraction = 0.7,
    this.height = 400,
    this.width = 300,
  });

  @override
  State<AutoScrollCarousel> createState() => _AutoScrollCarouselState();
}

class _AutoScrollCarouselState extends State<AutoScrollCarousel> {
  late PageController _pageController;
  Timer? _scrollTimer;
  final int virtualItemCount = 100000;
  late int initialPage;

  @override
  void initState() {
    super.initState();
    initialPage = virtualItemCount ~/ 2;
    _pageController = PageController(
      initialPage: initialPage,
      viewportFraction: widget.viewportFraction,
    );
    startMarqueeScroll();
  }

  void startMarqueeScroll() {
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_pageController.hasClients) {
        final maxScroll = _pageController.position.maxScrollExtent;
        final currentScroll = _pageController.offset;
        if (currentScroll < maxScroll) {
          _pageController.jumpTo(currentScroll + 0.8);
        } else {
          _pageController.jumpTo(0);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final realIndex = index % widget.imageUrls.length;
        return _carouselView(realIndex, index);
      },
    );
  }

  Widget _carouselView(int imageIndex, int pageIndex) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double offset = 0;
        double scale = 1.0;
        double rotation = 0.0;

        if (_pageController.hasClients) {
          double currentPage =
              _pageController.page ?? _pageController.initialPage.toDouble();
          offset = pageIndex - currentPage;
          double absOffset = offset.abs().clamp(0.0, 1.0);
          scale = 1 - (absOffset * 0.09);
          rotation = offset * 0.05;
        }

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(rotation)
            ..scale(scale)
            ..translate(0.0, offset.abs() * 20),
          child: _carouselCard(widget.imageUrls[imageIndex], offset),
        );
      },
    );
  }

  Widget _carouselCard(String imageUrl, double offset) {
    double absOffset = offset.abs().clamp(0.0, 1.0);
    double whiteOverlayOpacity = lerpDouble(0, 0.7, absOffset)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 8),
                  blurRadius: 24,
                  color: Colors.black.withAlpha(20),
                ),
              ],
            ),
          ),
          if (absOffset > 0.01)
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(whiteOverlayOpacity),
              ),
            ),
        ],
      ),
    );
  }
}
