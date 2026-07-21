import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
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
      backgroundColor: const Color(0xFFF8F6F3),
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
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(CupertinoIcons.chevron_left, color: primaryColor),
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
        child: Container(color: Colors.white.withAlpha(125)),
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
                  decoration: const BoxDecoration(
                    backgroundBlendMode: BlendMode.dstOut,
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: [0.5, 0.7, 0.9, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.white24,
                        Colors.white,
                        Colors.white,
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
          color: Colors.white,
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
          for (final yearCard in years)
            _CollectionCollageCard(
              title: yearCard.title,
              photoCount: yearCard.count ?? yearCard.photos.length,
              locationCount: yearCard.locationCount,
              tagCount: yearCard.tagCount,
              photos: yearCard.photos,
              headers: headers,
              fallbackCoverUrl: yearCard.coverUrl,
              accent: const Color(0xFF823D3D),
              onTap: () =>
                  onYearSelected(int.tryParse(yearCard.value) ?? yearCard.id),
            ),
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
            return _CollectionCollageCard(
              title: bucket.title,
              photoCount: bucket.count,
              locationCount: bucket.locationCount,
              tagCount: bucket.tagCount,
              photos: bucket.photos,
              headers: headers,
              accent: _monthAccent(bucket.month ?? index + 1),
              onTap: () => onTap(bucket),
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

class _CollectionCollageCard extends StatelessWidget {
  final String title;
  final int photoCount;
  final int? locationCount;
  final int? tagCount;
  final List<GalleryPhoto> photos;
  final Map<String, String>? headers;
  final String? fallbackCoverUrl;
  final Color accent;
  final VoidCallback onTap;

  const _CollectionCollageCard({
    required this.title,
    required this.photoCount,
    required this.photos,
    required this.headers,
    required this.accent,
    required this.onTap,
    this.locationCount,
    this.tagCount,
    this.fallbackCoverUrl,
  });

  @override
  Widget build(BuildContext context) {
    final visiblePhotos = photos.isNotEmpty
        ? photos
        : [
            if (fallbackCoverUrl != null && fallbackCoverUrl!.isNotEmpty)
              GalleryPhoto(
                id: 0,
                thumbnailUrl: fallbackCoverUrl!,
                fullUrl: fallbackCoverUrl!,
              ),
          ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 226,
        margin: const EdgeInsets.only(bottom: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.transparent,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 4,
              right: 4,
              top: 0,
              bottom: 18,
              child: _CollectionPhotoRow(
                photos: visiblePhotos,
                headers: headers,
                seed: title.hashCode,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: _ImageGlowBehindTitle(
                photos: visiblePhotos,
                headers: headers,
                seed: title.hashCode,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: accent.withAlpha(18),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withAlpha(225),
                            Colors.white.withAlpha(168),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withAlpha(135)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _CollectionSummary(
                                  accent: accent,
                                  photoCount: photoCount,
                                  locationCount: locationCount ?? 0,
                                  tagCount: tagCount ?? 0,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 34,
                            width: 34,
                            decoration: BoxDecoration(
                              color: accent.withAlpha(20),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.chevron_right,
                              color: accent.withAlpha(190),
                              size: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageGlowBehindTitle extends StatelessWidget {
  final List<GalleryPhoto> photos;
  final Map<String, String>? headers;
  final int seed;

  const _ImageGlowBehindTitle({
    required this.photos,
    required this.headers,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    final photo = photos[seed.abs() % photos.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Opacity(
          opacity: 0.42,
          child: SizedBox(
            height: 74,
            child: NetworkImageWithLoader(
              imageUrl: photo.thumbnailUrl,
              title: photo.title ?? 'Smruti',
              headers: headers,
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionPhotoRow extends StatelessWidget {
  final List<GalleryPhoto> photos;
  final Map<String, String>? headers;
  final int seed;

  const _CollectionPhotoRow({
    required this.photos,
    required this.headers,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const GalleryShimmerBox(borderRadius: 18);
    }
    final tileCount = photos.length >= 4 ? 4 : photos.length;
    final ordered = List<GalleryPhoto>.generate(tileCount, (index) {
      final offset = seed.abs() % photos.length;
      return photos[(index + offset) % photos.length];
    });

    return Row(
      children: [
        for (var i = 0; i < ordered.length; i++) ...[
          Expanded(
            child: _CollectionPhotoTile(
              photo: ordered[i],
              headers: headers,
              radius: 18,
            ),
          ),
          if (i != ordered.length - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _CollectionSummary extends StatelessWidget {
  final Color accent;
  final int photoCount;
  final int locationCount;
  final int tagCount;

  const _CollectionSummary({
    required this.accent,
    required this.photoCount,
    required this.locationCount,
    required this.tagCount,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryItem(CupertinoIcons.photo_on_rectangle, '$photoCount Photos'),
      _SummaryItem(CupertinoIcons.location, '$locationCount Locations'),
      _SummaryItem(CupertinoIcons.tag, '$tagCount Tags'),
    ];
    return Wrap(
      spacing: 9,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: accent, size: 12),
              const SizedBox(width: 4),
              Text(
                item.label,
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _SummaryItem {
  final IconData icon;
  final String label;

  const _SummaryItem(this.icon, this.label);
}

class _CollectionPhotoTile extends StatelessWidget {
  final GalleryPhoto photo;
  final Map<String, String>? headers;
  final double radius;

  const _CollectionPhotoTile({
    required this.photo,
    required this.headers,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: const Color(0xFFF2E9E4),
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
    final spacing = crossAxisCount <= 2 ? 3.0 : 1.5;
    final aspectRatio = crossAxisCount == 1
        ? 1.25
        : crossAxisCount == 2
        ? 0.92
        : 1.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
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
                        color: Colors.black.withAlpha(230),
                        fontSize: crossAxisCount <= 2 ? 28 : 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.black.withAlpha(120),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: Colors.black.withAlpha(120),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          if (visiblePhotos.isEmpty)
            const GalleryShimmerBox(height: 150, borderRadius: 0)
          else
            GridView.builder(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: visiblePhotos.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: aspectRatio,
              ),
              itemBuilder: (context, index) {
                final photo = visiblePhotos[index];
                return GestureDetector(
                  onTap: onPhotoTap,
                  child: _TimelinePhotoTile(
                    photo: photo,
                    headers: headers,
                    large: crossAxisCount <= 2,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
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
      child: NetworkImageWithLoader(
        imageUrl: photo.thumbnailUrl,
        title: photo.title ?? 'Smruti',
        headers: headers,
      ),
    );
  }
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

Color _monthAccent(int month) {
  const colors = [
    Color(0xFF823D3D),
    Color(0xFF3F6C8F),
    Color(0xFF6F5AA8),
    Color(0xFF2E7D68),
    Color(0xFFB05F3C),
    Color(0xFF4E6E58),
    Color(0xFF8A4F74),
    Color(0xFF516B9E),
    Color(0xFF7A653F),
    Color(0xFF3E7775),
    Color(0xFF9A544C),
    Color(0xFF5F627A),
  ];
  if (month < 1 || month > 12) return colors.first;
  return colors[month - 1];
}

int _defaultColumnsFor(TimelineLevel level) {
  switch (level) {
    case TimelineLevel.year:
      return 9;
    case TimelineLevel.month:
      return 5;
    case TimelineLevel.day:
      return 3;
  }
}
