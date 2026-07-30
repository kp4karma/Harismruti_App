import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/api/api_endpoints.dart';
import 'package:harismruti/api/models/app_section_setting.dart';

class AppSectionRepository {
  const AppSectionRepository();

  Future<AppSectionsConfiguration> getConfiguration({
    required String optionKey,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.appSections,
      queryParams: {'swami': optionKey},
      forceRefresh: true,
      cacheDuration: Duration.zero,
    );
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : const <String, dynamic>{};
    return AppSectionsConfiguration.fromJson(data);
  }
}
