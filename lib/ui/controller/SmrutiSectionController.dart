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
import 'package:harismruti/ui/view/home/on_this_day_smruti.dart';
import 'package:harismruti/ui/view/home/smruti_of.dart';
import 'package:harismruti/ui/view/home/smruti_with.dart';
import 'package:harismruti/ui/view/home/subject_smruti.dart';
import 'package:harismruti/api/repositories/app_section_repository.dart';
import 'package:harismruti/api/models/app_section_setting.dart';
import 'package:harismruti/utils/app_string.dart';
import 'package:harismruti/utils/size_config.dart';
import 'package:harismruti/utils/storage_helper.dart';

class SmrutiSectionController extends GetxController {
  SmrutiSectionController({AppSectionRepository? appSectionRepository})
    : _appSectionRepository =
          appSectionRepository ?? const AppSectionRepository();

  final AppSectionRepository _appSectionRepository;
  RxList<Map<String, dynamic>> sections = <Map<String, dynamic>>[].obs;
  final RxMap<String, String> optionLabels = <String, String>{
    'prabodh': 'P.P.Prabodh Swamiji',
    'hariprasad': 'P.P.Hariprasad Swamiji',
  }.obs;
  final RxMap<String, bool> appFeatures = <String, bool>{}.obs;
  bool isFeatureEnabled(String key) => appFeatures[key] ?? true;

  bool isSectionVisible(String sectionKey) {
    for (final section in sections) {
      if (_sectionKeyForTitle(section['title'].toString()) == sectionKey) {
        return section['is_show'] == true;
      }
    }
    return true;
  }

  final Set<String> _pendingCacheRefresh = {};
  final RxInt visibleCount = 3.obs;
  final RxBool showBottomBar = true.obs;
  final RxBool showSmrutiStoryLine = false.obs;
  final RxInt smrutiStoryCount = 8.obs;
  final RxInt smrutiStoryRefreshHours = 1.obs;
  double lastOffset = 0;

