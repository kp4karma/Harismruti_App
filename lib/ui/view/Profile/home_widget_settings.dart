import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/services/phone_smruti_widget_service.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/widget/appbar/detail_appbar.dart';
import 'package:harismruti/widget/background/custom_background.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class HomeWidgetSettingsScreen extends StatefulWidget {
  const HomeWidgetSettingsScreen({super.key});

  @override
  State<HomeWidgetSettingsScreen> createState() =>
      _HomeWidgetSettingsScreenState();
}

class _HomeWidgetSettingsScreenState extends State<HomeWidgetSettingsScreen> {
  int? _addingIndex;

  static const _designs = [
    (
      'Photo Grid',
      'Responsive gallery of recent Smrutis',
      Icons.grid_view_rounded,
      'SmrutiHomeWidgetProvider',
    ),
    (
      'Daily Darshan',
      'One peaceful full-size daily photo',
      Icons.image_rounded,
      'DailyDarshanWidgetProvider',
    ),
    (
      'Smruti Stories',
      'Story-style row for quick memories',
      Icons.auto_awesome_motion_rounded,
      'SmrutiStoriesWidgetProvider',
    ),
    (
      'Featured + Recent',
      'One featured photo with recent moments',
      Icons.dashboard_customize_rounded,
      'FeaturedRecentWidgetProvider',
    ),
    (
      'Minimal Smruti',
      'Compact photo, title and date',
      Icons.crop_landscape_rounded,
      'MinimalSmrutiWidgetProvider',
    ),
  ];

