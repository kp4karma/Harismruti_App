import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/api/api_endpoints.dart';
import 'package:harismruti/api/models/app_section_setting.dart';

class AppSectionRepository {
  const AppSectionRepository();

  Future<List<AppSectionSetting>> getSections() async {
    final response = await ApiClient.get(
      ApiEndpoints.appSections,
      forceRefresh: true,
      cacheDuration: Duration.zero,
    );
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : const <String, dynamic>{};
    final items = data['sections'] is List
        ? data['sections'] as List
        : const [];
    return items
        .whereType<Map>()
        .map(
          (item) => AppSectionSetting.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((section) => section.sectionKey.isNotEmpty)
        .toList();
  }
}
