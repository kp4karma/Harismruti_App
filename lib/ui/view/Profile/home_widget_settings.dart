import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/services/phone_smruti_widget_service.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/widget/appbar/detail_appbar.dart';
import 'package:harismruti/widget/background/custom_background.dart';

class HomeWidgetSettingsScreen extends StatefulWidget {
  const HomeWidgetSettingsScreen({super.key});

  @override
  State<HomeWidgetSettingsScreen> createState() =>
      _HomeWidgetSettingsScreenState();
}

class _HomeWidgetSettingsScreenState extends State<HomeWidgetSettingsScreen> {
  int? _addingIndex;

  static const _designs = [
    ('Photo Grid', 'Responsive gallery of recent Smrutis', Icons.grid_view_rounded, 'SmrutiHomeWidgetProvider'),
    ('Daily Darshan', 'One peaceful full-size daily photo', Icons.image_rounded, 'DailyDarshanWidgetProvider'),
    ('Smruti Stories', 'Story-style row for quick memories', Icons.auto_awesome_motion_rounded, 'SmrutiStoriesWidgetProvider'),
    ('Featured + Recent', 'One featured photo with recent moments', Icons.dashboard_customize_rounded, 'FeaturedRecentWidgetProvider'),
    ('Minimal Smruti', 'Compact photo, title and date', Icons.crop_landscape_rounded, 'MinimalSmrutiWidgetProvider'),
  ];

  Future<void> _add(int index) async {
    if (_addingIndex != null) return;
    setState(() => _addingIndex = index);
    try {
      final gallery = Get.find<GalleryController>();
      if (gallery.recentPhotos.isEmpty) await gallery.loadHome(force: true);
      final settings = Get.find<SmrutiSectionController>();
      await PhoneSmrutiWidgetService.prepareAndAdd(
        photos: gallery.recentPhotos.toList(growable: false),
        imageHeaders: gallery.imageHeaders,
        storyCount: settings.smrutiStoryCount.value,
        refreshHours: settings.smrutiStoryRefreshHours.value,
        providerName: _designs[index].$4,
      );
      TopNotification.success('Choose where to place ${_designs[index].$1}.');
    } catch (error) {
      TopNotification.error(error.toString().replaceFirst('Unsupported operation: ', ''));
    } finally {
      if (mounted) setState(() => _addingIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: Scaffold(
        appBar: DetailAppbar(
          title: 'Home Screen Widgets',
          onBackTap: () => Navigator.pop(context),
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _designs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final design = _designs[index];
            return Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainer.withAlpha(235),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: primaryColor.withAlpha(24),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(design.$3, color: primaryColor, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(design.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(design.$2, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: _addingIndex == null ? () => _add(index) : null,
                      child: _addingIndex == index
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Add'),
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
}
