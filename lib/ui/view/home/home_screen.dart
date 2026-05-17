import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tilt/flutter_tilt.dart';
import 'package:get/get.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/Profile/smruti_section_setting.dart';
import 'package:harismruti/ui/view/gallery/gallery_filter_sheet.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_string.dart';
import 'package:harismruti/widget/appbar/custom_appbar.dart';
import 'package:harismruti/widget/appbar/sub_header.dart';
import 'package:harismruti/widget/background/custom_background.dart';
import 'package:harismruti/widget/bottom_bar/bottom_bar.dart';
import 'package:url_launcher/url_launcher.dart';

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

  late AnimationController _appBarAnimationController;
  final StreamController<TiltStreamModel> streamController =
      StreamController<TiltStreamModel>.broadcast();

  @override
  void initState() {
    super.initState();

    // streamController.stream.listen((data) {
    //   debugPrint("Tilt updated via stream: ${data}");
    // });
    _appBarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
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
                    _hasVisibleSectionContent(section),
              )
              .toList()
            ..sort((a, b) => a['order_index'].compareTo(b['order_index']));
      final displaySections = sortedVisibleSections
          .take(sectionController.visibleCount.value)
          .toList();

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
                    ? kBottomNavigationBarHeight * 1.7
                    : 0,
                child: sectionController.showBottomBar.value
                    ? SwamiTabBar(
                        tabs: ["P.P.Prabodh Swamiji", "P.P.Hariprasad Swamiji"],
                        onTabSelected: (index) {},
                        onSearchTap: () => showGalleryFilterSheet(context),
                      )
                    : const SizedBox.shrink(),
              ),
              body: RefreshIndicator(
                color: primaryColor,
                onRefresh: galleryController.refreshHome,
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
                      ...displaySections.map(
                        (section) => Column(
                          children: [
                            SubHeader(
                              title: section['title'],
                              onTap: _openCustomizePreferences,
                            ),
                            section['widget'],
                          ],
                        ),
                      ),
                      const _VrundAppPromotion(),
                      const SizedBox(height: kBottomNavigationBarHeight),
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

  void _openCustomizePreferences() {
    if (!AuthRedirectHelper.ensureLoggedIn()) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SmrutiSectionSettingsScreen()),
    );
  }

  bool _hasVisibleSectionContent(Map<String, dynamic> section) {
    switch (section['title']) {
      case SmrutiSectionKeys.myFavorite:
      case 'My Favot':
      case 'My Favorites':
        return galleryController.favoritePhotoIds.isNotEmpty;
      case SmrutiSectionKeys.myCollection:
      case 'My Collectino':
        return galleryController.userCollections.isNotEmpty;
      default:
        return true;
    }
  }
}

class _VrundAppPromotion extends StatelessWidget {
  static const String _logoAsset = 'assets/vrund_app_logo.jpg';
  static final Uri _androidUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.suhradvrund&pcampaignid=web_share',
  );
  static final Uri _iosUri = Uri.parse(
    'https://apps.apple.com/in/app/hariprabodham-vrund/id6474902923',
  );

  const _VrundAppPromotion();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 380;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 22),
      padding: EdgeInsets.all(isCompact ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(236),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withAlpha(28)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withAlpha(18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isCompact ? 72 : 84,
                height: isCompact ? 72 : 84,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: primaryColor.withAlpha(18)),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withAlpha(18),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    _logoAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.play_circle_fill_rounded,
                      color: primaryColor,
                      size: 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hariprabodham Vrund',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Video and Audio Smruti with live pravachan updates.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black.withAlpha(166),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _PromoFeature(icon: Icons.videocam_rounded, label: 'Video'),
              _PromoFeature(icon: Icons.headphones_rounded, label: 'Audio'),
              _PromoFeature(icon: Icons.sensors_rounded, label: 'Live'),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackButtons = constraints.maxWidth < 330;

              final androidButton = _StoreButton(
                icon: Icons.android_rounded,
                label: 'Android App',
                onTap: () => _openStore(_androidUri),
              );
              final iosButton = _StoreButton(
                icon: Icons.phone_iphone_rounded,
                label: 'iOS App',
                onTap: () => _openStore(_iosUri),
              );

              if (stackButtons) {
                return Column(
                  children: [
                    androidButton,
                    const SizedBox(height: 8),
                    iosButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: androidButton),
                  const SizedBox(width: 8),
                  Expanded(child: iosButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static Future<void> _openStore(Uri uri) async {
    final didLaunch = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!didLaunch) {
      TopNotification.error(
        'Unable to open the app store link.',
        title: 'Hariprabodham Vrund',
      );
    }
  }
}

class _PromoFeature extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PromoFeature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: secondaryColor.withAlpha(22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: secondaryColor, size: 17),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StoreButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
