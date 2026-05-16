import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/widget/appbar/detail_appbar.dart';
import 'package:harismruti/widget/background/custom_background.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class MyCollectionScreen extends StatelessWidget {
  final GalleryController controller = Get.find<GalleryController>();

  MyCollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: Scaffold(
        appBar: DetailAppbar(
          onBackTap: () => Navigator.pop(context),
          title: 'My Collection',
        ),
        body: Obx(() {
          final favorites = controller.favoritePhotos;
          final collections = controller.userCollections;
          if (favorites.isEmpty && collections.isEmpty) {
            return const GalleryEmptyState(
              height: 360,
              message: 'No favorites or collections yet',
            );
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _SectionHeader(
                icon: CupertinoIcons.heart_fill,
                title: 'Favorites',
                count: favorites.length,
              ),
              const SizedBox(height: 12),
              if (favorites.isEmpty)
                const _EmptyPanel(message: 'Favorite photos will show here')
              else
                _PhotoGrid(
                  photos: favorites,
                  title: 'Favorites',
                  headers: controller.imageHeaders,
                ),
              const SizedBox(height: 22),
              _SectionHeader(
                icon: CupertinoIcons.collections,
                title: 'Collections',
                count: collections.length,
              ),
              const SizedBox(height: 12),
              if (collections.isEmpty)
                const _EmptyPanel(message: 'Create collections from any photo')
              else
                for (final collection in collections) ...[
                  _CollectionCard(
                    collection: collection,
                    photos: controller.photosForCollection(collection),
                    headers: controller.imageHeaders,
                    onDelete: () =>
                        _confirmRemoveCollection(context, collection.name),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        }),
      ),
    );
  }

  Future<void> _confirmRemoveCollection(
    BuildContext context,
    String collectionName,
  ) async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _RemoveCollectionSheet(collectionName: collectionName),
    );
    if (remove == true) {
      controller.removeCollection(collectionName);
    }
  }
}

class _RemoveCollectionSheet extends StatelessWidget {
  final String collectionName;

  const _RemoveCollectionSheet({required this.collectionName});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Icon(Icons.delete_outline_rounded, color: primaryColor, size: 32),
            const SizedBox(height: 12),
            const Text(
              'Remove Collection',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Remove "$collectionName" from your collections?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withAlpha(145),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor.withAlpha(80)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Remove'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<GalleryPhoto> photos;
  final String title;
  final Map<String, String> headers;

  const _PhotoGrid({
    required this.photos,
    required this.title,
    required this.headers,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final photo = photos[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => GalleryFullscreenViewer(
                  photos: photos,
                  initialIndex: index,
                  title: title,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: NetworkImageWithLoader(
              imageUrl: photo.thumbnailUrl,
              title: photo.title ?? title,
              headers: headers,
            ),
          ),
        );
      },
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final UserPhotoCollection collection;
  final List<GalleryPhoto> photos;
  final Map<String, String> headers;
  final VoidCallback onDelete;

  const _CollectionCard({
    required this.collection,
    required this.photos,
    required this.headers,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withAlpha(150),
          child: InkWell(
            onTap: photos.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => GalleryFullscreenViewer(
                          photos: photos,
                          initialIndex: 0,
                          title: collection.name,
                        ),
                      ),
                    );
                  },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: photos.isEmpty
                          ? ColoredBox(
                              color: const Color(0xFFF4F1EE),
                              child: Icon(
                                CupertinoIcons.photo,
                                color: primaryColor,
                              ),
                            )
                          : NetworkImageWithLoader(
                              imageUrl: photos.first.thumbnailUrl,
                              title: collection.name,
                              headers: headers,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${photos.length} photos',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String message;

  const _EmptyPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(140),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.black.withAlpha(135),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
