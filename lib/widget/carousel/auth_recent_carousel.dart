import 'package:flutter/material.dart';
import 'package:harismruti/api/repositories/auth_carousel_repository.dart';
import 'package:harismruti/widget/carousel/auto_scroll_carousel.dart';

class AuthRecentCarousel extends StatefulWidget {
  final double? height;

  const AuthRecentCarousel({super.key, this.height});

  @override
  State<AuthRecentCarousel> createState() => _AuthRecentCarouselState();
}

class _AuthRecentCarouselState extends State<AuthRecentCarousel> {
  late final Future<AuthCarouselImages> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _imagesFuture = AuthCarouselRepository().getRandomRecentImages();
  }

  @override
  Widget build(BuildContext context) {
    final carousel = FutureBuilder<AuthCarouselImages>(
      future: _imagesFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return AutoScrollCarousel(
          imageUrls: data?.imageUrls ?? const [],
          imageHeaders: data?.headers ?? const {},
        );
      },
    );

    if (widget.height == null) return carousel;
    return SizedBox(height: widget.height, child: carousel);
  }
}
