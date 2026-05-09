

import 'package:flutter/material.dart';
import 'package:parallax_cards/parallax_cards.dart';

class WallpaperSmruti extends StatelessWidget {
  final List<String> wallpapers = [
    "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  ];

  @override
  Widget build(BuildContext context) {
    // Optional: Responsive width/height
    double cardWidth = 170;
    double cardHeight = 300;

    return  ParallaxCards(
        borderRadius: BorderRadius.circular(20),
        scrollDirection: Axis.horizontal,
        imagesList:wallpapers ,
        width:cardWidth,
        height: cardHeight,
        thumbVisibility: false,
        thickness: 0,margin: EdgeInsetsGeometry.symmetric(horizontal: 8),
        onTap: (index) {},);
    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: wallpapers.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          return Container(
            width: cardWidth,
            margin: const EdgeInsets.only(right: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(wallpapers[index], fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}