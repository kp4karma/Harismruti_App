import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/ui/view/home/album_smruti.dart';
import 'package:harismruti/ui/view/home/collection_smruti.dart';
import 'package:harismruti/ui/view/home/location_smruti.dart';
import 'package:harismruti/ui/view/home/my_collection_smruti.dart';
import 'package:harismruti/ui/view/home/my_diary_smruti.dart';
import 'package:harismruti/ui/view/home/my_favorite_smruti.dart';
import 'package:harismruti/ui/view/home/my_photos_smruti.dart';
import 'package:harismruti/ui/view/home/recent_smruti.dart';
import 'package:harismruti/ui/view/home/smruti_of.dart';
import 'package:harismruti/ui/view/home/smruti_with.dart';
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
    final stored = StorageHelper.loadSections()
        .where((e) => !_isRemovedHomeSection(e['title']))
        .toList();
    if (stored.isNotEmpty) {
      final defaults = _defaultSections();
      final storedTitles = stored.map((e) => e['title']).toSet();
      final missingDefaults = defaults
          .where((section) => !storedTitles.contains(section['title']))
          .toList();

      sections.assignAll([
        ...stored.map((e) {
          return {...e, "widget": _getWidgetByTitle(e['title'])};
        }),
        ...missingDefaults.map(
          (e) => {
            ...e,
            'order_index': stored.length + missingDefaults.indexOf(e) + 1,
          },
        ),
      ]);
      saveSectionsToStorage();
    } else {
      sections.assignAll(_defaultSections());
    }
  }

  void updateSectionVisibility(int index, bool value) {
    sections[index]['is_show'] = value;
    saveSectionsToStorage();
    sections.refresh();
  }

  List<Map<String, dynamic>> customizableSections() {
    return sections
        .where((section) => !_isHiddenFromPreferences(section['title']))
        .toList();
  }

  void updateSectionVisibilityByTitle(String title, bool value) {
    final index = sections.indexWhere((section) => section['title'] == title);
    if (index == -1) return;
    updateSectionVisibility(index, value);
  }

  void reorderCustomizableSections(int oldIndex, int newIndex) {
    final editableTitles = customizableSections()
        .map((section) => section['title'])
        .toList();
    if (newIndex > oldIndex) newIndex--;

    final movedTitle = editableTitles.removeAt(oldIndex);
    editableTitles.insert(newIndex, movedTitle);

    final sectionsByTitle = {
      for (final section in sections) section['title']: section,
    };
    final sortedSlots = sections.toList()
      ..sort((a, b) => a['order_index'].compareTo(b['order_index']));
    final reordered = <Map<String, dynamic>>[];
    var editableIndex = 0;
    for (var slotIndex = 0; slotIndex < sortedSlots.length; slotIndex++) {
      final section = sortedSlots[slotIndex];
      if (_isHiddenFromPreferences(section['title'])) {
        reordered.add({...section, 'order_index': slotIndex + 1});
        continue;
      }
      final title = editableTitles[editableIndex];
      reordered.add({
        ...?sectionsByTitle[title],
        'title': title,
        'order_index': slotIndex + 1,
        'widget': _getWidgetByTitle(title),
      });
      editableIndex++;
    }

    sections.assignAll(reordered);
    saveSectionsToStorage();
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
      case SmrutiSectionKeys.myPhotos:
      case "My Phone":
      case "My Photos":
        return const MyPhotosSmruti();
      case SmrutiSectionKeys.myDiary:
      case "My Diray":
        return const MyDiarySmruti();
      case SmrutiSectionKeys.myFavorite:
      case "My Favot":
      case "My Favorites":
        return const MyFavoriteSmruti();
      case SmrutiSectionKeys.myCollection:
      case "My Collectino":
        return const MyCollectionSmruti();
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
      "title": SmrutiSectionKeys.myPhotos,
      "order_index": 7,
      "is_show": true,
      "widget": const MyPhotosSmruti(),
    },
    {
      "title": SmrutiSectionKeys.myDiary,
      "order_index": 8,
      "is_show": true,
      "widget": const MyDiarySmruti(),
    },
    {
      "title": SmrutiSectionKeys.myFavorite,
      "order_index": 9,
      "is_show": true,
      "widget": const MyFavoriteSmruti(),
    },
    {
      "title": SmrutiSectionKeys.myCollection,
      "order_index": 10,
      "is_show": true,
      "widget": const MyCollectionSmruti(),
    },
  ];

  bool _isHiddenFromPreferences(dynamic title) => false;

  bool _isRemovedHomeSection(dynamic title) {
    return title == SmrutiSectionKeys.wallpapers ||
        title == SmrutiSectionKeys.people ||
        title == SmrutiSectionKeys.pinnedCollection;
  }
}
