import 'package:flutter/material.dart';
import 'package:harismruti/utils/app_string.dart';
import 'package:harismruti/utils/size_config.dart';

class AlbumSmruti extends StatelessWidget {


  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SizeConfig.heightMultiplier! * 31,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: eventList.map((event) {
            return AlbumCard(
              images: event['images'],
              title: event['title'],
              subtitle: event['subtitle'],
            );
          }).toList(),
        ),
      ),
    );
  }
}


class AlbumCard extends StatelessWidget {
  final List<String> images; // At least 4 images
  final String title;
  final String subtitle;

  const AlbumCard({
    super.key,
    required this.images,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final shuffledImages = images.toList()..shuffle();
    final mainImage = shuffledImages.first;
    final bottomImages = shuffledImages.skip(1).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: SizeConfig.widthMultiplier! * 50,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top large image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Image.network(
                  mainImage,
                  height: SizeConfig.heightMultiplier! * 17,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

              SizedBox(height: SizeConfig.heightMultiplier! * 0.5),

              // Bottom 3 images
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(bottomImages.length, (index) {
                  final url = bottomImages[index];

                  // Determine custom border radius based on position
                  BorderRadius borderRadius;
                  if (index == 0) {
                    borderRadius = const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                    );
                  } else if (index == bottomImages.length - 1) {
                    borderRadius = const BorderRadius.only(
                      bottomRight: Radius.circular(12),
                    );
                  } else {
                    borderRadius = BorderRadius.zero;
                  }

                  return ClipRRect(
                    borderRadius: borderRadius,
                    child: Image.network(
                      url,
                      width: SizeConfig.widthMultiplier! * 16,
                      height: SizeConfig.widthMultiplier! * 16,
                      fit: BoxFit.cover,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}