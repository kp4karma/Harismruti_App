import 'package:cached_network_image/cached_network_image.dart';
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
  late final AuthCarouselRepository _repository;
  late final AuthCarouselImages? _cachedImages;
  late final Future<AuthCarouselImages> _imagesFuture;
  bool _didPrecache = false;

  @override
  void initState() {
    super.initState();
    _repository = AuthCarouselRepository();
    _cachedImages = _repository.getCachedRecentImages();
    _imagesFuture = _repository.getRandomRecentImages();
  }

  @override
  Widget build(BuildContext context) {
    final carousel = FutureBuilder<AuthCarouselImages>(
      future: _imagesFuture,
      initialData: _cachedImages,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null && !_didPrecache) {
          _didPrecache = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            for (final imageUrl in data.imageUrls.take(5)) {
              precacheImage(
                CachedNetworkImageProvider(imageUrl, headers: data.headers),
                context,
              );
            }
          });
        }
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
