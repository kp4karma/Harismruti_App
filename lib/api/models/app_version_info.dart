class AppVersionInfo {
  final String currentVersion;
  final String minVersion;
  final String maxVersion;
  final String storeUrl;
  final String message;
  final bool updateRequired;
  final bool updateAvailable;

  const AppVersionInfo({
    required this.currentVersion,
    required this.minVersion,
    required this.maxVersion,
    required this.storeUrl,
    required this.message,
    required this.updateRequired,
    required this.updateAvailable,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      currentVersion: json['current_version']?.toString() ?? '',
      minVersion: json['min_version']?.toString() ?? '',
      maxVersion: json['max_version']?.toString() ?? '',
      storeUrl: json['store_url']?.toString() ?? '',
      message:
          json['message']?.toString() ?? 'New version available. Upgrade now.',
      updateRequired: json['update_required'] == true,
      updateAvailable: json['update_available'] == true,
    );
  }
}
