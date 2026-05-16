import 'package:flutter/material.dart';
import 'package:harismruti/widget/background/animated_gallery_background.dart';

class CustomBackground extends StatelessWidget {
  final Widget child;

  const CustomBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedGalleryBackground(tileOpacity: 0.18, child: child);
  }
}
