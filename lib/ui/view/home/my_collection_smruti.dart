import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class MyCollectionSmruti extends StatelessWidget {
  const MyCollectionSmruti({super.key});

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();

    final scale = tabletScale(context);
    if (!StorageHelper.isLogin()) {
      return GestureDetector(
        onTap: AuthRedirectHelper.ensureLoggedIn,
        child: GalleryEmptyState(
          height: 190 * scale,
          message: 'Login to see your collections',
        ),
      );
    }

    return Obx(() {
      final collections = galleryController.userCollections.toList(
        growable: false,
      );
      if (collections.isEmpty) {
        return GalleryEmptyState(
          height: 190 * scale,
          message: 'Create collections from any photo',
        );
      }

      return SizedBox(
        height: 220 * scale,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          itemCount: collections.length,
          itemBuilder: (context, index) {
            final collection = collections[index];
            return _CollectionCard(
              collection: collection,
              photos: galleryController.photosForCollection(collection),
              headers: galleryController.imageHeaders,
              onDelete: () => _confirmRemoveCollection(
                context,
                galleryController,
                collection.name,
              ),
            );
          },
        ),
      );
    });
  }

  Future<void> _confirmRemoveCollection(
    BuildContext context,
    GalleryController controller,
    String collectionName,
  ) async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ResponsiveBottomCenter(
        maxWidth: kSheetMaxWidth,
        child: _RemoveCollectionSheet(collectionName: collectionName),
      ),
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
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
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
                color: Theme.of(context).colorScheme.outlineVariant,
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _CollectionCard extends StatelessWidget {
  final UserPhotoCollection collection;
  final List<GalleryPhoto> photos;
  final Map<String, String>? headers;
  final VoidCallback onDelete;

  const _CollectionCard({
    required this.collection,
    required this.photos,
    required this.headers,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cover = photos.isNotEmpty ? photos.first.thumbnailUrl : '';

    return GestureDetector(
      onTap: photos.isEmpty
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'My Collection Detail'),
                  builder: (_) => GalleryDetailScreen(
                    title: collection.name,
                    subtitle: '${photos.length} Photos',
                    coverUrl: cover,
                    loader: () async => photos,
                  ),
                ),
              );
            },
      child: Container(
        width: 245 * tabletScale(context),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover.isNotEmpty)
              NetworkImageWithLoader(
                imageUrl: cover,
                title: collection.name,
                headers: headers,
              )
            else
              ColoredBox(
                color: const Color(0xFFF4F1EE),
                child: Icon(Icons.collections, color: primaryColor, size: 34),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(25),
                    Colors.black.withAlpha(135),
                  ],
                  stops: const [0.42, 0.7, 1],
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Material(
                color: Colors.white.withAlpha(230),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onDelete,
                  child: SizedBox(
                    width: 34 * tabletScale(context),
                    height: 34 * tabletScale(context),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: primaryColor,
                      size: 19 * tabletScale(context),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${photos.length} photos',
                    style: TextStyle(
                      color: Colors.white.withAlpha(215),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
