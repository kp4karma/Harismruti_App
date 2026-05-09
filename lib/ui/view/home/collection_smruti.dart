import 'package:flutter/material.dart';
import 'package:harismruti/utils/size_config.dart';

class CollectionSmruti extends StatelessWidget {
  final List<List<String>> allImageGroups = [
    [
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    ],
    [
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
    ],
    // Add more groups as needed
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(allImageGroups.length, (index) {
            return CollectionCard(
              imageUrls: allImageGroups[index],
              title: '20${22 + index}',
              subtitle: '12 Photos',
            );
          }),
        ),
      ),
    );
  }
}

class CollectionCard extends StatelessWidget {
  final List<String> imageUrls;
  final String title;
  final String subtitle;

  const CollectionCard({
    super.key,
    required this.imageUrls,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final shuffled = List<String>.from(imageUrls)..shuffle();
    final mainImage = shuffled.first;
    final sideImages = shuffled.skip(1).take(3).toList();

    return Container(
      width: 200,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Image Grid Row
          Row(
            children: [
              // Main Big Image
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    mainImage,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Right Side Small Images
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(sideImages.length, (index) {
                  final url = sideImages[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      left: 8,
                      bottom: index == 1 ? 4 : 0,
                      top: index == 1 ? 4 : 0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        height: 44,
                        width: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),

          SizedBox(height: SizeConfig.heightMultiplier! * 1),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),

          // Subtitle
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
