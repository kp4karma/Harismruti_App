
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/utils/app_string.dart';

class SmrutiOf extends StatelessWidget {


  const SmrutiOf({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: _buildImageWidgets()),
      ),
    );
  }

  List<Widget> _buildImageWidgets() {
    List<Widget> widgets = [];

    int i = 0;
    while (i < imageUrls.length) {
      // Show composite layout every 5th image
      if (i % 6 == 0 && i + 5 < imageUrls.length) {
        widgets.add(_buildCustomLayout(i));
        i += 6;
      } else {
        // Grid-like layout with 2 stacked images
        widgets.add(_buildGridItemColumn(i));
        i++;
      }
    }

    return widgets;
  }

  Widget _buildGridItemColumn(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        children: [
          _smallImage(imageUrls[index]),
          const SizedBox(height: 10),
          if (index + 1 < imageUrls.length) _smallImage(imageUrls[index + 1]),
        ],
      ),
    );
  }

  Widget _buildCustomLayout(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left large image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrls[index],
              width: 170,
              height: 170,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          // Right 2x2 grid of small images
          Column(
            children: [
              Row(
                children: [
                  _smallImage(imageUrls[index + 1]),
                  const SizedBox(width: 6),
                  _smallImage(imageUrls[index + 2]),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _smallImage(imageUrls[index + 3]),
                  const SizedBox(width: 6),
                  _smallImage(imageUrls[index + 4]),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(url, width: 82, height: 82, fit: BoxFit.cover),
    );
  }
}