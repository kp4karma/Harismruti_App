import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tilt/flutter_tilt.dart';
import 'package:get/get.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_filter_sheet.dart';
import 'package:harismruti/ui/view/home/home_section_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_string.dart';
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
      MaterialPageRoute(builder: (_) => HomeSectionDetailScreen(title: title)),
    );
  }

  bool _hasSectionDetailAction(String title) {
    return switch (title) {
      SmrutiSectionKeys.recent ||
      SmrutiSectionKeys.withSmruti ||
      SmrutiSectionKeys.ofDarshan ||
      SmrutiSectionKeys.location ||
      SmrutiSectionKeys.album ||
      SmrutiSectionKeys.ofSmruti ||
      SmrutiSectionKeys.yearCollection ||
      SmrutiSectionKeys.myPhotos ||
      SmrutiSectionKeys.myDiary ||
      SmrutiSectionKeys.myCollection ||
      SmrutiSectionKeys.myFavorite ||
      'Collection' ||
      'My Phone' ||
      'My Photos' ||
      'My Diray' ||
      'My Collectino' ||
      'My Favot' ||
      'My Favorites' => true,
      _ => false,
    };
  }
}
