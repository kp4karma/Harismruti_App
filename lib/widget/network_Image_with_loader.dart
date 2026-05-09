import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:harismruti/utils/app_color.dart';

class NetworkImageWithLoader extends StatelessWidget {
  final String imageUrl;
  final String title;

  const NetworkImageWithLoader({super.key, required this.imageUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      placeholder: (context, url) => CupertinoActivityIndicator(
        radius: 14,
        color: primaryColor,
      ),
      errorWidget: (context, url, error) => Icon(
        CupertinoIcons.photo,
        color: primaryColor,
      ),
      fit: BoxFit.cover,
    );
  }
}
