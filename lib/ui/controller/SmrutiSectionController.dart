import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/ui/view/home/album_smruti.dart';
import 'package:harismruti/ui/view/home/collection_smruti.dart';
import 'package:harismruti/ui/view/home/location_smruti.dart';
import 'package:harismruti/ui/view/home/people_smruti.dart';
import 'package:harismruti/ui/view/home/recent_smruti.dart';
import 'package:harismruti/ui/view/home/smruti_of.dart';
import 'package:harismruti/ui/view/home/smruti_with.dart';
import 'package:harismruti/ui/view/home/wallpaper_smruti.dart';
import 'package:harismruti/utils/app_string.dart';
import 'package:harismruti/utils/size_config.dart';
import 'package:harismruti/utils/storage_helper.dart';

class SmrutiSectionController extends GetxController {
  RxList<Map<String, dynamic>> sections = <Map<String, dynamic>>[].obs;
  final RxInt visibleCount = 3.obs;
  final RxBool showBottomBar = true.obs;
  double lastOffset = 0;

  @override
  void onInit() {
    super.onInit();
    loadSections();
  }

  void increaseVisibleCount([int step = 3]) {
    visibleCount.value += step;
  }

  void resetVisibleCount() {
    visibleCount.value = 3;
  }

  void onHomeScroll(
    double offset,
    double maxScroll,
    AnimationController appBarController,
  ) {
    double delta = 10;

    if (offset > lastOffset && offset > 50) {
      if (appBarController.value == 1.0) {
        appBarController.reverse();
        showBottomBar.value = false;
      }
    } else if (offset < lastOffset - 10) {
      if (appBarController.value == 0.0) {
        appBarController.forward();
        showBottomBar.value = true;
      }
    }

    if (offset + delta >= maxScroll) {
      final totalVisible = sections.where((e) => e['is_show'] == true).length;
      if (visibleCount.value < totalVisible) {
        increaseVisibleCount();
      }
    }

    lastOffset = offset;
  }

  SizedBox getVerticalSizeBox() {
    return SizedBox(height: SizeConfig.heightMultiplier! * 1.5);
  }

  void loadSections() {
    final stored = StorageHelper.loadSections();
    if (stored.isNotEmpty) {
      sections.assignAll(
        stored.map((e) {
          return {...e, "widget": _getWidgetByTitle(e['title'])};
        }),
      );
    } else {
      sections.assignAll(_defaultSections());
    }
  }

  void updateSectionVisibility(int index, bool value) {
    sections[index]['is_show'] = value;
    saveSectionsToStorage();
    sections.refresh();
  }

  void reorderSections(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;

    final item = sections.removeAt(oldIndex);
    sections.insert(newIndex, item);

    for (int i = 0; i < sections.length; i++) {
      sections[i]['order_index'] = i + 1;
    }
    saveSectionsToStorage();
    sections.refresh();
  }

  void saveSectionsToStorage() {
    final saveList = sections
        .map(
          (e) => {
            "title": e['title'],
            "order_index": e['order_index'],
            "is_show": e['is_show'],
          },
        )
        .toList();
    StorageHelper.setValue(
      key: StorageKeys.smrutiSectionConfig,
      value: saveList,
    );
  }

  Widget _getWidgetByTitle(String title) {
    switch (title) {
      case SmrutiSectionKeys.recent:
        return const RecentSmruti();
      case SmrutiSectionKeys.withSmruti:
        return const SmrutiWith();
      case SmrutiSectionKeys.ofSmruti:
        return const SmrutiOf();
      case SmrutiSectionKeys.location:
        return const LocationSmruti();
      case SmrutiSectionKeys.album:
        return const AlbumSmruti();
      case SmrutiSectionKeys.collections:
        return const CollectionSmruti();
      case SmrutiSectionKeys.people:
        return const PeopleSmruti();
      case SmrutiSectionKeys.wallpapers:
        return const WallpaperSmruti();
      case SmrutiSectionKeys.pinnedCollection:
        return const SizedBox();
      default:
        return const SizedBox();
    }
  }

  List<Map<String, dynamic>> _defaultSections() => [
    {
      "title": SmrutiSectionKeys.recent,
      "order_index": 1,
      "is_show": true,
      "widget": const RecentSmruti(),
    },
    {
      "title": SmrutiSectionKeys.withSmruti,
      "order_index": 2,
      "is_show": true,
      "widget": const SmrutiWith(),
    },
    {
      "title": SmrutiSectionKeys.ofSmruti,
      "order_index": 3,
      "is_show": true,
      "widget": const SmrutiOf(),
    },
    {
      "title": SmrutiSectionKeys.location,
      "order_index": 4,
      "is_show": true,
      "widget": const LocationSmruti(),
    },
    {
      "title": SmrutiSectionKeys.album,
      "order_index": 5,
      "is_show": true,
      "widget": const AlbumSmruti(),
    },
    {
      "title": SmrutiSectionKeys.collections,
      "order_index": 6,
      "is_show": true,
      "widget": const CollectionSmruti(),
    },
    {
      "title": SmrutiSectionKeys.people,
      "order_index": 7,
      "is_show": true,
      "widget": const PeopleSmruti(),
    },
    {
      "title": SmrutiSectionKeys.wallpapers,
      "order_index": 8,
      "is_show": true,
      "widget": const WallpaperSmruti(),
    },
    {
      "title": SmrutiSectionKeys.pinnedCollection,
      "order_index": 9,
      "is_show": true,
      "widget": const SizedBox(),
    },
  ];
}