  Future<void> _add(int index) async {
    if (_addingIndex != null) return;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    setState(() => _addingIndex = index);
    try {
      final gallery = Get.find<GalleryController>();
      if (gallery.recentPhotos.isEmpty) await gallery.loadHome(force: true);
      final settings = Get.find<SmrutiSectionController>();
      final photos = _photosForDesign(gallery, index);
      await PhoneSmrutiWidgetService.prepareAndAdd(
        photos: photos,
        imageHeaders: gallery.imageHeaders,
        storyCount: settings.smrutiStoryCount.value,
        refreshHours: settings.smrutiStoryRefreshHours.value,
        providerName: _designs[index].$4,
      );
      TopNotification.success(
        isIOS
            ? '${_designs[index].$1} is ready. Long-press the iPhone Home Screen, tap +, then choose HariSmruti.'
            : 'Choose where to place ${_designs[index].$1}.',
      );
    } on PlatformException catch (error) {
      TopNotification.error(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Unable to add this widget. You can add it from the Home screen widget picker.',
      );
    } catch (error) {
      TopNotification.error(
        error.toString().replaceFirst('Unsupported operation: ', ''),
      );
    } finally {
      if (mounted) setState(() => _addingIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gallery = Get.find<GalleryController>();
    return CustomBackground(
      child: Scaffold(
        appBar: DetailAppbar(
          title: 'Home Screen Widgets',
          onBackTap: () => Navigator.pop(context),
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _designs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final design = _designs[index];
            return Card(
              elevation: 7,
              shadowColor: Colors.black.withAlpha(36),
              surfaceTintColor: Colors.white,
              color: Colors.white,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Obx(
                      () => _HomeWidgetPreview(
                        styleIndex: index,
                        photos: _photosForDesign(gallery, index),
                        imageHeaders: gallery.imageHeaders,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: primaryColor.withAlpha(24),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(design.$3, color: primaryColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                design.$1,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                design.$2,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _addingIndex == null
                              ? () => _add(index)
                              : null,
                          child: _addingIndex == index
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<GalleryPhoto> _photosForDesign(GalleryController gallery, int index) {
    final source = switch (index) {
      1 =>
        gallery.onThisDayPhotos.isNotEmpty
            ? gallery.onThisDayPhotos
            : gallery.recentPhotos,
      2 =>
        gallery.smrutiWith.isNotEmpty
            ? gallery.smrutiWith.expand((card) => card.photos)
            : gallery.recentPhotos,
      4 =>
        gallery.favoritePhotos.isNotEmpty
            ? gallery.favoritePhotos
            : gallery.recentPhotos,
      _ => gallery.recentPhotos,
    };
    final all = source
        .where((photo) => photo.thumbnailUrl.isNotEmpty)
        .toList(growable: false);
    final wantsPortrait = index == 2;
    final preferred = all
        .where((photo) {
          final width = photo.width ?? 0;
          final height = photo.height ?? 0;
          if (width <= 0 || height <= 0) return false;
          return wantsPortrait ? height > width : width >= height;
        })
        .toList(growable: false);
    return (preferred.isNotEmpty ? preferred : all).take(8).toList();
  }
}

class _HomeWidgetPreview extends StatelessWidget {
  const _HomeWidgetPreview({
    required this.styleIndex,
    required this.photos,
    required this.imageHeaders,
  });

  final int styleIndex;
  final List<GalleryPhoto> photos;
  final Map<String, String> imageHeaders;

  GalleryPhoto? _photo(int index) =>
      photos.isEmpty ? null : photos[index % photos.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: styleIndex == 4 ? 78 : 112,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: switch (styleIndex) {
        0 => Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _PreviewTile(
                      photo: _photo(0),
                      headers: imageHeaders,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: _PreviewTile(
                      photo: _photo(1),
                      headers: imageHeaders,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _PreviewTile(
                      photo: _photo(2),
                      headers: imageHeaders,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: _PreviewTile(
                      photo: _photo(3),
                      headers: imageHeaders,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        1 => _PreviewTile(
          photo: _photo(0),
          headers: imageHeaders,
          showCaption: true,
        ),
        2 => Row(
          children: [
            for (var index = 0; index < 4; index++) ...[
              Expanded(
                child: _PreviewTile(
                  photo: _photo(index),
                  headers: imageHeaders,
                  round: true,
                ),
              ),
              if (index != 3) const SizedBox(width: 3),
            ],
          ],
        ),
        3 => Row(
          children: [
            Expanded(
              flex: 2,
              child: _PreviewTile(
                photo: _photo(0),
                headers: imageHeaders,
                showCaption: true,
              ),
            ),
            SizedBox(width: 3),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _PreviewTile(
                      photo: _photo(1),
                      headers: imageHeaders,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Expanded(
                    child: _PreviewTile(
                      photo: _photo(2),
                      headers: imageHeaders,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        _ => Row(
          children: [
            SizedBox(
              width: 74,
              child: _PreviewTile(photo: _photo(0), headers: imageHeaders),
            ),
            const SizedBox(width: 10),
            const Expanded(child: _PreviewText()),
          ],
        ),
      },
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.photo,
    required this.headers,
    this.showCaption = false,
    this.round = false,
  });

  final GalleryPhoto? photo;
  final Map<String, String> headers;
  final bool showCaption;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(round ? 40 : 11),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo != null)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
              child: Image.network(
                photo!.thumbnailUrl,
                headers: headers,
                fit: BoxFit.cover,
                color: Colors.black.withAlpha(55),
                colorBlendMode: BlendMode.darken,
              ),
            )
          else
            GalleryShimmerBox(borderRadius: round ? 40 : 11),
          if (photo != null)
            Padding(
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(round ? 38 : 9),
                child: NetworkImageWithLoader(
                  imageUrl: photo!.thumbnailUrl,
                  title: photo!.title ?? 'Smruti',
                  headers: headers,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          if (showCaption)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(80),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(11),
                  ),
                ),
                child: const Text(
                  'Today’s Smruti',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewText extends StatelessWidget {
  const _PreviewText();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HariPrabodham Smruti',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        GalleryShimmerBox(height: 5, width: 100, borderRadius: 4),
        const SizedBox(height: 5),
        GalleryShimmerBox(height: 5, width: 64, borderRadius: 4),
      ],
    );
  }
}
