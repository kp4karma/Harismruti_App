import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_tilt/flutter_tilt.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/repositories/live_stream_repository.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/controller/my_photos_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_filter_sheet.dart';
import 'package:harismruti/ui/view/home/home_section_detail_screen.dart';
import 'package:harismruti/ui/view/home/live_stream_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_string.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/appbar/custom_appbar.dart';
import 'package:harismruti/widget/appbar/sub_header.dart';
import 'package:harismruti/widget/background/custom_background.dart';
import 'package:harismruti/widget/bottom_bar/bottom_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final SmrutiSectionController sectionController =
      Get.find<SmrutiSectionController>();
  final GalleryController galleryController = Get.find<GalleryController>();
  final MyPhotosController myPhotosController = Get.find<MyPhotosController>();
  final LiveStreamRepository _liveStreamRepository =
      const LiveStreamRepository();
  String? _liveStreamUrl;
  late bool _isLoggedIn;
  bool _isLoadingLiveStream = false;

  late AnimationController _appBarAnimationController;
  final StreamController<TiltStreamModel> streamController =
      StreamController<TiltStreamModel>.broadcast();

  @override
  void initState() {
    super.initState();
    _isLoggedIn = StorageHelper.isLogin();

    // streamController.stream.listen((data) {
    //   debugPrint("Tilt updated via stream: ${data}");
    // });
    _appBarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      myPhotosController.refreshSmrutiFlow();
      if (_isLoggedIn) _loadLiveStream();
    });
    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      final maxScroll = _scrollController.position.maxScrollExtent;
      sectionController.onHomeScroll(
        offset,
        maxScroll,
        _appBarAnimationController,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _appBarAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sortedVisibleSections =
          sectionController.sections
              .where(
                (section) =>
                    section['is_show'] == true &&
                    _hasHomeSectionContent(section['title'].toString()),
              )
              .toList()
            ..sort((a, b) => a['order_index'].compareTo(b['order_index']));
      final displaySections = sortedVisibleSections
          .take(sectionController.visibleCount.value)
          .toList();
      final bottomSystemInset = MediaQuery.of(context).viewPadding.bottom;
      final bottomContentPadding = sectionController.showBottomBar.value
          ? 96.0 + bottomSystemInset
          : 24.0 + bottomSystemInset;

      return CustomBackground(
        child: Center(
          child: Tilt(
            tiltStreamController: streamController,
            borderRadius: BorderRadius.circular(24),
            tiltConfig: TiltConfig(
              disable: false,
              enableGestureTouch: false,
              enableGestureHover: true,
              enableGestureSensors: true,
              sensorFactor: 30.0, // Increased
              enableSensorRevert: true,
              sensorRevertFactor: 0.07, // Smoother easing
              angle: 5,
            ),

            lightConfig: const LightConfig(
              minIntensity: 0.0,
              maxIntensity: 0.0,
            ),
            shadowConfig: ShadowConfig(color: Colors.white),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              extendBodyBehindAppBar: true,
              extendBody: true,
              appBar: CustomAppbar(isLoginAppbar: false),
              bottomNavigationBar: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: sectionController.showBottomBar.value
                    // Keep the controls at a stable height and reserve the
                    // device's navigation/gesture area separately.
                    ? 60 + bottomSystemInset
                    : 0,
                child: sectionController.showBottomBar.value
                    ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: SwamiTabBar(
                            tabs: [
                              "P.P.Prabodh Swamiji",
                              "P.P.Hariprasad Swamiji",
                            ],
                            initialIndex:
                                galleryController.selectedSwami.value.index,
                            onTabSelected: galleryController.selectSwami,
                            onSearchTap: () => showGalleryFilterSheet(context),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              body: RefreshIndicator(
                color: primaryColor,
                onRefresh: _refreshHome,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: Column(
                    children: [
                      sectionController.getVerticalSizeBox(),
                      SizedBox(
                        height:
                            kToolbarHeight + MediaQuery.of(context).padding.top,
                      ),
                      _LiveNowCard(
                        isLoading: _isLoadingLiveStream,
                        isLoggedIn: _isLoggedIn,
                        isLive: _liveStreamUrl != null,
                        onTap: _openLiveStream,
                      ),
                      ...displaySections.map(
                        (section) => Column(
                          children: [
                            SubHeader(
                              title: section['title'],
                              showAction: _hasSectionDetailAction(
                                section['title'].toString(),
                              ),
                              onTap: () => _openSectionDetails(
                                section['title'].toString(),
                              ),
                            ),
                            section['widget'],
                          ],
                        ),
                      ),
                      SizedBox(height: bottomContentPadding),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _refreshHome() async {
    await Future.wait([
      galleryController.refreshHome(),
      sectionController.refreshGlobalVisibility(),
      myPhotosController.refreshSmrutiFlow(),
      _refreshLiveStreamForAuth(),
    ]);
  }

  Future<void> _refreshLiveStreamForAuth() async {
    final isLoggedIn = StorageHelper.isLogin();
    if (mounted) {
      setState(() {
        _isLoggedIn = isLoggedIn;
        if (!isLoggedIn) _liveStreamUrl = null;
      });
    }
    if (isLoggedIn) await _loadLiveStream(forceRefresh: true);
  }

  Future<void> _loadLiveStream({bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoadingLiveStream = true);
    try {
      final url = await _liveStreamRepository.fetchLiveStreamUrl(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _liveStreamUrl = url;
          _isLoadingLiveStream = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (forceRefresh) _liveStreamUrl = null;
          _isLoadingLiveStream = false;
        });
      }
    }
  }

  Future<void> _openLiveStream() async {
    if (!_isLoggedIn) {
      AuthRedirectHelper.ensureLoggedIn();
      return;
    }
    if (_isLoadingLiveStream) return;

    if (_liveStreamUrl == null) {
      await _loadLiveStream(forceRefresh: true);
    }
    final url = _liveStreamUrl;
    if (!mounted) return;
    if (url == null) {
      TopNotification.error('Live stream is not available right now.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Live Stream'),
        builder: (_) => LiveStreamScreen(url: url),
      ),
    );
  }

  void _openSectionDetails(String title) {
    if (title == SmrutiSectionKeys.myPhotos ||
        title == SmrutiSectionKeys.myDiary ||
        title == SmrutiSectionKeys.myFavorite ||
        title == SmrutiSectionKeys.myCollection ||
        title == 'My Phone' ||
        title == 'My Photos' ||
        title == 'My Diray' ||
        title == 'My Favot' ||
        title == 'My Favorites' ||
        title == 'My Collectino') {
      if (!AuthRedirectHelper.ensureLoggedIn()) return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: title),
        builder: (_) => HomeSectionDetailScreen(title: title),
      ),
    );
  }

  bool _hasSectionDetailAction(String title) {
    if (title == SmrutiSectionKeys.myPhotos ||
        title == 'My Phone' ||
        title == 'My Photos') {
      // The arrow opens the matched-photo detail gallery. Hide it while the
      // user is uploading, waiting, rejected, fetching, or has no matches.
      return myPhotosController.hasMatchedSmruti;
    }

    return switch (title) {
      SmrutiSectionKeys.recent ||
      SmrutiSectionKeys.withSmruti ||
      SmrutiSectionKeys.ofDarshan ||
      SmrutiSectionKeys.location ||
      SmrutiSectionKeys.album ||
      SmrutiSectionKeys.ofSmruti ||
      SmrutiSectionKeys.yearCollection ||
      SmrutiSectionKeys.myDiary ||
      SmrutiSectionKeys.myCollection ||
      SmrutiSectionKeys.myFavorite ||
      'Collection' ||
      'My Diray' ||
      'My Collectino' ||
      'My Favot' ||
      'My Favorites' => true,
      _ => false,
    };
  }

  bool _hasHomeSectionContent(String title) {
    if (title == SmrutiSectionKeys.onThisDay) {
      return galleryController.onThisDayPhotos.isNotEmpty;
    }
    if (title == SmrutiSectionKeys.myFavorite ||
        title == 'My Favot' ||
        title == 'My Favorites') {
      return galleryController.favoritePhotos.isNotEmpty;
    }

    if (title == SmrutiSectionKeys.myCollection || title == 'My Collectino') {
      return galleryController.userCollections.isNotEmpty;
    }

    return true;
  }
}

class _LiveNowCard extends StatelessWidget {
  const _LiveNowCard({
    required this.onTap,
    required this.isLoading,
    required this.isLoggedIn,
    required this.isLive,
  });

  final VoidCallback onTap;
  final bool isLoading;
  final bool isLoggedIn;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withAlpha(82),
                  primaryColor.withAlpha(20),
                  Colors.white.withAlpha(48),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.live_tv_rounded,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Live Darshan',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: primaryColor.withAlpha(16),
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor.withAlpha(45)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                  ),
                  onPressed: isLoading ? null : onTap,
                  icon: isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
                          ),
                        )
                      : Icon(
                          !isLoggedIn
                              ? Icons.lock_outline_rounded
                              : isLive
                              ? Icons.play_arrow_rounded
                              : Icons.portable_wifi_off_rounded,
                          size: 20,
                        ),
                  label: Text(
                    isLoading
                        ? 'Checking'
                        : !isLoggedIn
                        ? 'Login Required'
                        : isLive
                        ? 'Live Now'
                        : 'Offline',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
