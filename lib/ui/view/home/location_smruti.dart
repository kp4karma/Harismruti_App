import 'package:flutter/material.dart';
import 'package:harismruti/utils/app_string.dart';

class LocationSmruti extends StatelessWidget {

  @override
  Widget build(BuildContext context) {


    return SizedBox(
      height: 290,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: photoAlbumList.length,
        itemBuilder: (context, index) {
          final album = photoAlbumList[index];
          return PhotoAlbumCard(
            title: album['title'],
            subtitle: album['subtitle'],
            images: album['images'],
          );
        },
      ),
    );
  }
}


class PhotoAlbumCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> images;

  const PhotoAlbumCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.images,
  });

  @override
  State<PhotoAlbumCard> createState() => _PhotoAlbumCardState();
}

class _PhotoAlbumCardState extends State<PhotoAlbumCard> {
  late String selectedImage;

  @override
  void initState() {
    super.initState();
    selectedImage = widget.images.first; // default main image
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(10), // main padding
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              selectedImage,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 10),

          // Thumbnails
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.images.map((img) {
                final isSelected = img == selectedImage;
                return GestureDetector(
                  onTap: () => setState(() => selectedImage = img),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.orange : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        img,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Title and Subtitle
          Text(
            widget.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            widget.subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}