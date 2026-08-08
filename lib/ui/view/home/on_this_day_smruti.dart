import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/api/repositories/gallery_repository.dart';
import 'package:harismruti/services/analytics_service.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/controller/my_photos_controller.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class OnThisDaySmruti extends StatefulWidget {
  const OnThisDaySmruti({super.key});

  @override
  State<OnThisDaySmruti> createState() => _OnThisDaySmrutiState();
}

class _OnThisDaySmrutiState extends State<OnThisDaySmruti> {
  Set<String> _viewedGroupKeys = <String>{};
  String? _activeStorageKey;
  Timer? _refreshTimer;
  bool _openFromNotification = false;
  bool _notificationOpenScheduled = false;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    _openFromNotification =
        arguments is Map && arguments['notification_screen'] == 'on_this_day';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _syncViewedState(GalleryController controller) {
    final refreshTimes =
        controller.sectionSetting('on_this_day')?.refreshTimes ?? ['05:00'];
    final cycle = _feedCycle(DateTime.now(), refreshTimes);
    final storageKey = '${controller.selectedSwami.value.apiValue}:$cycle';
    if (_activeStorageKey == storageKey) return;
    final stored = StorageHelper.getValue<Map>(
      key: StorageKeys.onThisDayViewedStories,
    );
    final values = stored?[storageKey];
    _activeStorageKey = storageKey;
    _viewedGroupKeys = values is List
        ? values.map((value) => value.toString()).toSet()
        : <String>{};
    _scheduleFeedRefresh(controller, refreshTimes);
  }

  void _scheduleFeedRefresh(
    GalleryController controller,
    List<String> refreshTimes,
  ) {
    _refreshTimer?.cancel();
    final now = DateTime.now();
    final slots = _dailyRefreshSlots(now, refreshTimes);
    var next = slots.firstWhere(
      (slot) => slot.isAfter(now),
      orElse: () => slots.first.add(const Duration(days: 1)),
    );
    _refreshTimer = Timer(next.difference(now), () async {
      if (!mounted) return;
      setState(() {
        _activeStorageKey = null;
        _viewedGroupKeys = <String>{};
      });
      await controller.refreshHome();
    });
  }

