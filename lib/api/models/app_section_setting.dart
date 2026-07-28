class AppSectionSetting {
  final String sectionKey;
  final String displayName;
  final String description;
  final bool enabled;
  final int orderIndex;
  final String orderMode;
  final int freshnessDays;
  final int itemLimit;

  const AppSectionSetting({
    required this.sectionKey,
    required this.displayName,
    required this.description,
    required this.enabled,
    required this.orderIndex,
    required this.orderMode,
    required this.freshnessDays,
    required this.itemLimit,
  });

  factory AppSectionSetting.fromJson(Map<String, dynamic> json) {
    return AppSectionSetting(
      sectionKey: json['section_key']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      enabled: json['enabled'] != false,
      orderIndex: int.tryParse(json['order_index']?.toString() ?? '') ?? 0,
      orderMode: json['order_mode']?.toString() ?? 'fresh_then_random',
      freshnessDays:
          int.tryParse(json['freshness_days']?.toString() ?? '') ?? 7,
      itemLimit: int.tryParse(json['item_limit']?.toString() ?? '') ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
    'section_key': sectionKey,
    'display_name': displayName,
    'description': description,
    'enabled': enabled,
    'order_index': orderIndex,
    'order_mode': orderMode,
    'freshness_days': freshnessDays,
    'item_limit': itemLimit,
  };
}
