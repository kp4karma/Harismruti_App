import 'package:flutter/material.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class GalleryCoverCard extends StatelessWidget {
  final GalleryCard card;
  final Map<String, String>? headers;
  final double width;
  final double height;

  const GalleryCoverCard({
    super.key,
    required this.card,
    this.headers,
    this.width = 170,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: height * 0.68,
            width: double.infinity,
            child: card.coverUrl.isEmpty
                ? Icon(Icons.photo, color: primaryColor)
                : NetworkImageWithLoader(
                    imageUrl: card.coverUrl,
                    title: card.title,
                    headers: headers,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Text(
              card.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              card.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class GalleryMosaicCard extends StatelessWidget {
  final GalleryCard card;
  final Map<String, String>? headers;
  final double width;

  const GalleryMosaicCard({
    super.key,
    required this.card,
    this.headers,
    this.width = 210,
  });

  @override
  Widget build(BuildContext context) {
    final images = card.imageUrls;

    return Container(
      width: width,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
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
          : NetworkImageWithLoader(
              imageUrl: url,
              title: card.title,
              headers: headers,
            ),
    );
  }
}
