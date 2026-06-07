class AppSectionSetting {
  final String sectionKey;
  final String displayName;
  final bool enabled;
  final int orderIndex;

  const AppSectionSetting({
    required this.sectionKey,
    required this.displayName,
    required this.enabled,
    required this.orderIndex,
  });

  factory AppSectionSetting.fromJson(Map<String, dynamic> json) {
    return AppSectionSetting(
      sectionKey: json['section_key']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      enabled: json['enabled'] != false,
      orderIndex: int.tryParse(json['order_index']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'section_key': sectionKey,
    'display_name': displayName,
    'enabled': enabled,
    'order_index': orderIndex,
  };
}
