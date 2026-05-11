import 'package:flutter/cupertino.dart';
import 'package:harismruti/utils/app_color.dart';

class GallerySectionLoader extends StatelessWidget {
  final double height;

  const GallerySectionLoader({super.key, this.height = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: CupertinoActivityIndicator(radius: 14, color: primaryColor),
      ),
    );
  }
}

class GalleryEmptyState extends StatelessWidget {
  final double height;
  final String message;

  const GalleryEmptyState({
    super.key,
    this.height = 160,
    this.message = 'No smruti found',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: primaryColor.withAlpha(170),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
