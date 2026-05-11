import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tilt/flutter_tilt.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/utils/app_color.dart';
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
          sectionController.sections.where((e) => e['is_show'] == true).toList()
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
                            SubHeader(title: section['title']),
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
}
