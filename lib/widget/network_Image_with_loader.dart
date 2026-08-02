import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';

class NetworkImageWithLoader extends StatelessWidget {
  final String imageUrl;
  final String title;
  final Map<String, String>? headers;
  final BoxFit fit;

  const NetworkImageWithLoader({
    super.key,
    required this.imageUrl,
    required this.title,
    this.headers,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 400.0;
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final decodeWidth = (logicalWidth * devicePixelRatio).round().clamp(
          1,
          1200,
        );

        return CachedNetworkImage(
          imageUrl: imageUrl,
          httpHeaders: headers,
          useOldImageOnUrlChange: true,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          memCacheWidth: decodeWidth,
          maxWidthDiskCache: 1600,
          placeholder: (context, url) => const GalleryShimmerBox(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 0,
          ),
          errorWidget: (context, url, error) =>
              Icon(CupertinoIcons.photo, color: primaryColor),
          fit: fit,
        );
      },
    );
  }
}
