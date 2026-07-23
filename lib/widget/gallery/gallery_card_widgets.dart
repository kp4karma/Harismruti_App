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
              color: const Color(0xFFFFFFFF),
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
          color: const Color(0xFFFFFFFF),
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
                : ColoredBox(
                    color: const Color(0xFFFFFFFF),
                    child: NetworkImageWithLoader(
                      imageUrl: card.coverUrl,
                      title: card.title,
                      headers: headers,
                      fit: BoxFit.contain,
                    ),
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
                                  ColoredBox(
                                    color: const Color(0xFFFFFFFF),
                                    child: NetworkImageWithLoader(
                                      imageUrl: previewImages[index],
                                      title: card.title,
                                      headers: headers,
                                      fit: BoxFit.contain,
                                    ),
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
                    color: const Color(0xFFFFFFFF),
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
    final year = int.tryParse(card.value) ?? card.id;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GalleryTimelineScreen(year: year)),
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
