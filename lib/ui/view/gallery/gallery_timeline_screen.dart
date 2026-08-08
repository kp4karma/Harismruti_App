import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/widget/gallery/gallery_card_widgets.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

enum TimelineLevel { year, month, day }

class GalleryTimelineScreen extends StatefulWidget {
  final int? year;
  final int? month;
  final TimelineLevel? initialLevel;

  const GalleryTimelineScreen({
    super.key,
    this.year,
    this.month,
    this.initialLevel,
  });

  @override
  State<GalleryTimelineScreen> createState() => _GalleryTimelineScreenState();
}

class _GalleryTimelineScreenState extends State<GalleryTimelineScreen> {
  late TimelineLevel _level;
  late int? _year;
  late int? _month;
  bool _sortNewestFirst = true;
  int _crossAxisCount = 5;

  @override
  void initState() {
    super.initState();
    _year = widget.year;
    _month = widget.month;
    _level =
        widget.initialLevel ??
        (widget.month != null
            ? TimelineLevel.day
            : widget.year != null
            ? TimelineLevel.month
            : TimelineLevel.year);
    _crossAxisCount = _defaultColumnsFor(_level);
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = DateTime(_year ?? now.year, _month ?? now.month, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 1, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: primaryColor),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !context.mounted) return;

    setState(() {
      _year = picked.year;
      _month = picked.month;
      _level = TimelineLevel.day;
      _crossAxisCount = _defaultColumnsFor(TimelineLevel.day);
    });

