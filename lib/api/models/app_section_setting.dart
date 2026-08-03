class AppSectionSetting {
  final String sectionKey;
  final String displayName;
  final bool enabled;
  final int orderIndex;
  final String orderMode;
  final int freshnessDays;
  final int itemLimit;
  final String refreshTime;
  final List<String> refreshTimes;

  const AppSectionSetting({
    required this.sectionKey,
    required this.displayName,
    required this.enabled,
    required this.orderIndex,
    required this.orderMode,
    required this.freshnessDays,
    required this.itemLimit,
    required this.refreshTime,
    required this.refreshTimes,
  });

  factory AppSectionSetting.fromJson(Map<String, dynamic> json) {
    return AppSectionSetting(
      sectionKey: json['section_key']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      enabled: json['enabled'] != false,
      orderIndex: int.tryParse(json['order_index']?.toString() ?? '') ?? 0,
      orderMode: json['order_mode']?.toString() ?? 'fresh_then_random',
      freshnessDays:
          int.tryParse(json['freshness_days']?.toString() ?? '') ?? 7,
      itemLimit: int.tryParse(json['item_limit']?.toString() ?? '') ?? 10,
      refreshTime: json['refresh_time']?.toString() ?? '05:00',
      refreshTimes: json['refresh_times'] is List
          ? (json['refresh_times'] as List)
                .map((value) => value.toString())
                .where((value) => value.isNotEmpty)
                .toList()
          : [json['refresh_time']?.toString() ?? '05:00'],
    );
  }

  Map<String, dynamic> toJson() => {
    'section_key': sectionKey,
    'display_name': displayName,
    'enabled': enabled,
    'order_index': orderIndex,
    'order_mode': orderMode,
    'freshness_days': freshnessDays,
    'item_limit': itemLimit,
    'refresh_time': refreshTime,
    'refresh_times': refreshTimes,
  };
}

class AppSectionOptionLabel {
  final String optionKey;
  final String displayName;
  final int orderIndex;
  final int cacheRevision;

  const AppSectionOptionLabel({
    required this.optionKey,
    required this.displayName,
    required this.orderIndex,
    required this.cacheRevision,
  });

  factory AppSectionOptionLabel.fromJson(Map<String, dynamic> json) {
    return AppSectionOptionLabel(
      optionKey: json['option_key']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      orderIndex: int.tryParse(json['order_index']?.toString() ?? '') ?? 0,
      cacheRevision:
          int.tryParse(json['cache_revision']?.toString() ?? '') ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'option_key': optionKey,
    'display_name': displayName,
    'order_index': orderIndex,
    'cache_revision': cacheRevision,
  };
}

class AppSectionsConfiguration {
  final String selectedOption;
  final String optionName;
  final int cacheRevision;
  final List<AppSectionOptionLabel> options;
  final List<AppSectionSetting> sections;
  final Map<String, bool> features;

  const AppSectionsConfiguration({
    required this.selectedOption,
    required this.optionName,
    required this.cacheRevision,
    required this.options,
    required this.sections,
    required this.features,
  });

  factory AppSectionsConfiguration.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] is List
        ? json['options'] as List
        : const [];
    final rawSections = json['sections'] is List
        ? json['sections'] as List
        : const [];
    return AppSectionsConfiguration(
      selectedOption: json['selected_option']?.toString() ?? 'prabodh',
      optionName: json['option_name']?.toString() ?? '',
      cacheRevision:
          int.tryParse(json['cache_revision']?.toString() ?? '') ?? 1,
      options:
          rawOptions
              .whereType<Map>()
              .map(
                (item) => AppSectionOptionLabel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.optionKey.isNotEmpty)
              .toList()
            ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
      sections: rawSections
          .whereType<Map>()
          .map(
            (item) =>
                AppSectionSetting.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.sectionKey.isNotEmpty)
          .toList(),
      features: json['features'] is Map
          ? Map<String, dynamic>.from(
              json['features'] as Map,
            ).map((key, value) => MapEntry(key, value != false))
          : const {},
    );
  }
}
