import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
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
          final tags = controller.allUserTags;
          if (favorites.isEmpty && collections.isEmpty && tags.isEmpty) {
            return const GalleryEmptyState(
              height: 360,
              message: 'No favorites, collections, or tags yet',
            );
          }

          return ResponsiveCenter(
            maxWidth: kContentMaxWidth,
            child: ListView(
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
                  const _EmptyPanel(
                    message: 'Create collections from any photo',
                  )
                else
                  for (final collection in collections) ...[
                    _CollectionCard(
                      collection: collection,
                      photos: controller.photosForCollection(collection),
                      headers: controller.imageHeaders,
                      onEdit: () => _renameCollection(context, collection.name),
                      onDelete: () =>
                          _confirmRemoveCollection(context, collection.name),
                    ),
                    const SizedBox(height: 12),
                  ],
                const SizedBox(height: 22),
                _SectionHeader(
                  icon: CupertinoIcons.tag_fill,
                  title: 'My Tags',
                  count: controller.allUserTags.length,
                ),
                const SizedBox(height: 12),
                if (controller.allUserTags.isEmpty)
                  const _EmptyPanel(
                    message: 'Tags added to photos will show here',
                  )
                else
                  for (final tag in tags) ...[
                    _TagCard(
                      tag: tag,
                      photoCount: controller.photoCountForTag(tag),
                      onTap: () => _openTagOptions(context, tag),
                      onEdit: () => _renameTag(context, tag),
                      onDelete: () => _confirmRemoveTag(context, tag),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
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
      builder: (context) => ResponsiveBottomCenter(
        maxWidth: kSheetMaxWidth,
        child: _RemoveCollectionSheet(collectionName: collectionName),
      ),
    );
    if (remove == true) {
      await controller.removeCollection(collectionName);
    }
  }

  Future<void> _renameCollection(BuildContext context, String name) async {
    final newName = await _showRenameDialog(
      context,
      title: 'Rename Collection',
      currentName: name,
    );
    if (newName == null || newName == name) return;
    final updated = await controller.renameCollection(name, newName);
    if (!updated && context.mounted) {
      _showError(context, 'Could not rename the collection.');
    }
  }

  Future<void> _renameTag(BuildContext context, String tag) async {
    final newName = await _showRenameDialog(
      context,
      title: 'Rename Tag Everywhere',
      currentName: tag,
    );
    if (newName == null || newName == tag) return;
    final updated = await controller.renameTagEverywhere(tag, newName);
    if (!updated && context.mounted) {
      _showError(context, 'Could not rename the tag.');
    }
  }

  Future<void> _openTagOptions(BuildContext context, String tag) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(tag),
        message: Text(
          'Used on ${controller.photoCountForTag(tag)} '
          '${controller.photoCountForTag(tag) == 1 ? 'photo' : 'photos'}',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, 'edit'),
            child: const Text('Edit Tag'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(sheetContext, 'delete'),
            child: const Text('Delete Permanently'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'edit') {
      await _renameTag(context, tag);
    } else if (action == 'delete') {
      await _confirmRemoveTag(context, tag);
    }
  }

  Future<void> _confirmRemoveTag(BuildContext context, String tag) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Tag Permanently?'),
        content: Text(
          'This will permanently delete "$tag" and remove it from all '
          '${controller.photoCountForTag(tag)} photos. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (remove != true) return;
    final removed = await controller.removeTagEverywhere(tag);
    if (!removed && context.mounted) {
      _showError(context, 'Could not remove the tag.');
    }
  }

  Future<String?> _showRenameDialog(
    BuildContext context, {
    required String title,
    required String currentName,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => ResponsiveBottomCenter(
        maxWidth: kSheetMaxWidth,
        child: _RenameItemSheet(title: title, currentName: currentName),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RenameItemSheet extends StatefulWidget {
  const _RenameItemSheet({required this.title, required this.currentName});

  final String title;
  final String currentName;

  @override
  State<_RenameItemSheet> createState() => _RenameItemSheetState();
}

class _RenameItemSheetState extends State<_RenameItemSheet> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.currentName);
    _textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.currentName.length,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _textController.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: scheme.surface.withAlpha(215),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withAlpha(85)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(35),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _textController,
                    autofocus: true,
                    maxLength: 128,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Text('Update'),
                        ),
                      ),
                    ],
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
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
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
                settings: const RouteSettings(name: 'Photo Viewer'),
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CollectionCard({
    required this.collection,
    required this.photos,
    required this.headers,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainer.withAlpha(190),
          child: InkWell(
            onTap: photos.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        settings: const RouteSettings(name: 'Photo Viewer'),
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
                    width: 72 * tabletScale(context),
                    height: 72 * tabletScale(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: photos.isEmpty
                          ? ColoredBox(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
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
                    onPressed: onEdit,
                    tooltip: 'Rename collection',
                    icon: Icon(Icons.edit_outlined, color: primaryColor),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    tooltip: 'Remove collection',
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

class _TagCard extends StatelessWidget {
  const _TagCard({
    required this.tag,
    required this.photoCount,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final String tag;
  final int photoCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer.withAlpha(190),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(CupertinoIcons.tag, color: primaryColor),
        title: Text(tag, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('$photoCount ${photoCount == 1 ? 'photo' : 'photos'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onEdit,
              tooltip: 'Rename tag everywhere',
              icon: Icon(Icons.edit_outlined, color: primaryColor),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: 'Delete tag permanently',
              icon: Icon(Icons.delete_outline_rounded, color: primaryColor),
            ),
          ],
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
        color: Theme.of(context).colorScheme.surfaceContainer.withAlpha(190),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