  @override
  void onInit() {
    super.onInit();
    _loadCachedOptionLabels();
    showSmrutiStoryLine.value =
        StorageHelper.getValue<bool>(
          key: StorageKeys.showSmrutiStoryLine,
          defaultValue: false,
        ) ??
        false;
    smrutiStoryCount.value =
        StorageHelper.getValue<int>(
          key: StorageKeys.smrutiStoryCount,
          defaultValue: 8,
        ) ??
        8;
    smrutiStoryRefreshHours.value =
        StorageHelper.getValue<int>(
          key: StorageKeys.smrutiStoryRefreshHours,
          defaultValue: 1,
        ) ??
        1;
    loadSections();
    final cachedSettings = _loadCachedGlobalSettings(_selectedOptionKey());
    if (cachedSettings.isNotEmpty) {
      _applyGlobalSettings(cachedSettings);
    }
    refreshGlobalVisibility(optionKey: _selectedOptionKey());
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
      }
    } else if (offset < lastOffset - 10) {
      if (appBarController.value == 0.0) {
        appBarController.forward();
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
    final cachedGlobalVisibility = _loadCachedGlobalVisibility();
    final stored = StorageHelper.loadSections()
        .where((e) => !_isRemovedHomeSection(e['title']))
        .toList();
    if (stored.isNotEmpty) {
      final defaults = _defaultSections();
      final storedTitles = stored.map((e) => e['title']).toSet();
      final missingDefaults = defaults
          .where((section) => !storedTitles.contains(section['title']))
          .toList();

      final restoredSections = stored.map((e) {
        final title = e['title'].toString();
        final localVisibility = e['user_is_show'] ?? e['is_show'] ?? true;
        return {
          ...e,
          'user_is_show': localVisibility,
          'is_show':
              (cachedGlobalVisibility[_sectionKeyForTitle(title)] ?? true) &&
              (localVisibility == true),
          "widget": _getWidgetByTitle(title),
        };
      }).toList();
      final shouldPromoteOnThisDay =
          StorageHelper.getValue<bool>(
            key: StorageKeys.onThisDaySectionOrderMigrated,
          ) !=
          true;
      if (shouldPromoteOnThisDay) {
        restoredSections.removeWhere(
          (section) => section['title'] == SmrutiSectionKeys.onThisDay,
        );
      }
      final isOnThisDayNew =
          shouldPromoteOnThisDay ||
          missingDefaults.any(
            (section) => section['title'] == SmrutiSectionKeys.onThisDay,
          );
      final remainingMissing = missingDefaults
          .where(
            (section) =>
                section['title'] != SmrutiSectionKeys.onThisDay &&
                section['title'] != SmrutiSectionKeys.liveDarshan &&
                section['title'] != SmrutiSectionKeys.aiSearch &&
                section['title'] != SmrutiSectionKeys.downloads,
          )
          .toList();
      final newUtilitySections = missingDefaults
          .where(
            (section) =>
                section['title'] == SmrutiSectionKeys.liveDarshan ||
                section['title'] == SmrutiSectionKeys.aiSearch,
          )
          .map((section) => {...section, 'user_is_show': true});
      final newDownloadSections = missingDefaults
          .where((section) => section['title'] == SmrutiSectionKeys.downloads)
          .map((section) => {...section, 'user_is_show': true});
      final mergedSections = <Map<String, dynamic>>[
        ...newUtilitySections,
        if (isOnThisDayNew)
          {
            ...defaults.firstWhere(
              (section) => section['title'] == SmrutiSectionKeys.onThisDay,
            ),
            'user_is_show': true,
          },
        ...restoredSections,
        ...remainingMissing.map(
          (e) => {...e, 'user_is_show': e['is_show'] ?? true},
        ),
        ...newDownloadSections,
      ];
      for (var index = 0; index < mergedSections.length; index++) {
        mergedSections[index]['order_index'] = index + 1;
      }
      sections.assignAll(mergedSections);
      saveSectionsToStorage();
      StorageHelper.setValue(
        key: StorageKeys.onThisDaySectionOrderMigrated,
        value: true,
      );
      _applyGlobalVisibility(cachedGlobalVisibility);
    } else {
      sections.assignAll(_defaultSections());
      StorageHelper.setValue(
        key: StorageKeys.onThisDaySectionOrderMigrated,
        value: true,
      );
      _applyGlobalVisibility(cachedGlobalVisibility);
    }
  }

  void updateSectionVisibility(int index, bool value) {
    sections[index]['user_is_show'] = value;
    final sectionKey = _sectionKeyForTitle(sections[index]['title'].toString());
    final globalVisibility = _loadCachedGlobalVisibility();
    sections[index]['is_show'] =
        (globalVisibility[sectionKey] ?? true) && value;
    saveSectionsToStorage();
    sections.refresh();
  }

  void saveSmrutiStorySettings({
    required bool visible,
    required int count,
    required int refreshHours,
  }) {
    showSmrutiStoryLine.value = visible;
    smrutiStoryCount.value = count;
    smrutiStoryRefreshHours.value = refreshHours;
    StorageHelper.setValue(
      key: StorageKeys.showSmrutiStoryLine,
      value: visible,
    );
    StorageHelper.setValue(key: StorageKeys.smrutiStoryCount, value: count);
    StorageHelper.setValue(
      key: StorageKeys.smrutiStoryRefreshHours,
      value: refreshHours,
    );
  }

  List<Map<String, dynamic>> customizableSections() {
    return sections.where(_isAdminEnabled).toList();
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
    final editableTitleSet = editableTitles.toSet();
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
      if (!editableTitleSet.contains(section['title'])) {
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

  void resetToDefaultOrder() {
    final visibilityByTitle = {
      for (final section in sections)
        section['title']: section['user_is_show'] ?? section['is_show'] ?? true,
    };
    final defaults = _defaultSections().where(
      (section) => !_isRemovedHomeSection(section['title']),
    );

    sections.assignAll(
      defaults.map((section) {
        final title = section['title'];
        return {
          ...section,
          'user_is_show': visibilityByTitle[title] ?? section['is_show'],
          'is_show': visibilityByTitle[title] ?? section['is_show'],
          'widget': _getWidgetByTitle(title),
        };
      }).toList(),
    );
    resetVisibleCount();
    saveSectionsToStorage();
    _applyGlobalVisibility(_loadCachedGlobalVisibility());
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
            "display_name": e['display_name'] ?? e['title'],
            "order_index": e['order_index'],
            "is_show": e['user_is_show'] ?? e['is_show'],
            "user_is_show": e['user_is_show'] ?? e['is_show'],
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
      case SmrutiSectionKeys.onThisDay:
        return const OnThisDaySmruti();
      case SmrutiSectionKeys.withSmruti:
        return const SmrutiWith();
      case SmrutiSectionKeys.ofDarshan:
        return const SmrutiOf();
      case SmrutiSectionKeys.location:
        return const LocationSmruti();
      case SmrutiSectionKeys.album:
        return const AlbumSmruti();
      case SmrutiSectionKeys.ofSmruti:
        return const SubjectSmruti();
      case SmrutiSectionKeys.yearCollection:
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
      "title": SmrutiSectionKeys.liveDarshan,
      "order_index": 1,
      "is_show": true,
      "widget": const SizedBox(),
    },
    {
      "title": SmrutiSectionKeys.aiSearch,
      "order_index": 2,
      "is_show": true,
      "widget": const SizedBox(),
    },
    {
      "title": SmrutiSectionKeys.onThisDay,
      "order_index": 3,
      "is_show": true,
      "widget": const OnThisDaySmruti(),
    },
    {
      "title": SmrutiSectionKeys.recent,
      "order_index": 4,
      "is_show": true,
      "widget": const RecentSmruti(),
    },
    {
      "title": SmrutiSectionKeys.withSmruti,
      "order_index": 5,
      "is_show": true,
      "widget": const SmrutiWith(),
    },
    {
      "title": SmrutiSectionKeys.ofDarshan,
      "order_index": 6,
      "is_show": true,
      "widget": const SmrutiOf(),
    },
    {
      "title": SmrutiSectionKeys.location,
      "order_index": 7,
      "is_show": true,
      "widget": const LocationSmruti(),
    },
    {
      "title": SmrutiSectionKeys.album,
      "order_index": 8,
      "is_show": true,
      "widget": const AlbumSmruti(),
    },
    {
      "title": SmrutiSectionKeys.ofSmruti,
      "order_index": 9,
      "is_show": true,
      "widget": const SubjectSmruti(),
    },
    {
      "title": SmrutiSectionKeys.yearCollection,
      "order_index": 10,
      "is_show": true,
      "widget": const CollectionSmruti(),
    },
    {
      "title": SmrutiSectionKeys.myPhotos,
      "order_index": 11,
      "is_show": true,
      "widget": const MyPhotosSmruti(),
    },
    {
      "title": SmrutiSectionKeys.myDiary,
      "order_index": 12,
      "is_show": true,
      "widget": const MyDiarySmruti(),
    },
    {
      "title": SmrutiSectionKeys.myFavorite,
      "order_index": 13,
      "is_show": true,
      "widget": const MyFavoriteSmruti(),
    },
    {
      "title": SmrutiSectionKeys.myCollection,
      "order_index": 14,
      "is_show": true,
      "widget": const MyCollectionSmruti(),
    },
    {
      "title": SmrutiSectionKeys.downloads,
      "order_index": 15,
      "is_show": true,
      "widget": const SizedBox(),
    },
  ];

  Future<void> refreshGlobalVisibility({required String optionKey}) async {
    try {
      final configuration = await _appSectionRepository.getConfiguration(
        optionKey: optionKey,
      );
      appFeatures.assignAll(configuration.features);
      final revisions = _loadCachedCacheRevisions();
      if (revisions[optionKey] != configuration.cacheRevision) {
        _pendingCacheRefresh.add(optionKey);
      }
      StorageHelper.setValue(
        key: StorageKeys.appSectionCacheRevisions,
        value: {...revisions, optionKey: configuration.cacheRevision},
      );
      final remoteSections = configuration.sections;
      final visibility = {
        for (final section in remoteSections)
          section.sectionKey: section.enabled,
      };
      StorageHelper.setValue(
        key: StorageKeys.appSectionVisibility,
        value: visibility,
      );
      StorageHelper.setValue(
        key: StorageKeys.appSectionSettingsByOption,
        value: {
          ..._loadCachedSettingsMap(),
          optionKey: remoteSections.map((section) => section.toJson()).toList(),
        },
      );
      optionLabels.assignAll({
        for (final option in configuration.options)
          option.optionKey: option.displayName,
      });
      StorageHelper.setValue(
        key: StorageKeys.appSectionOptionLabels,
        value: Map<String, String>.from(optionLabels),
      );
      _applyGlobalSettings(remoteSections);
    } catch (_) {
      final cachedSettings = _loadCachedGlobalSettings(optionKey);
      if (cachedSettings.isNotEmpty) {
        _applyGlobalSettings(cachedSettings);
      } else {
        _applyGlobalVisibility(_loadCachedGlobalVisibility());
      }
    }
  }

  bool consumeCacheRefresh(String optionKey) {
    return _pendingCacheRefresh.remove(optionKey);
  }

  Map<String, int> _loadCachedCacheRevisions() {
    final raw = StorageHelper.getValue<Map>(
      key: StorageKeys.appSectionCacheRevisions,
    );
    if (raw == null) return {};
    return raw.map(
      (key, value) =>
          MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0),
    );
  }

  Map<String, dynamic> _loadCachedSettingsMap() {
    final raw = StorageHelper.getValue<Map>(
      key: StorageKeys.appSectionSettingsByOption,
    );
    if (raw == null) return {};
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  List<AppSectionSetting> _loadCachedGlobalSettings(String optionKey) {
    final raw = _loadCachedSettingsMap()[optionKey];
    if (raw is! List) return const [];
    final items = raw;
    return items
        .whereType<Map>()
        .map(
          (item) => AppSectionSetting.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.sectionKey.isNotEmpty)
        .toList();
  }

  void _loadCachedOptionLabels() {
    final raw = StorageHelper.getValue<Map>(
      key: StorageKeys.appSectionOptionLabels,
    );
    if (raw == null) return;
    optionLabels.assignAll(
      raw.map((key, value) => MapEntry(key.toString(), value.toString())),
    );
  }

  String _selectedOptionKey() {
    return StorageHelper.getValue<String>(key: StorageKeys.selectedSwami) ??
        'prabodh';
  }

  void _applyGlobalSettings(List<AppSectionSetting> settings) {
    final settingsByKey = {
      for (final setting in settings) setting.sectionKey: setting,
    };
    for (final section in sections) {
      final sectionKey = _sectionKeyForTitle(section['title'].toString());
      final setting = settingsByKey[sectionKey];
      if (setting == null) continue;
      final userValue = section['user_is_show'] ?? section['is_show'] ?? true;
      section['is_show'] = setting.enabled && (userValue == true);
      section['display_name'] = setting.displayName.isEmpty
          ? section['title']
          : setting.displayName;
      section['order_index'] = setting.orderIndex;
      section['order_mode'] = setting.orderMode;
      section['freshness_days'] = setting.freshnessDays;
      section['item_limit'] = setting.itemLimit;
    }
    sections.sort(
      (first, second) =>
          (first['order_index'] as int).compareTo(second['order_index'] as int),
    );
    resetVisibleCount();
    sections.refresh();
  }

  Map<String, bool> _loadCachedGlobalVisibility() {
    final raw = StorageHelper.getValue<Map>(
      key: StorageKeys.appSectionVisibility,
    );
    if (raw == null) return {};
    return raw.map((key, value) => MapEntry(key.toString(), value == true));
  }

  void _applyGlobalVisibility(Map<String, bool> visibility) {
    if (visibility.isEmpty) return;
    for (final section in sections) {
      final sectionKey = _sectionKeyForTitle(section['title'].toString());
      final globalValue = visibility[sectionKey];
      if (globalValue != null) {
        final userValue = section['user_is_show'] ?? section['is_show'] ?? true;
        section['is_show'] = globalValue && (userValue == true);
      }
    }
    resetVisibleCount();
    sections.refresh();
  }

  String _sectionKeyForTitle(String title) {
    return switch (title) {
      SmrutiSectionKeys.liveDarshan => 'live_darshan',
      SmrutiSectionKeys.aiSearch => 'ai_search',
      SmrutiSectionKeys.downloads => 'downloads',
      SmrutiSectionKeys.recent => 'recent',
      SmrutiSectionKeys.onThisDay => 'on_this_day',
      SmrutiSectionKeys.withSmruti => 'smruti_with',
      SmrutiSectionKeys.ofDarshan => 'darshan_of',
      SmrutiSectionKeys.location => 'location',
      SmrutiSectionKeys.album => 'smruti_category',
      SmrutiSectionKeys.ofSmruti => 'smruti_of',
      SmrutiSectionKeys.yearCollection => 'year',
      SmrutiSectionKeys.myPhotos || 'My Phone' || 'My Photos' => 'my_smruti',
      SmrutiSectionKeys.myDiary || 'My Diray' => 'my_diary',
      SmrutiSectionKeys.myFavorite ||
      'My Favot' ||
      'My Favorites' => 'my_favorite',
      SmrutiSectionKeys.myCollection || 'My Collectino' => 'my_collection',
      _ => '',
    };
  }

  bool _isAdminEnabled(Map<String, dynamic> section) {
    final sectionKey = _sectionKeyForTitle(section['title'].toString());
    return _loadCachedGlobalVisibility()[sectionKey] != false;
  }

  bool _isRemovedHomeSection(dynamic title) {
    return title == SmrutiSectionKeys.wallpapers ||
        title == SmrutiSectionKeys.people ||
        title == SmrutiSectionKeys.pinnedCollection;
  }
}
