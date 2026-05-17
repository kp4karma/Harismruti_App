import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/controller/my_diary_controller.dart';
import 'package:harismruti/ui/controller/my_photos_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/ui/view/gallery/gallery_filter_sheet.dart';
import 'package:harismruti/ui/view/gallery/gallery_location_screen.dart';
import 'package:harismruti/ui/view/gallery/gallery_timeline_screen.dart';
import 'package:harismruti/ui/view/home/my_diary_smruti.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_string.dart';
import 'package:harismruti/widget/appbar/detail_appbar.dart';
import 'package:harismruti/widget/gallery/gallery_card_widgets.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class HomeSectionDetailScreen extends StatefulWidget {
  final String title;

  const HomeSectionDetailScreen({super.key, required this.title});

  @override
  State<HomeSectionDetailScreen> createState() =>
      _HomeSectionDetailScreenState();
}

class _HomeSectionDetailScreenState extends State<HomeSectionDetailScreen> {
  final GalleryController _controller = Get.find<GalleryController>();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F3),
      appBar: DetailAppbar(title: widget.title),
      body: Obx(() {
        final items = _itemsForTitle(widget.title);
        final visibleItems = _filterItems(items);

        return Column(
          children: [
            _SearchFilterBar(
              controller: _searchController,
              onFilterTap: () => showGalleryFilterSheet(context),
            ),
            Expanded(
              child: visibleItems.isEmpty
                  ? const GalleryEmptyState(
                      height: 260,
                      message: 'No smruti found',
                    )
                  : _buildSectionBody(visibleItems),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSectionBody(List<Object> visibleItems) {
    final cards = visibleItems.whereType<GalleryCard>().toList(growable: false);
    switch (widget.title) {
      case SmrutiSectionKeys.withSmruti:
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => SizedBox(
            height: 255,
            child: GalleryWithFeatureCard(
              card: cards[index],
              headers: _controller.imageHeaders,
              width: double.infinity,
            ),
          ),
        );
      case SmrutiSectionKeys.ofSmruti:
        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, index) => GalleryCoverCard(
            card: cards[index],
            headers: _controller.imageHeaders,
            width: double.infinity,
            height: 230,
          ),
        );
      case SmrutiSectionKeys.location:
        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) => GalleryGridCard(
            card: cards[index],
            headers: _controller.imageHeaders,
          ),
        );
      case SmrutiSectionKeys.album:
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => SizedBox(
            height: 255,
            child: GalleryMosaicCard(
              card: cards[index],
              headers: _controller.imageHeaders,
              width: double.infinity,
            ),
          ),
        );
      case SmrutiSectionKeys.collections:
      case 'Collection':
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) => SizedBox(
            height: 250,
            child: GalleryCollectionCollageCard(
              card: cards[index],
              headers: _controller.imageHeaders,
              width: double.infinity,
            ),
          ),
        );
      case SmrutiSectionKeys.myFavorite:
      case 'My Favot':
      case 'My Favorites':
      case SmrutiSectionKeys.myPhotos:
      case 'My Phone':
      case 'My Photos':
        final photos = visibleItems.whereType<GalleryPhoto>().toList(
          growable: false,
        );
        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: photos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.74,
          ),
          itemBuilder: (context, index) => _PhotoPosterCard(
            photo: photos[index],
            headers: _controller.imageHeaders,
            onTap: () => _openPhotoGallery(photos, index),
          ),
        );
      case SmrutiSectionKeys.myCollection:
      case 'My Collectino':
        final collections = visibleItems
            .whereType<_UserCollectionItem>()
            .toList(growable: false);
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: collections.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _UserCollectionPosterCard(
            item: collections[index],
            headers: _controller.imageHeaders,
            onTap: () => _openUserCollection(collections[index]),
          ),
        );
      case SmrutiSectionKeys.myDiary:
      case 'My Diray':
        final entries = visibleItems.whereType<DiaryEntry>().toList(
          growable: false,
        );
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _DiaryEntryPosterCard(
            entry: entries[index],
            headers: _controller.imageHeaders,
            onTap: () => _openDiaryEntry(entries[index]),
          ),
        );
      default:
        return _buildSimpleCardList(visibleItems);
    }
  }

  Widget _buildSimpleCardList(List<Object> visibleItems) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: visibleItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = visibleItems[index];
        if (item is GalleryCard) {
          return _SectionCardTile(
            title: item.title,
            subtitle: item.subtitle.isNotEmpty
                ? item.subtitle
                : '${item.count ?? item.photos.length} Photos',
            imageUrl: item.coverUrl,
            headers: _controller.imageHeaders,
            onTap: () => _openCard(item),
          );
        }
        if (item is _UserCollectionItem) {
          return _SectionCardTile(
            title: item.title,
            subtitle: '${item.photos.length} Photos',
            imageUrl: item.coverUrl,
            headers: _controller.imageHeaders,
            onTap: () => _openUserCollection(item),
          );
        }
        if (item is DiaryEntry) {
          return _SectionCardTile(
            title: item.title,
            subtitle: _diarySubtitle(item),
            imageUrl: item.images.isEmpty ? '' : item.images.first,
            headers: _controller.imageHeaders,
            onTap: () => _openDiaryEntry(item),
          );
        }

        final photo = item as GalleryPhoto;
        return _SectionCardTile(
          title: photo.title ?? 'Smruti',
          subtitle: photo.subtitle ?? _formatDate(photo.takenAt),
          imageUrl: photo.thumbnailUrl,
          headers: _controller.imageHeaders,
          onTap: () => _openPhotoList(visibleItems),
        );
      },
    );
  }

  List<Object> _itemsForTitle(String title) {
    switch (title) {
      case SmrutiSectionKeys.recent:
        return _controller.recentPhotos.toList(growable: false);
      case SmrutiSectionKeys.collections:
      case 'Collection':
        return _controller.collections.toList(growable: false);
      case SmrutiSectionKeys.withSmruti:
        return _controller.smrutiWith.toList(growable: false);
      case SmrutiSectionKeys.ofSmruti:
        return _controller.smrutiOf.toList(growable: false);
      case SmrutiSectionKeys.location:
        return _controller.locations.toList(growable: false);
      case SmrutiSectionKeys.album:
        return _controller.albums.toList(growable: false);
      case SmrutiSectionKeys.myFavorite:
      case 'My Favot':
      case 'My Favorites':
        return _controller.favoritePhotos;
      case SmrutiSectionKeys.myCollection:
      case 'My Collectino':
        return _controller.userCollections
            .map(
              (collection) => _UserCollectionItem(
                title: collection.name,
                photos: _controller.photosForCollection(collection),
              ),
            )
            .toList(growable: false);
      case SmrutiSectionKeys.myDiary:
      case 'My Diray':
        if (!Get.isRegistered<MyDiaryController>()) return const [];
        return Get.find<MyDiaryController>().entries.toList(growable: false);
      case SmrutiSectionKeys.myPhotos:
      case 'My Phone':
      case 'My Photos':
        if (!Get.isRegistered<MyPhotosController>()) return const [];
        return Get.find<MyPhotosController>().matchedPhotos.toList(
          growable: false,
        );
      default:
        return const [];
    }
  }

  List<Object> _filterItems(List<Object> items) {
    if (_query.isEmpty) return items;
    return items
        .where((item) {
          final text = switch (item) {
            GalleryCard() => '${item.title} ${item.subtitle}',
            GalleryPhoto() => '${item.title ?? ''} ${item.subtitle ?? ''}',
            _UserCollectionItem() => item.title,
            DiaryEntry() => '${item.title} ${item.note} ${item.tags.join(' ')}',
            _ => '',
          };
          return text.toLowerCase().contains(_query);
        })
        .toList(growable: false);
  }

  void _openCard(GalleryCard card) {
    if (card.type == 'collection') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GalleryTimelineScreen()),
      );
      return;
    }

    if (card.type == 'location') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GalleryLocationScreen(card: card)),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GalleryDetailScreen.fromCard(card)),
    );
  }

  void _openUserCollection(_UserCollectionItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryDetailScreen(
          title: item.title,
          subtitle: '${item.photos.length} Photos',
          coverUrl: item.coverUrl,
          loader: () async => item.photos,
        ),
      ),
    );
  }

  void _openDiaryEntry(DiaryEntry entry) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) =>
            DiaryEntryDetailScreen(date: entry.date, entryId: entry.id),
      ),
    );
  }

  void _openPhotoList(List<Object> items) {
    final photos = items.whereType<GalleryPhoto>().toList(growable: false);
    _openPhotoGallery(photos, 0);
  }

  void _openPhotoGallery(List<GalleryPhoto> photos, int initialIndex) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => GalleryFullscreenViewer(
          photos: photos,
          initialIndex: initialIndex,
          title: widget.title,
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Photo';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _diarySubtitle(DiaryEntry entry) {
    final parts = [
      _formatDate(entry.date),
      if (entry.locationName?.trim().isNotEmpty == true) entry.locationName!,
      if (entry.tags.isNotEmpty) entry.tags.take(2).join(', '),
    ];
    return parts.join(' | ');
  }
}