    final controller = Get.find<GalleryController>();
    Navigator.push(
      context,
      CupertinoPageRoute(
        settings: const RouteSettings(name: 'Gallery Detail'),
        builder: (_) => GalleryDetailScreen(
          title: '${picked.day} ${_monthLabel(picked.month)} ${picked.year}',
          subtitle: 'Selected Date',
          loader: () => controller.loadPhotosForDay(
            year: picked.year,
            month: picked.month,
            day: picked.day,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GalleryController>();
    final title = _level == TimelineLevel.year
        ? 'Years'
        : _level == TimelineLevel.month
        ? (_year?.toString() ?? 'Months')
        : '${_monthLabel(_month ?? 1)} $_year';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      bottomNavigationBar: SafeArea(
        top: false,
        child: _TimelineBottomTools(
          sortNewestFirst: _sortNewestFirst,
          onDateTap: () => _pickDate(context),
          onSortChanged: (value) {
            setState(() => _sortNewestFirst = value);
          },
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            centerTitle: true,
            title: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(
                CupertinoIcons.chevron_left,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.onSurface
                    : primaryColor,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: const _TimelineHeaderGlass(),
          ),
          if (_level == TimelineLevel.year)
            SliverToBoxAdapter(
              child: Obx(() {
                final years = controller.collections.toList()
                  ..sort((a, b) {
                    final aYear = int.tryParse(a.value) ?? a.id;
                    final bYear = int.tryParse(b.value) ?? b.id;
                    return _sortNewestFirst
                        ? bYear.compareTo(aYear)
                        : aYear.compareTo(bYear);
                  });
                return _YearBoxList(
                  years: years,
                  headers: controller.imageHeaders,
                  onYearSelected: (year) {
                    setState(() {
                      _year = year;
                      _month = null;
                      _level = TimelineLevel.month;
                      _crossAxisCount = _defaultColumnsFor(TimelineLevel.month);
                    });
                  },
                );
              }),
            )
          else if (_level == TimelineLevel.month && _year != null)
            FutureBuilder<List<GalleryTimeBucket>>(
              future: controller.loadMonthsForYear(_year!),
              builder: (context, snapshot) {
                final months = [...snapshot.data ?? const <GalleryTimeBucket>[]]
                  ..sort((a, b) {
                    final aMonth = a.month ?? 0;
                    final bMonth = b.month ?? 0;
                    return _sortNewestFirst
                        ? bMonth.compareTo(aMonth)
                        : aMonth.compareTo(bMonth);
                  });
                return _BucketList(
                  buckets: months,
                  loading: snapshot.connectionState != ConnectionState.done,
                  headers: controller.imageHeaders,
                  crossAxisCount: _crossAxisCount,
                  onTap: (bucket) {
                    setState(() {
                      _month = bucket.month;
                      _level = TimelineLevel.day;
                      _crossAxisCount = _defaultColumnsFor(TimelineLevel.day);
                    });
                  },
                );
              },
            )
          else if (_level == TimelineLevel.day &&
              _year != null &&
              _month != null)
            FutureBuilder<List<GalleryTimeBucket>>(
              future: controller.loadDaysForMonth(year: _year!, month: _month!),
              builder: (context, snapshot) {
                final days = [...snapshot.data ?? const <GalleryTimeBucket>[]]
                  ..sort((a, b) {
                    final aDay = a.day ?? 0;
                    final bDay = b.day ?? 0;
                    return _sortNewestFirst
                        ? bDay.compareTo(aDay)
                        : aDay.compareTo(bDay);
                  });
                return _BucketList(
                  buckets: days,
                  loading: snapshot.connectionState != ConnectionState.done,
                  headers: controller.imageHeaders,
                  crossAxisCount: _crossAxisCount,
                  compactTitle: true,
                  onTap: (bucket) {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        settings: const RouteSettings(name: 'Gallery Detail'),
                        builder: (_) => GalleryDetailScreen(
                          title: '${bucket.day} ${_monthLabel(_month!)} $_year',
                          subtitle: '${bucket.count} Photos',
                          coverUrl: bucket.photos.isNotEmpty
                              ? bucket.photos.first.thumbnailUrl
                              : null,
                          loader: () => controller.loadPhotosForDay(
                            year: _year!,
                            month: _month!,
                            day: bucket.day ?? 1,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            )
          else
            const SliverToBoxAdapter(
              child: GalleryEmptyState(
                height: 260,
                message: 'Select a year first',
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
        ],
      ),
    );
  }
}

class _TimelineHeaderGlass extends StatelessWidget {
  const _TimelineHeaderGlass();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: Theme.of(context).colorScheme.surface.withAlpha(190),
        ),
      ),
    );
  }
}

class _TimelineBottomTools extends StatelessWidget {
  final bool sortNewestFirst;
  final VoidCallback onDateTap;
  final ValueChanged<bool> onSortChanged;

  const _TimelineBottomTools({
    required this.sortNewestFirst,
    required this.onDateTap,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kBottomNavigationBarHeight * 1.35,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    backgroundBlendMode: BlendMode.dstOut,
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: [0.5, 0.7, 0.9, 1.0],
                      colors: [
                        Colors.transparent,
                        Theme.of(context).colorScheme.surface.withAlpha(60),
                        Theme.of(context).colorScheme.surface,
                        Theme.of(context).colorScheme.surface,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: _ToolButton(
                    icon: CupertinoIcons.calendar,
                    label: 'Date',
                    onTap: onDateTap,
                  ),
                ),
                const SizedBox(width: 8),
                _SortToggle(
                  newestFirst: sortNewestFirst,
                  onChanged: onSortChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(14),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryColor),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortToggle extends StatelessWidget {
  final bool newestFirst;
  final ValueChanged<bool> onChanged;

  const _SortToggle({required this.newestFirst, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => const [
        PopupMenuItem(value: true, child: Text('Newest first')),
        PopupMenuItem(value: false, child: Text('Oldest first')),
      ],
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withAlpha(32),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.arrow_up_arrow_down, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              newestFirst ? 'New' : 'Old',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearBoxList extends StatelessWidget {
  final List<GalleryCard> years;
  final Map<String, String>? headers;
  final ValueChanged<int> onYearSelected;

  const _YearBoxList({
    required this.years,
    required this.headers,
    required this.onYearSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (years.isEmpty) {
      return const GalleryEmptyState(height: 260, message: 'No years found');
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
      child: Column(
        children: [
          for (final yearCard in years) ...[
            SizedBox(
              height: 255,
              child: GalleryMosaicCard(
                card: yearCard,
                headers: headers,
                width: double.infinity,
                overlappingTitle: true,
                onTap: () =>
                    onYearSelected(int.tryParse(yearCard.value) ?? yearCard.id),
              ),
            ),
            if (yearCard != years.last) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _BucketList extends StatelessWidget {
  final List<GalleryTimeBucket> buckets;
  final bool loading;
  final bool compactTitle;
  final Map<String, String>? headers;
  final int crossAxisCount;
  final ValueChanged<GalleryTimeBucket> onTap;

  const _BucketList({
    required this.buckets,
    required this.loading,
    required this.headers,
    required this.crossAxisCount,
    required this.onTap,
    this.compactTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SliverPadding(
        padding: EdgeInsets.all(16),
        sliver: _TimelineShimmer(),
      );
    }
    if (buckets.isEmpty) {
      return const SliverToBoxAdapter(
        child: GalleryEmptyState(height: 260, message: 'No smruti found'),
      );
    }
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(14, compactTitle ? 8 : 10, 14, 28),
      sliver: SliverList.builder(
        itemCount: buckets.length,
        itemBuilder: (context, index) {
          final bucket = buckets[index];
          if (!compactTitle) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SizedBox(
                height: 255,
                child: GalleryMosaicCard(
                  card: GalleryCard(
                    id: bucket.month ?? bucket.year,
                    title: bucket.title,
                    subtitle: '${bucket.count} Photos',
                    type: 'bucket',
                    value: '',
                    count: bucket.count,
                    locationCount: bucket.locationCount,
                    tagCount: bucket.tagCount,
                    photos: bucket.photos,
                  ),
                  headers: headers,
                  width: double.infinity,
                  overlappingTitle: true,
                  onTap: () => onTap(bucket),
                ),
              ),
            );
          }
          return _TimelinePhotoSection(
            title: compactTitle
                ? '${bucket.title} ${bucket.month == null ? '' : _monthLabel(bucket.month!)}'
                : bucket.title,
            subtitle: '${bucket.count} Photos',
            photos: bucket.photos,
            headers: headers,
            crossAxisCount: crossAxisCount,
            onHeaderTap: () => onTap(bucket),
            onPhotoTap: () => onTap(bucket),
          );
        },
      ),
    );
  }
}

class _TimelinePhotoSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<GalleryPhoto> photos;
  final Map<String, String>? headers;
  final int crossAxisCount;
  final VoidCallback onHeaderTap;
  final VoidCallback onPhotoTap;

  const _TimelinePhotoSection({
    required this.title,
    required this.subtitle,
    required this.photos,
    required this.headers,
    required this.crossAxisCount,
    required this.onHeaderTap,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    final visiblePhotos = photos;
    final compactPhone = MediaQuery.sizeOf(context).width < 600;
    final effectiveColumns = visiblePhotos.isEmpty
        ? 1
        : compactPhone
        ? _compactTimelineColumns(visiblePhotos.length, crossAxisCount)
        : crossAxisCount.clamp(1, visiblePhotos.length);
    final spacing = effectiveColumns <= 2 ? 4.0 : 2.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onHeaderTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: effectiveColumns <= 2 ? 24 : 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          if (visiblePhotos.isEmpty)
            const GalleryShimmerBox(height: 150, borderRadius: 0)
          else
            MasonryGridView.count(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: visiblePhotos.length,
              crossAxisCount: effectiveColumns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              itemBuilder: (context, index) {
                final photo = visiblePhotos[index];
                return AspectRatio(
                  aspectRatio: _timelinePhotoAspectRatio(photo, index),
                  child: GestureDetector(
                    onTap: onPhotoTap,
                    child: _TimelinePhotoTile(
                      photo: photo,
                      headers: headers,
                      large: effectiveColumns <= 2,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

int _compactTimelineColumns(int photoCount, int maximumColumns) {
  if (photoCount <= 1) return 1;
  if (photoCount == 3) return maximumColumns.clamp(1, 3);
  if (photoCount <= 6) return maximumColumns.clamp(1, 2);
  return maximumColumns.clamp(1, 3);
}

class _TimelinePhotoTile extends StatelessWidget {
  final GalleryPhoto photo;
  final Map<String, String>? headers;
  final bool large;

  const _TimelinePhotoTile({
    required this.photo,
    required this.headers,
    required this.large,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(large ? 14 : 4),
      child: ColoredBox(
        color: const Color(0xFFFFFFFF),
        child: NetworkImageWithLoader(
          imageUrl: photo.thumbnailUrl,
          title: photo.title ?? 'Smruti',
          headers: headers,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

double _timelinePhotoAspectRatio(GalleryPhoto photo, int index) {
  final width = photo.width;
  final height = photo.height;
  if (width != null && width > 0 && height != null && height > 0) {
    // Let the masonry grid follow the photo's real dimensions. Clamping this
    // ratio forces very tall or wide photos to be cropped by their tile.
    return width / height;
  }

  const fallbackRatios = [0.78, 1.2, 0.92, 1.35, 0.72, 1.0];
  return fallbackRatios[index % fallbackRatios.length];
}

class _TimelineShimmer extends StatelessWidget {
  const _TimelineShimmer();

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GalleryShimmerBox(
          height: index.isEven ? 210 : 168,
          borderRadius: 24,
        ),
      ),
    );
  }
}

String _monthLabel(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  if (month < 1 || month > 12) return month.toString();
  return months[month - 1];
}

int _defaultColumnsFor(TimelineLevel level) {
  final large = isLargeTabletDevice();
  final tablet = large || isTabletDevice();
  switch (level) {
    case TimelineLevel.year:
      return large ? 14 : (tablet ? 12 : 9);
    case TimelineLevel.month:
      return large ? 8 : (tablet ? 7 : 5);
    case TimelineLevel.day:
      return large ? 5 : (tablet ? 4 : 3);
  }
}
