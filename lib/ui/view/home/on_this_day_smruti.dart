import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/services/analytics_service.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/controller/my_photos_controller.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class OnThisDaySmruti extends StatelessWidget {
  const OnThisDaySmruti({super.key});

  @override
  Widget build(BuildContext context) {
    final galleryController = Get.find<GalleryController>();
    return Obx(() {
      final publicPhotos = galleryController.onThisDayPhotos;
      final mySmrutiPhotos = Get.isRegistered<MyPhotosController>()
          ? Get.find<MyPhotosController>().matchedPhotos.where(_isOnThisDay)
          : const Iterable<GalleryPhoto>.empty();
      final groups = _buildStoryGroups(
        publicPhotos: publicPhotos,
        mySmrutiPhotos: mySmrutiPhotos,
      );
      if (groups.isEmpty) return const SizedBox.shrink();

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
            headers: galleryController.imageHeaders,
            onTap: () {
              AnalyticsService.instance.track(
                'On This Day Story Opened',
                properties: {
                  'category': groups[index].label,
                  'photo_count': groups[index].photos.length,
                },
              );
              Navigator.push(
                context,
                CupertinoPageRoute(
                  settings: RouteSettings(
                    name: 'On This Day ${groups[index].label} Story',
                  ),
                  builder: (_) => _OnThisDayStoryViewer(
                    group: groups[index],
                    headers: galleryController.imageHeaders,
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }
}

class _StoryCircle extends StatelessWidget {
  const _StoryCircle({
    required this.group,
    required this.headers,
    required this.onTap,
  });

  final _StoryGroup group;
  final Map<String, String>? headers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = tabletScale(context);
    final circleSize = 82 * scale;
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
                gradient: LinearGradient(
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
                    color: primaryColor.withAlpha(35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Container(
                padding: EdgeInsets.all(3 * scale),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      NetworkImageWithLoader(
                        imageUrl: group.photos.first.thumbnailUrl,
                        title: group.label,
                        headers: headers,
                      ),
                      Positioned(
                        right: 3,
                        bottom: 3,
                        child: Container(
                          width: 24 * scale,
                          height: 24 * scale,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            group.icon,
                            color: Colors.white,
                            size: 12 * scale,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 7 * scale),
            Text(
              group.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF2B211B),
                fontSize: 12 * scale,
                fontWeight: FontWeight.w900,
              ),
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

  GalleryPhoto get _photo => widget.group.photos[_index];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scheduleNext();
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

  void _next() {
    if (_index >= widget.group.photos.length - 1) {
      Navigator.pop(context);
      return;
    }
    _goTo(_index + 1);
  }

  void _previous() {
    if (_index > 0) _goTo(_index - 1);
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    onTap: _next,
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
}

List<_StoryGroup> _buildStoryGroups({
  required Iterable<GalleryPhoto> publicPhotos,
  required Iterable<GalleryPhoto> mySmrutiPhotos,
}) {
  List<GalleryPhoto> takeTen(Iterable<GalleryPhoto> photos) =>
      photos.take(10).toList(growable: false);

  final groups = <_StoryGroup>[];
  final mine = takeTen(mySmrutiPhotos);
  if (mine.isNotEmpty) {
    groups.add(
      _StoryGroup(
        type: _StoryType.mySmruti,
        label: 'My Smruti',
        icon: CupertinoIcons.person_crop_circle_fill,
        photos: mine,
      ),
    );
  }

  void addPublicGroup({
    required _StoryType type,
    required String label,
    required IconData icon,
    required bool Function(GalleryPhoto) include,
  }) {
    final photos = takeTen(publicPhotos.where(include));
    if (photos.isEmpty) return;
    groups.add(
      _StoryGroup(type: type, label: label, icon: icon, photos: photos),
    );
  }

  addPublicGroup(
    type: _StoryType.location,
    label: 'Location',
    icon: CupertinoIcons.location_solid,
    include: (photo) =>
        _hasValue(photo.location) || _hasValue(photo.subLocation),
  );
  addPublicGroup(
    type: _StoryType.darshan,
    label: 'Darshan',
    icon: CupertinoIcons.person_2_fill,
    include: (photo) => _hasValue(photo.darshanOf),
  );
  addPublicGroup(
    type: _StoryType.withSmruti,
    label: 'With',
    icon: CupertinoIcons.person_3_fill,
    include: (photo) => _hasValue(photo.smrutiWith),
  );
  addPublicGroup(
    type: _StoryType.smrutiOf,
    label: 'Smruti Of',
    icon: CupertinoIcons.sparkles,
    include: (photo) => _hasValue(photo.smrutiOf),
  );
  return groups;
}

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
