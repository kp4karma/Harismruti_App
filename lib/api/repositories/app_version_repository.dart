import 'package:flutter/foundation.dart';
import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/api/api_endpoints.dart';
import 'package:harismruti/api/models/app_version_info.dart';

class AppVersionRepository {
  const AppVersionRepository();

  Future<AppVersionInfo?> checkCurrentVersion() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }

    final response = await ApiClient.get(
      ApiEndpoints.appVersionCheck,
      queryParams: {
        'platform': defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : 'ios',
        'current_version': ApiClient.currentAppVersion,
      },
      forceRefresh: true,
      cacheDuration: Duration.zero,
    );
    return AppVersionInfo.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
