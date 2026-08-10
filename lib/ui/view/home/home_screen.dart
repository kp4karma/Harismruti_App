import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tilt/flutter_tilt.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/api_endpoints.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/api/repositories/gallery_repository.dart';
import 'package:harismruti/api/repositories/live_stream_repository.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/services/download_library_service.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/ui/controller/auth_controller.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/controller/my_photos_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/ui/view/gallery/ai_smruti_search_screen.dart';
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
import 'package:harismruti/widget/internet_status_widget.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final SmrutiSectionController sectionController =
      Get.find<SmrutiSectionController>();
  final GalleryController galleryController = Get.find<GalleryController>();
  final MyPhotosController myPhotosController = Get.find<MyPhotosController>();
  final AuthController authController = Get.find<AuthController>();
  final LiveStreamRepository _liveStreamRepository =
      const LiveStreamRepository();
  String? _liveStreamUrl;
  bool _isLoadingLiveStream = false;
  DateTime? _lastSectionSettingsRefresh;
  bool _sectionFillCheckScheduled = false;

  late AnimationController _appBarAnimationController;
  final StreamController<TiltStreamModel> streamController =
      StreamController<TiltStreamModel>.broadcast();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // streamController.stream.listen((data) {
    //   debugPrint("Tilt updated via stream: ${data}");
    // });
    _appBarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshWebPanelSections());
      myPhotosController.refreshSmrutiFlow();
      if (authController.isLoggedIn.value) _loadLiveStream();
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
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _appBarAnimationController.dispose();
    streamController.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshWebPanelSections());
    }
  }

  Future<void> _refreshWebPanelSections() async {
    final now = DateTime.now();
    if (_lastSectionSettingsRefresh != null &&
        now.difference(_lastSectionSettingsRefresh!) <
            const Duration(seconds: 2)) {
      return;
    }
    _lastSectionSettingsRefresh = now;

    final optionKey = galleryController.selectedSwami.value.apiValue;
    await sectionController.refreshGlobalVisibility(optionKey: optionKey);
    final settingsChanged = sectionController.consumeCacheRefresh(optionKey);
    // Always give the gallery controller a chance to invalidate yesterday's
    // snapshot when the app resumes across midnight.
    await galleryController.loadHome(force: settingsChanged);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoggedIn = authController.isLoggedIn.value;
      final sortedVisibleSections =
          sectionController.sections
              .where(
                (section) =>
                    section['is_show'] == true &&
                    _featureAllowsSection(section['title'].toString()) &&
                    (isLoggedIn ||
                        !_isLoginOnlySection(section['title'].toString())) &&
                    _hasHomeSectionContent(section['title'].toString()),
              )
              .toList()
            ..sort((a, b) => a['order_index'].compareTo(b['order_index']));
      final displaySections = sortedVisibleSections
          .take(sectionController.visibleCount.value)
          .toList();
      _scheduleSectionFillCheck(
        displayedCount: displaySections.length,
        totalCount: sortedVisibleSections.length,
      );
      final bottomSystemInset = MediaQuery.of(context).viewPadding.bottom;
      final bottomContentPadding = sectionController.showBottomBar.value
          ? 96.0 + bottomSystemInset
          : 24.0 + bottomSystemInset;
      final isDark = Theme.of(context).brightness == Brightness.dark;

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
              sensorFactor: 34.0,
              enableSensorRevert: true,
              sensorRevertFactor: 0.07, // Smoother easing
              angle: 6,
            ),

            lightConfig: const LightConfig(
              minIntensity: 0.0,
              maxIntensity: 0.0,
            ),
            shadowConfig: ShadowConfig(disable: isDark, color: Colors.white),
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
                              sectionController.optionLabels['prabodh'] ??
                                  'P.P.Prabodh Swamiji',
                              sectionController.optionLabels['hariprasad'] ??
                                  'P.P.Hariprasad Swamiji',
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
                      ValueListenableBuilder<bool>(
                        valueListenable: InternetStatusWidget.isConnected,
                        builder: (context, isConnected, _) => isConnected
                            ? const SizedBox.shrink()
                            : const _OfflineHomeCard(),
                      ),
                      ...displaySections.map(
                        (section) => _buildOrderedHomeSection(
                          section,
                          isLoggedIn: isLoggedIn,
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
      _refreshWebPanelSections(),
      myPhotosController.refreshSmrutiFlow(),
      _refreshLiveStreamForAuth(),
    ]);
  }

  void _scheduleSectionFillCheck({
    required int displayedCount,
    required int totalCount,
  }) {
    if (_sectionFillCheckScheduled || displayedCount >= totalCount) return;
    _sectionFillCheckScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sectionFillCheckScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;

      // Section batches used to advance only after a scroll notification. If
      // the current batch was shorter than the viewport, no notification was
      // generated and the home screen showed an empty gap until the user
      // dragged it. Fill another batch whenever the end is already visible.
      if (_scrollController.position.extentAfter <= 120) {
        sectionController.increaseVisibleCount();
      }
    });
  }

  Widget _buildOrderedHomeSection(
    Map<String, dynamic> section, {
    required bool isLoggedIn,
  }) {
    final title = section['title'].toString();
    if (title == SmrutiSectionKeys.liveDarshan) {
      return _LiveNowCard(
        isLoading: _isLoadingLiveStream,
        isLoggedIn: isLoggedIn,
        isLive: _liveStreamUrl != null,
        onTap: _openLiveStream,
      );
    }
    if (title == SmrutiSectionKeys.aiSearch) {
      return _AiSearchCard(onTap: _openAiSearch);
    }
    if (title == SmrutiSectionKeys.downloads) {
      return const _EnhancedDownloadsSection();
    }
    final displayName = section['display_name']?.toString().trim();
    return Column(
      children: [
        SubHeader(
          title: displayName?.isNotEmpty == true ? displayName! : title,
          showAction: _hasSectionDetailAction(title),
          onTap: () => _openSectionDetails(title),
        ),
        section['widget'],
      ],
    );
  }

  bool _featureAllowsSection(String title) {
    final key = switch (title) {
      SmrutiSectionKeys.aiSearch => 'ai_search',
      SmrutiSectionKeys.liveDarshan => 'live_darshan',
      // Downloads also contains originals saved by the user, so it must not
      // disappear when AI enhancement is disabled.
      SmrutiSectionKeys.downloads => null,
      SmrutiSectionKeys.myPhotos => 'my_smruti',
      SmrutiSectionKeys.myDiary => 'my_diary',
      _ => null,
    };
    return key == null || sectionController.isFeatureEnabled(key);
  }

  Future<void> _refreshLiveStreamForAuth() async {
    final isLoggedIn = StorageHelper.isLogin();
    if (mounted) {
      setState(() {
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
    if (!authController.isLoggedIn.value) {
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

  void _openAiSearch() {
    if (!AuthRedirectHelper.ensureLoggedIn()) return;
    Navigator.push(
      context,
      CupertinoPageRoute<void>(
        settings: const RouteSettings(name: 'AI Smruti Search'),
        builder: (_) => const AiSmrutiSearchScreen(),
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
      // Keep the section visible so its designed empty state can explain when
      // the next admin-configured story refresh will provide new memories.
      return true;
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

  bool _isLoginOnlySection(String title) {
    return title == SmrutiSectionKeys.aiSearch ||
        title == SmrutiSectionKeys.myPhotos ||
        title == SmrutiSectionKeys.myDiary ||
        title == SmrutiSectionKeys.myFavorite ||
        title == SmrutiSectionKeys.myCollection ||
        title == 'My Phone' ||
        title == 'My Photos' ||
        title == 'My Diray' ||
        title == 'My Favot' ||
        title == 'My Favorites' ||
        title == 'My Collectino';
  }
}

class _OfflineHomeCard extends StatelessWidget {
  const _OfflineHomeCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withAlpha(235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.wifi_slash, color: primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No internet connection',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You can continue browsing photos already saved on this device.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnhancedDownloadsSection extends StatefulWidget {
  const _EnhancedDownloadsSection();

  @override
  State<_EnhancedDownloadsSection> createState() =>
      _EnhancedDownloadsSectionState();
}

class _EnhancedDownloadsSectionState extends State<_EnhancedDownloadsSection>
    with WidgetsBindingObserver {
  final GalleryRepository _repository = const GalleryRepository();
  List<GalleryPhoto> _photos = const [];
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DownloadLibraryService.revision.addListener(_handleLibraryChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    DownloadLibraryService.revision.removeListener(_handleLibraryChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  void _handleLibraryChanged() => unawaited(_load());

  Future<void> _load() async {
    final request = ++_loadRequest;
    final originals = DownloadLibraryService.savedOriginals;
    if (mounted) setState(() => _photos = originals);
    try {
      final items = await _repository.getReadyPhotoEnhancements();
      if (!mounted || request != _loadRequest) return;
      final enhancements = items
          .map(_enhancedPhotoFor)
          .whereType<GalleryPhoto>();
      final byUrl = <String, GalleryPhoto>{};
      for (final photo in [...enhancements, ...originals]) {
        byUrl.putIfAbsent(photo.fullUrl, () => photo);
      }
      setState(() => _photos = byUrl.values.toList(growable: false));
    } catch (_) {
      // Saved originals remain available if the enhancement API is offline.
    }
  }

  GalleryPhoto? _enhancedPhotoFor(Map<String, dynamic> item) {
    final jobId = int.tryParse('${item['id']}');
    final photoId = int.tryParse('${item['photo_id']}');
    if (jobId == null || photoId == null) return null;
    final enhancedUrl = ApiEndpoints.photoEnhancementDownload(jobId);
    return GalleryPhoto(
      id: photoId,
      thumbnailUrl: enhancedUrl,
      fullUrl: enhancedUrl,
    );
  }

  void _openPhoto(int index) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        settings: const RouteSettings(name: 'Photo Viewer'),
        builder: (_) => GalleryFullscreenViewer(
          photos: _photos,
          initialIndex: index,
          title: 'Downloads',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_photos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubHeader(title: 'Downloads', onTap: () => _openPhoto(0)),
        SizedBox(
          height: 126,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openPhoto(index),
                child: SizedBox(
                  width: 82,
                  height: 126,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: NetworkImageWithLoader(
                      imageUrl: _photos[index].thumbnailUrl,
                      title: 'Download',
                      headers: _repository.imageHeaders,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _AiSearchCard extends StatelessWidget {
  const _AiSearchCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withAlpha(24),
                  scheme.surface.withAlpha(210),
                  const Color(0xFFE7A46B).withAlpha(24),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: primaryColor.withAlpha(34)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, const Color(0xFFE7A46B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withAlpha(45),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.sparkles,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'AI Smruti Search',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ask or speak to find any smruti',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.arrow_up_right,
                    color: primaryColor,
                    size: 17,
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFFFFB59F) : primaryColor;
    final statusColor = isLive && isLoggedIn
        ? (isDark ? const Color(0xFFFF7D72) : const Color(0xFFC73C32))
        : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        scheme.surfaceContainerHigh.withAlpha(225),
                        const Color(0xFF3A2421).withAlpha(205),
                        scheme.surfaceContainer.withAlpha(220),
                      ]
                    : [
                        Colors.white.withAlpha(105),
                        primaryColor.withAlpha(22),
                        Colors.white.withAlpha(68),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(22)
                    : primaryColor.withAlpha(24),
              ),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(55),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF663D35), const Color(0xFF402824)]
                          : [
                              primaryColor.withAlpha(25),
                              primaryColor.withAlpha(10),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withAlpha(45)),
                  ),
                  child: Icon(Icons.live_tv_rounded, color: accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Darshan',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLive && isLoggedIn
                            ? 'Darshan is streaming now'
                            : 'Check the current broadcast',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: statusColor.withAlpha(isDark ? 30 : 18),
                    foregroundColor: statusColor,
                    disabledBackgroundColor: scheme.surfaceContainerHighest,
                    disabledForegroundColor: scheme.onSurfaceVariant,
                    side: BorderSide(color: statusColor.withAlpha(65)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isLoading ? null : onTap,
                  icon: isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accent,
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
