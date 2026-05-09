

import 'package:flutter/material.dart';

class PeopleSmruti extends StatelessWidget {
  final List<Map<String, String>> swamijis = [
    {
      'name': 'P. Hariprasad Swamiji',
      'image': "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    },
    {
      'name': 'P. Prabodh Swamiji',
      'image': "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    },
    {
      'name': 'P. Bhaktipriya Swamiji',
      'image': "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    },
    {
      'name': 'P. Anandsagar Swamiji',
      'image': "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    },
    {
      'name': 'P. Hariprasad Swamiji',
      'image': "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    },
    {
      'name': 'P. Anandsagar Swamiji',
      'image': "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    },
    {
      'name': 'P. Hariprasad Swamiji',
      'image': "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    },
    {
      'name': 'P. Anandsagar Swamiji',
      'image': "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    },
    {
      'name': 'P. Hariprasad Swamiji',
      'image': "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    },
    {
      'name': 'P. Anandsagar Swamiji',
      'image': "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    },
    {
      'name': 'P. Hariprasad Swamiji',
      'image': "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: GridView.builder(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(), // Optional: if inside scroll view
        padding: const EdgeInsets.all(12),
        itemCount: swamijis.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1, // Square
        ),
        itemBuilder: (context, index) {
          final swamiji = swamijis[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Background image
                Positioned.fill(
                  child: Image.network(swamiji['image']!, fit: BoxFit.cover),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        stops: [0.1, 0.6],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withAlpha(100),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Name text
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Text(
                    swamiji['name']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}