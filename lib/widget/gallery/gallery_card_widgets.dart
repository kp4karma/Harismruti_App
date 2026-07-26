import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/ui/view/gallery/gallery_location_screen.dart';
import 'package:harismruti/ui/view/gallery/gallery_timeline_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
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
  final bool overlappingTitle;

  const GalleryMosaicCard({
    super.key,
    required this.card,
    this.headers,
    this.width = 210,
    this.onTap,
    this.overlappingTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final images = card.imageUrls.isNotEmpty
        ? card.imageUrls.take(4).toList(growable: false)
        : <String>[card.coverUrl];

    return _TapScale(
      onTap: onTap ?? () => _openDetail(context, card),
      child: Container(
        width: width,
        margin: overlappingTitle
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
            : const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: overlappingTitle ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: overlappingTitle
              ? null
              : const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: overlappingTitle
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    bottom: 48,
                    child: _MasonryPreview(
                      images: images,
                      title: card.title,
                      headers: headers,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 66),
                          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(242),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withAlpha(42),
                                blurRadius: 18,
                                spreadRadius: 1,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      card.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF171717),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      card.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.black.withAlpha(115),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: primaryColor.withAlpha(18),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: primaryColor.withAlpha(38),
                                  ),
                                ),
                                child: Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 17,
                                  color: primaryColor.withAlpha(190),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _MasonryPreview(
                      images: images,
                      title: card.title,
                      headers: headers,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
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
}

class _MasonryPreview extends StatelessWidget {
  final List<String> images;
  final String title;
  final Map<String, String>? headers;

  const _MasonryPreview({
    required this.images,
    required this.title,
    required this.headers,
  });

  @override
  Widget build(BuildContext context) {
    final urls = List<String>.generate(
      4,
      (index) => images.isEmpty ? '' : images[index % images.length],
      growable: false,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(flex: 5, child: _tile(urls[0])),
              const SizedBox(height: 6),
              Expanded(flex: 3, child: _tile(urls[2])),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            children: [
              Expanded(flex: 3, child: _tile(urls[1])),
              const SizedBox(height: 6),
              Expanded(flex: 5, child: _tile(urls[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: const Color(0xFFF2F2F2),
        child: url.isEmpty
            ? Center(child: Icon(Icons.photo, color: primaryColor, size: 24))
            : SizedBox.expand(
                child: NetworkImageWithLoader(
                  imageUrl: url,
                  title: title,
                  headers: headers,
                  fit: BoxFit.cover,
                ),
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
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF1ECE8),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(34),
              blurRadius: 20,
              offset: const Offset(0, 10),
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
                      fit: BoxFit.cover,
                    ),
                  ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(8),
                    Colors.black.withAlpha(190),
                  ],
                  stops: const [0.38, 0.58, 1],
                ),
              ),
            ),
            if (previewImages.isNotEmpty)
              Positioned(
                right: 10,
                top: 10,
                child: SizedBox(
                  width: 52,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < previewImages.length; index++)
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: index == previewImages.length - 1 ? 0 : 7,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ColoredBox(
                                    color: const Color(0xFFFFFFFF),
                                    child: NetworkImageWithLoader(
                                      imageUrl: previewImages[index],
                                      title: card.title,
                                      headers: headers,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.white.withAlpha(220),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(40),
                                          blurRadius: 8,
                                        ),
                                      ],
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 22, 10, 10),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 5,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(38),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withAlpha(70),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.photo_on_rectangle,
                                color: Colors.white.withAlpha(235),
                                size: 11,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _photoCountLabel(card),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(235),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
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
        crossAxisCount: responsiveImageColumnCount(context),
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
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Gallery Timeline'),
        builder: (_) => GalleryTimelineScreen(year: year),
      ),
    );
    return;
  }

  if (card.type == 'location') {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Gallery Location'),
        builder: (_) => GalleryLocationScreen(card: card),
      ),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: 'Gallery Detail'),
      builder: (_) => GalleryDetailScreen.fromCard(card),
    ),
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
