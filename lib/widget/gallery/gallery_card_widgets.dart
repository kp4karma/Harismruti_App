import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/ui/view/gallery/gallery_location_screen.dart';
import 'package:harismruti/ui/view/gallery/gallery_timeline_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class GalleryCoverCard extends StatelessWidget {
  final GalleryCard card;
  final Map<String, String>? headers;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const GalleryCoverCard({
    super.key,
    required this.card,
    this.headers,
    this.width = 170,
    this.height = 220,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      onTap: onTap ?? () => _openDetail(context, card),
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: card.coverUrl.isEmpty
                  ? Icon(Icons.photo, color: primaryColor)
                  : NetworkImageWithLoader(
                      imageUrl: card.coverUrl,
                      title: card.title,
                      headers: headers,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 1),
              child: Text(
                card.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
              child: Text(
                card.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GalleryMosaicCard extends StatelessWidget {
  final GalleryCard card;
  final Map<String, String>? headers;
  final double width;
  final VoidCallback? onTap;

  const GalleryMosaicCard({
    super.key,
    required this.card,
    this.headers,
    this.width = 210,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final images = card.imageUrls;

    return _TapScale(
      onTap: onTap ?? () => _openDetail(context, card),
      child: Container(
        width: width,
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _image(
                      images.isNotEmpty ? images.first : card.coverUrl,
                      140,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _image(
                            images.length > 1 ? images[1] : card.coverUrl,
                            44,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: _image(
                            images.length > 2 ? images[2] : card.coverUrl,
                            44,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: _image(
                            images.length > 3 ? images[3] : card.coverUrl,
                            44,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              card.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              card.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image(String url, double fallbackSize) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url.isEmpty
          ? ColoredBox(
              color: const Color(0xFFF2E9E4),
              child: Center(
                child: Icon(
                  Icons.photo,
                  color: primaryColor,
                  size: fallbackSize * 0.4,
                ),
              ),
            )
          : SizedBox.expand(
              child: NetworkImageWithLoader(
                imageUrl: url,
                title: card.title,
                headers: headers,
              ),
            ),
    );
  }
}

class GalleryCollectionCollageCard extends StatelessWidget {
  final GalleryCard card;
  final Map<String, String>? headers;
  final double width;
  final VoidCallback? onTap;

  const GalleryCollectionCollageCard({
    super.key,
    required this.card,
    this.headers,
    this.width = 300,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final photos = card.photos;
    final visiblePhotos = photos.isNotEmpty
        ? photos
        : [
            if (card.coverUrl.isNotEmpty)
              GalleryPhoto(
                id: card.id,
                thumbnailUrl: card.coverUrl,
                fullUrl: card.coverUrl,
              ),
          ];

    return _TapScale(
      onTap: onTap ?? () => _openDetail(context, card),
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              bottom: 42,
              child: _HomeCollectionBentoCollage(
                photos: visiblePhotos,
                headers: headers,
                seed: card.title.hashCode,
              ),
            ),
            Positioned(
              left: 4,
              right: 4,
              bottom: 0,
              child: _HomeCollectionInfoBar(card: card),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCollectionInfoBar extends StatelessWidget {
  final GalleryCard card;

  const _HomeCollectionInfoBar({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(34),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(214),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(145)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        card.title.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 3,
                        children: [
                          _MiniSummary(
                            icon: CupertinoIcons.photo_on_rectangle,
                            label: card.subtitle.isNotEmpty
                                ? card.subtitle
                                : '${card.count ?? card.photos.length} Photos',
                          ),
                          if ((card.locationCount ?? 0) > 0)
                            _MiniSummary(
                              icon: CupertinoIcons.location,
                              label: '${card.locationCount} Places',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    color: primaryColor,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniSummary extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniSummary({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: primaryColor, size: 11),
        const SizedBox(width: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: primaryColor,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _HomeCollectionBentoCollage extends StatelessWidget {
  final List<GalleryPhoto> photos;
  final Map<String, String>? headers;
  final int seed;

  const _HomeCollectionBentoCollage({
    required this.photos,
    required this.headers,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return ColoredBox(
        color: const Color(0xFFF2E9E4),
        child: Icon(CupertinoIcons.photo, color: primaryColor),
      );
    }
    final preferredPhotos = _landscapePhotosFirst(photos);
    final orderedPhotos = List<GalleryPhoto>.generate(5, (index) {
      final offset = seed.abs() % preferredPhotos.length;
      return preferredPhotos[(index + offset) % preferredPhotos.length];
    });

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFEA),
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withAlpha(238),
            secondaryColor.withAlpha(22),
            primaryColor.withAlpha(18),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withAlpha(14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Row(
          children: [
            Expanded(
              flex: 7,
              child: Column(
                children: [
                  Expanded(
                    flex: 7,
                    child: _CollectionBentoTile(
                      photo: orderedPhotos[0],
                      headers: headers,
                      radius: 18,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Expanded(
                          child: _CollectionBentoTile(
                            photo: orderedPhotos[2],
                            headers: headers,
                            radius: 14,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _CollectionBentoTile(
                            photo: orderedPhotos[3],
                            headers: headers,
                            radius: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Expanded(
                    flex: 5,
                    child: _CollectionBentoTile(
                      photo: orderedPhotos[1],
                      headers: headers,
                      radius: 16,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Expanded(
                    flex: 6,
                    child: _CollectionBentoTile(
                      photo: orderedPhotos[4],
                      headers: headers,
                      radius: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<GalleryPhoto> _landscapePhotosFirst(List<GalleryPhoto> photos) {
    final sorted = photos.toList();
    sorted.sort((a, b) {
      final orientation = _orientationRank(a).compareTo(_orientationRank(b));
      if (orientation != 0) return orientation;
      return b.id.compareTo(a.id);
    });
    return sorted;
  }

  static int _orientationRank(GalleryPhoto photo) {
    final width = photo.width;
    final height = photo.height;
    if (width == null || height == null || width <= 0 || height <= 0) return 1;
    return width >= height ? 0 : 2;
  }
}

class _CollectionBentoTile extends StatelessWidget {
  final GalleryPhoto photo;
  final Map<String, String>? headers;
  final double radius;

  const _CollectionBentoTile({
    required this.photo,
    required this.headers,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(226),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withAlpha(190), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _CollectionPreviewImage(
        photo: photo,
        headers: headers,
        fit: BoxFit.contain,
        radius: radius,
      ),
    );
  }
}

class _CollectionPreviewImage extends StatelessWidget {
  final GalleryPhoto photo;
  final Map<String, String>? headers;
  final BoxFit fit;
  final double radius;

  const _CollectionPreviewImage({
    required this.photo,
    required this.headers,
    required this.fit,
    this.radius = 0,
  });

  @override
  Widget build(BuildContext context) {
    final image = NetworkImageWithLoader(
      imageUrl: photo.thumbnailUrl,
      title: photo.title ?? 'Smruti',
      headers: headers,
      fit: fit,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (fit == BoxFit.contain) ...[
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Transform.scale(
                scale: 1.24,
                child: NetworkImageWithLoader(
                  imageUrl: photo.thumbnailUrl,
                  title: photo.title ?? 'Smruti',
                  headers: headers,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withAlpha(124),
                    secondaryColor.withAlpha(28),
                    primaryColor.withAlpha(32),
                  ],
                ),
              ),
            ),
          ],
          image,
        ],
      ),
    );
  }
}

class GalleryWithFeatureCard extends StatelessWidget {
  final GalleryCard card;
  final Map<String, String>? headers;
  final double width;
  final VoidCallback? onTap;

  const GalleryWithFeatureCard({
    super.key,
    required this.card,
    this.headers,
    this.width = 248,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final previewImages = card.imageUrls.skip(1).take(2).toList();

    return _TapScale(
      onTap: onTap ?? () => _openDetail(context, card),
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF2E9E4),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            card.coverUrl.isEmpty
                ? Icon(CupertinoIcons.photo, color: primaryColor)
                : NetworkImageWithLoader(
                    imageUrl: card.coverUrl,
                    title: card.title,
                    headers: headers,
                  ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withAlpha(8),
                    Colors.black.withAlpha(28),
                    Colors.black.withAlpha(138),
                  ],
                  stops: const [0.12, 0.48, 1],
                ),
              ),
            ),
            if (previewImages.isNotEmpty)
              Positioned(
                right: 12,
                top: 12,
                child: SizedBox(
                  width: 58,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < previewImages.length; index++)
                        SizedBox(
                          width: 58,
                          height: 58,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: index == previewImages.length - 1 ? 0 : 8,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  NetworkImageWithLoader(
                                    imageUrl: previewImages[index],
                                    title: card.title,
                                    headers: headers,
                                  ),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.white.withAlpha(145),
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(76),
                      border: Border(
                        top: BorderSide(color: Colors.white.withAlpha(90)),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            card.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.photo_on_rectangle,
                              color: Colors.white.withAlpha(220),
                              size: 10,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _photoCountLabel(card),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withAlpha(220),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GalleryGridCard extends StatelessWidget {
  final GalleryCard card;
  final Map<String, String>? headers;
  final double aspectRatio;
  final bool fillParent;
  final BoxFit imageFit;
  final VoidCallback? onTap;

  const GalleryGridCard({
    super.key,
    required this.card,
    this.headers,
    this.aspectRatio = 0.78,
    this.fillParent = false,
    this.imageFit = BoxFit.cover,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = _TapScale(
      onTap: onTap ?? () => _openDetail(context, card),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            card.coverUrl.isEmpty
                ? ColoredBox(
                    color: const Color(0xFFF2E9E4),
                    child: Center(
                      child: Icon(Icons.photo, color: primaryColor, size: 34),
                    ),
                  )
                : NetworkImageWithLoader(
                    imageUrl: card.coverUrl,
                    title: card.title,
                    headers: headers,
                    fit: imageFit,
                  ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(12),
                    Colors.black.withAlpha(165),
                  ],
                  stops: const [0.36, 0.62, 1],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white],
                  stops: [0, 0.42],
                ).createShader(bounds),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 34, 12, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withAlpha(0),
                            Colors.black.withAlpha(78),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _GlassMetaText(
                                  icon: CupertinoIcons.location_solid,
                                  label: card.title,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _GlassMetaText(
                                icon: CupertinoIcons.photo,
                                label: _photoCountLabel(card),
                                alignEnd: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (fillParent) {
      return SizedBox.expand(child: child);
    }

    return AspectRatio(aspectRatio: aspectRatio, child: child);
  }
}

class GalleryCardGrid extends StatelessWidget {
  final List<GalleryCard> cards;
  final Map<String, String>? headers;
  final double childAspectRatio;
  final EdgeInsets padding;

  const GalleryCardGrid({
    super.key,
    required this.cards,
    this.headers,
    this.childAspectRatio = 0.78,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 22),
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      primary: false,
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width >= 680 ? 3 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) =>
          GalleryGridCard(card: cards[index], headers: headers),
    );
  }
}

String _photoCountLabel(GalleryCard card) {
  if (card.count != null) return card.count.toString();
  final match = RegExp(r'\d+').firstMatch(card.subtitle);
  return match?.group(0) ?? card.subtitle.replaceAll('Photos', '').trim();
}

class _GlassMetaText extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool alignEnd;

  const _GlassMetaText({
    required this.icon,
    required this.label,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: alignEnd ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white.withAlpha(230), size: 12),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

void _openDetail(BuildContext context, GalleryCard card) {
  if (card.type == 'collection') {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GalleryTimelineScreen()),
    );
    return;
  }

  if (card.type == 'location') {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GalleryLocationScreen(card: card)),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => GalleryDetailScreen.fromCard(card)),
  );
}

class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapScale({required this.child, required this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