class _SearchFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onFilterTap;

  const _SearchFilterBar({required this.controller, required this.onFilterTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search smruti',
                    prefixIcon: Icon(
                      CupertinoIcons.search,
                      color: primaryColor,
                    ),
                    filled: true,
                    fillColor: Colors.white.withAlpha(230),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCardTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final Map<String, String>? headers;
  final VoidCallback onTap;

  const _SectionCardTile({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 74,
                  height: 74,
                  child: imageUrl.isEmpty
                      ? ColoredBox(
                          color: primaryColor.withAlpha(18),
                          child: Icon(Icons.photo, color: primaryColor),
                        )
                      : NetworkImageWithLoader(
                          imageUrl: imageUrl,
                          title: title,
                          headers: headers,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF322318),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withAlpha(135),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPosterCard extends StatelessWidget {
  final GalleryPhoto photo;
  final Map<String, String>? headers;
  final VoidCallback onTap;

  const _PhotoPosterCard({
    required this.photo,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
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
            NetworkImageWithLoader(
              imageUrl: photo.thumbnailUrl,
              title: photo.title ?? 'Smruti',
              headers: headers,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(18),
                    Colors.black.withAlpha(135),
                  ],
                  stops: const [0.45, 0.72, 1],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                photo.title ?? 'Smruti',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCollectionPosterCard extends StatelessWidget {
  final _UserCollectionItem item;
  final Map<String, String>? headers;
  final VoidCallback onTap;

  const _UserCollectionPosterCard({
    required this.item,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.photos.isEmpty ? null : onTap,
      child: Container(
        height: 218,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
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
            if (item.coverUrl.isNotEmpty)
              NetworkImageWithLoader(
                imageUrl: item.coverUrl,
                title: item.title,
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
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
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
                          '${item.photos.length} photos',
                          style: TextStyle(
                            color: Colors.white.withAlpha(215),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryEntryPosterCard extends StatelessWidget {
  final DiaryEntry entry;
  final Map<String, String>? headers;
  final VoidCallback onTap;

  const _DiaryEntryPosterCard({
    required this.entry,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image = entry.images.isEmpty ? '' : entry.images.first;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 106,
              child: image.isEmpty
                  ? ColoredBox(
                      color: primaryColor.withAlpha(18),
                      child: Icon(CupertinoIcons.book, color: primaryColor),
                    )
                  : NetworkImageWithLoader(
                      imageUrl: image,
                      title: entry.title,
                      headers: headers,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF322318),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withAlpha(135),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(CupertinoIcons.chevron_right, color: primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCollectionItem {
  final String title;
  final List<GalleryPhoto> photos;

  const _UserCollectionItem({required this.title, required this.photos});

  String get coverUrl => photos.isEmpty ? '' : photos.first.thumbnailUrl;
}