  void _markViewed(_StoryGroup group) {
    final storageKey = _activeStorageKey;
    if (storageKey == null || _viewedGroupKeys.contains(group.key)) return;
    setState(() => _viewedGroupKeys.add(group.key));
    final existing = StorageHelper.getValue<Map>(
      key: StorageKeys.onThisDayViewedStories,
    );
    final updated = <String, dynamic>{
      if (existing != null)
        ...existing.map((key, value) => MapEntry(key.toString(), value)),
      storageKey: _viewedGroupKeys.toList(),
    };
    if (updated.length > 6) {
      final oldestKeys = updated.keys.take(updated.length - 6).toList();
      for (final key in oldestKeys) {
        updated.remove(key);
      }
    }
    StorageHelper.setValue(
      key: StorageKeys.onThisDayViewedStories,
      value: updated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();
    return Obx(() {
      _syncViewedState(galleryController);
      final publicPhotos = galleryController.onThisDayPhotos;
      final mySmrutiPhotos = Get.isRegistered<MyPhotosController>()
          ? Get.find<MyPhotosController>().matchedPhotos.where(_isOnThisDay)
          : const Iterable<GalleryPhoto>.empty();
      final groups =
          _buildStoryGroups(
            publicPhotos: publicPhotos,
            mySmrutiPhotos: mySmrutiPhotos,
          )..sort((first, second) {
            final firstViewed = _viewedGroupKeys.contains(first.key);
            final secondViewed = _viewedGroupKeys.contains(second.key);
            return firstViewed == secondViewed ? 0 : (firstViewed ? 1 : -1);
          });
      if (groups.isEmpty) return const SizedBox.shrink();

      if (_openFromNotification && !_notificationOpenScheduled) {
        _notificationOpenScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || groups.isEmpty) return;
          _openStory(
            context,
            groups.first,
            galleryController,
            fromNotification: true,
          );
          _openFromNotification = false;
        });
      }

      final scale = tabletScale(context);
      return SizedBox(
        height: 132 * scale,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: groups.length,
          separatorBuilder: (_, _) => SizedBox(width: 16 * scale),
          itemBuilder: (context, index) => _StoryCircle(
            group: groups[index],
            isViewed: _viewedGroupKeys.contains(groups[index].key),
            headers: galleryController.imageHeaders,
            onTap: () => _openStory(context, groups[index], galleryController),
          ),
        ),
      );
    });
  }

  void _openStory(
    BuildContext context,
    _StoryGroup group,
    GalleryController controller, {
    bool fromNotification = false,
  }) {
    _markViewed(group);
    AnalyticsService.instance.track(
      'On This Day Story Opened',
      properties: {
        'category': group.label,
        'photo_count': group.photos.length,
        if (fromNotification) 'source': 'notification',
      },
    );
    Navigator.push(
      context,
      CupertinoPageRoute(
        settings: RouteSettings(name: 'On This Day ${group.label} Story'),
        builder: (_) => _OnThisDayStoryViewer(
          group: group,
          headers: controller.imageHeaders,
        ),
      ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  const _StoryCircle({
    required this.group,
    required this.headers,
    required this.onTap,
    required this.isViewed,
  });

  final _StoryGroup group;
  final Map<String, String>? headers;
  final VoidCallback onTap;
  final bool isViewed;

  @override
  Widget build(BuildContext context) {
    final scale = tabletScale(context);
    final circleSize = 82 * scale;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 92 * scale,
        child: Column(
          children: [
            Container(
              width: circleSize,
              height: circleSize,
              padding: EdgeInsets.all(3 * scale),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isViewed
                    ? const LinearGradient(
                        colors: [Color(0xFFB9B9B9), Color(0xFF777777)],
                      )
                    : LinearGradient(
                        colors: [
                          primaryColor,
                          const Color(0xFFE4A34C),
                          primaryColor.withAlpha(180),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: isViewed
                        ? Colors.black.withAlpha(18)
                        : primaryColor.withAlpha(35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Container(
                padding: EdgeInsets.all(3 * scale),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: ClipOval(
                  child: NetworkImageWithLoader(
                    imageUrl: group.photos.first.thumbnailUrl,
                    title: group.label,
                    headers: headers,
                  ),
                ),
              ),
            ),
            SizedBox(height: 7 * scale),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  group.icon,
                  color: isViewed ? Colors.grey.shade600 : primaryColor,
                  size: 12 * scale,
                ),
                SizedBox(width: 3 * scale),
                Flexible(
                  child: Text(
                    group.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isViewed
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w900,
                    ),
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

class _OnThisDayStoryViewer extends StatefulWidget {
  const _OnThisDayStoryViewer({required this.group, required this.headers});

  final _StoryGroup group;
  final Map<String, String>? headers;

  @override
  State<_OnThisDayStoryViewer> createState() => _OnThisDayStoryViewerState();
}

class _OnThisDayStoryViewerState extends State<_OnThisDayStoryViewer> {
  static const _storyDuration = Duration(seconds: 4);

  late final PageController _pageController;
  Timer? _timer;
  int _index = 0;
  bool _didPrecache = false;
  bool _isChangingPage = false;

  GalleryPhoto get _photo => widget.group.photos[_index];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scheduleNext();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecache) {
      _didPrecache = true;
      _precacheAround(0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = Timer(_storyDuration, _next);
  }

  Future<void> _next() async {
    if (_index >= widget.group.photos.length - 1) {
      Navigator.pop(context);
      return;
    }
    await _goTo(_index + 1);
  }

  void _previous() {
    if (_index > 0) unawaited(_goTo(_index - 1));
  }

  Future<void> _goTo(int index) async {
    if (_isChangingPage || index == _index) return;
    _isChangingPage = true;
    await _ensurePhotoReady(index);
    if (!mounted) return;
    _precacheAround(index);
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _isChangingPage = false;
  }

  Future<void> _ensurePhotoReady(int index) async {
    final url = widget.group.photos[index].fullUrl;
    if (url.isEmpty) return;
    try {
      await precacheImage(
        CachedNetworkImageProvider(url, headers: widget.headers),
        context,
      );
    } catch (_) {
      // The page retains its loader/error treatment if the request fails.
    }
  }

  void _precacheAround(int index) {
    final last = (index + 2).clamp(0, widget.group.photos.length - 1);
    for (var position = index; position <= last; position++) {
      final url = widget.group.photos[position].fullUrl;
      if (url.isEmpty) continue;
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(url, headers: widget.headers),
          context,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = _storyTags(_photo);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.group.photos.length,
            onPageChanged: (index) {
              setState(() => _index = index);
              _precacheAround(index);
              _scheduleNext();
            },
            itemBuilder: (context, index) => NetworkImageWithLoader(
              imageUrl: widget.group.photos[index].fullUrl,
              title: widget.group.label,
              headers: widget.headers,
              fit: BoxFit.contain,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(165),
                  Colors.transparent,
                  Colors.black.withAlpha(185),
                ],
                stops: const [0, 0.34, 1],
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _previous,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => unawaited(_next()),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (
                        var index = 0;
                        index < widget.group.photos.length;
                        index++
                      )
                        Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: index <= _index
                                  ? Colors.white
                                  : Colors.white.withAlpha(75),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(widget.group.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          widget.group.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.white.withAlpha(35),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.pop(context),
                          child: const SizedBox.square(
                            dimension: 42,
                            child: Icon(
                              CupertinoIcons.xmark,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    _contextLabel(widget.group.type, _photo),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (_photo.eventDate != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          color: Colors.white.withAlpha(215),
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatEventDate(_photo.eventDate!),
                          style: TextStyle(
                            color: Colors.white.withAlpha(225),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    SizedBox(
                      height: 30,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: tags.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (context, index) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(32),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: Colors.white.withAlpha(65),
                            ),
                          ),
                          child: Text(
                            '#${tags[index]}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    '${_index + 1} of ${widget.group.photos.length}',
                    style: TextStyle(
                      color: Colors.white.withAlpha(190),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _StoryType { mySmruti, location, darshan, withSmruti, smrutiOf }

class _StoryGroup {
  const _StoryGroup({
    required this.type,
    required this.label,
    required this.icon,
    required this.photos,
  });

  final _StoryType type;
  final String label;
  final IconData icon;
  final List<GalleryPhoto> photos;

  String get key => type.name;
}

String _feedCycle(DateTime now, List<String> refreshTimes) {
  final slots = _dailyRefreshSlots(now, refreshTimes);
  final elapsed = slots.where((slot) => !slot.isAfter(now)).toList();
  final cycle = elapsed.isNotEmpty
      ? elapsed.last
      : slots.last.subtract(const Duration(days: 1));
  return '${cycle.year.toString().padLeft(4, '0')}-'
      '${cycle.month.toString().padLeft(2, '0')}-'
      '${cycle.day.toString().padLeft(2, '0')}T'
      '${cycle.hour.toString().padLeft(2, '0')}:'
      '${cycle.minute.toString().padLeft(2, '0')}';
}

List<DateTime> _dailyRefreshSlots(DateTime day, List<String> refreshTimes) {
  final slots = <DateTime>[];
  for (final value in refreshTimes) {
    final parts = value.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts.first) : null;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (hour == null || minute == null || hour > 23 || minute > 59) continue;
    slots.add(DateTime(day.year, day.month, day.day, hour, minute));
  }
  if (slots.isEmpty) slots.add(DateTime(day.year, day.month, day.day, 5));
  slots.sort();
  return slots;
}

List<_StoryGroup> _buildStoryGroups({
  required Iterable<GalleryPhoto> publicPhotos,
  required Iterable<GalleryPhoto> mySmrutiPhotos,
}) {
  const storyLimit = 5;
  final usedPhotoKeys = <String>{};
  final groupsByType = <_StoryType, _StoryGroup>{};

  final mine = <GalleryPhoto>[];
  for (final photo in mySmrutiPhotos) {
    if (!usedPhotoKeys.add(_photoKey(photo))) continue;
    mine.add(photo);
    if (mine.length == storyLimit) break;
  }
  if (mine.isNotEmpty) {
    groupsByType[_StoryType.mySmruti] = _StoryGroup(
      type: _StoryType.mySmruti,
      label: 'My Smruti',
      icon: CupertinoIcons.person_crop_circle_fill,
      photos: mine,
    );
  }

  void buildDistinctPublicGroup({
    required _StoryType type,
    required String label,
    required IconData icon,
    required String? Function(GalleryPhoto) valueFor,
    bool requireDistinctValues = true,
  }) {
    final seenValues = <String>{};
    final selected = <GalleryPhoto>[];
    for (final photo in publicPhotos) {
      final value = valueFor(photo)?.trim() ?? '';
      if (value.isEmpty) continue;
      final valueKey = value.toLowerCase();
      final photoKey = _photoKey(photo);
      if ((requireDistinctValues && seenValues.contains(valueKey)) ||
          usedPhotoKeys.contains(photoKey)) {
        continue;
      }
      seenValues.add(valueKey);
      usedPhotoKeys.add(photoKey);
      selected.add(photo);
      if (selected.length == storyLimit) break;
    }
    if (selected.isEmpty) return;
    groupsByType[type] = _StoryGroup(
      type: type,
      label: label,
      icon: icon,
      photos: selected,
    );
  }

  // Specific metadata gets first choice. Location is the broad fallback,
  // preventing it from consuming every image before the other stories.
  buildDistinctPublicGroup(
    type: _StoryType.darshan,
    label: 'Darshan',
    icon: CupertinoIcons.person_2_fill,
    valueFor: (photo) => photo.darshanOf,
    requireDistinctValues: false,
  );
  buildDistinctPublicGroup(
    type: _StoryType.withSmruti,
    label: 'With',
    icon: CupertinoIcons.person_3_fill,
    valueFor: (photo) => photo.smrutiWith,
  );
  buildDistinctPublicGroup(
    type: _StoryType.smrutiOf,
    label: 'Smruti Of',
    icon: CupertinoIcons.sparkles,
    valueFor: (photo) => photo.smrutiOf,
  );
  buildDistinctPublicGroup(
    type: _StoryType.location,
    label: 'Location',
    icon: CupertinoIcons.location_solid,
    valueFor: (photo) =>
        _hasValue(photo.subLocation) ? photo.subLocation : photo.location,
  );

  const displayOrder = [
    _StoryType.mySmruti,
    _StoryType.location,
    _StoryType.darshan,
    _StoryType.withSmruti,
    _StoryType.smrutiOf,
  ];
  return displayOrder
      .map((type) => groupsByType[type])
      .whereType<_StoryGroup>()
      .toList(growable: false);
}

String _photoKey(GalleryPhoto photo) =>
    photo.id > 0 ? 'id:${photo.id}' : photo.thumbnailUrl;

bool _isOnThisDay(GalleryPhoto photo) {
  final date = photo.eventDate ?? photo.takenAt;
  final now = DateTime.now();
  return date != null &&
      date.year < now.year &&
      date.month == now.month &&
      date.day == now.day;
}

bool _hasValue(String? value) => value?.trim().isNotEmpty == true;

String _contextLabel(_StoryType type, GalleryPhoto photo) {
  return switch (type) {
    _StoryType.mySmruti => 'Your Smruti from this day',
    _StoryType.location =>
      photo.subLocation?.trim().isNotEmpty == true
          ? photo.subLocation!.trim()
          : photo.location?.trim().isNotEmpty == true
          ? photo.location!.trim()
          : 'Location',
    _StoryType.darshan => 'Darshan of ${photo.darshanOf ?? ''}',
    _StoryType.withSmruti => 'Smruti with ${photo.smrutiWith ?? ''}',
    _StoryType.smrutiOf => 'Smruti of ${photo.smrutiOf ?? ''}',
  };
}

String _formatEventDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day.toString().padLeft(2, '0')} '
      '${months[date.month - 1]} ${date.year}';
}

List<String> _storyTags(GalleryPhoto photo) {
  final seen = <String>{};
  return photo.tags
      .map((tag) => tag.trim().replaceFirst(RegExp(r'^#+'), ''))
      .where((tag) => tag.isNotEmpty && seen.add(tag.toLowerCase()))
      .toList(growable: false);
}
