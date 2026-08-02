import 'package:get_storage/get_storage.dart';

class StorageKeys {
  static const String authData = 'authData';
  static const String accessToken = 'accessToken';
  static const String refreshToken = 'refreshToken';
  static const String tokenExpiresAt = 'tokenExpiresAt';
  static const String currentDeviceId = 'currentDeviceId';
  static const String deviceId = 'deviceId';
  static const String userProfile = 'userProfile';
  static const String smrutiSectionConfig = 'smrutiSectionConfig';
  static const String onThisDaySectionOrderMigrated =
      'onThisDaySectionOrderMigratedV1';
  static const String appSectionVisibility = 'appSectionVisibility';
  static const String appSectionSettings = 'appSectionSettings';
  static const String appSectionSettingsByOption =
      'appSectionSettingsByOptionV1';
  static const String appSectionOptionLabels = 'appSectionOptionLabelsV1';
  static const String appSectionCacheRevisions = 'appSectionCacheRevisionsV1';
  static const String myPhotos = 'myPhotos';
  static const String myDiaryEntries = 'myDiaryEntries';
  static const String myPhotosSubmitted = 'myPhotosSubmitted';
  static const String mySmrutiRequestId = 'mySmrutiRequestId';
  static const String mySmrutiOwnerKey = 'mySmrutiOwnerKey';
  static const String favoritePhotos = 'favoritePhotos';
  static const String galleryPhotoSnapshots = 'galleryPhotoSnapshots';
  static const String photoUserTags = 'photoUserTags';
  static const String userCollections = 'userCollections';
  static const String authCarouselImages = 'authCarouselImages';
  static const String reorderTutorialSeen = 'reorderTutorialSeenV2';
  static const String selectedSwami = 'selectedSwami';
  static const String fcmTopicsSubscriptionVersion =
      'fcmTopicsSubscriptionVersion';
  static const String notificationHistory = 'notificationHistory';
  static const String lastMobileNumber = 'lastMobileNumber';
  static const String lastMobileCountryCode = 'lastMobileCountryCode';
  static const String showSmrutiStoryLine = 'showSmrutiStoryLine';
  static const String smrutiStoryCount = 'smrutiStoryCount';
  static const String smrutiStoryRefreshHours = 'smrutiStoryRefreshHours';
  static const String darkMode = 'darkMode';
  static const String aiSearchHistory = 'aiSearchHistoryV1';
}

class StorageHelper {
  static final GetStorage _box = GetStorage();

  static Future<void> init() async {
    await GetStorage.init();
  }

  static void setValue({required String key, required dynamic value}) {
    _box.write(key, value);
  }

  static T? getValue<T>({required String key, T? defaultValue}) {
    return _box.read<T>(key) ?? defaultValue;
  }

  static void removeValue(String key) {
    _box.remove(key);
  }

  static void clearStorage() {
    final reorderTutorialSeen = getValue<bool>(
      key: StorageKeys.reorderTutorialSeen,
      defaultValue: false,
    );
    final lastMobileNumber = getValue<String>(
      key: StorageKeys.lastMobileNumber,
    );
    final lastMobileCountryCode = getValue<String>(
      key: StorageKeys.lastMobileCountryCode,
    );
    final darkMode = getValue<bool>(
      key: StorageKeys.darkMode,
      defaultValue: false,
    );
    _box.erase();
    if (reorderTutorialSeen == true) {
      setValue(key: StorageKeys.reorderTutorialSeen, value: true);
    }
    if (lastMobileNumber != null && lastMobileNumber.isNotEmpty) {
      setValue(key: StorageKeys.lastMobileNumber, value: lastMobileNumber);
    }
    if (lastMobileCountryCode != null && lastMobileCountryCode.isNotEmpty) {
      setValue(
        key: StorageKeys.lastMobileCountryCode,
        value: lastMobileCountryCode,
      );
    }
    setValue(key: StorageKeys.darkMode, value: darkMode ?? false);
  }

  static bool hasKey(String key) {
    return _box.hasData(key);
  }

  static List<Map<String, dynamic>> loadSections() {
    final data = _box.read<List>(StorageKeys.smrutiSectionConfig);
    if (data != null) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }
  // static User? getAuthData() {
  //   String? jsonString = _box.read<String>(StorageKeys.authData);
  //   if (jsonString == null) return null;
  //
  //   try {
  //     return User.fromJson(jsonDecode(jsonString));
  //   } catch (e) {
  //     print("❌ Error decoding AuthModel: $e");
  //     return null;
  //   }
  // }

  static String? getUserId() {
    return "";
    // return getAuthData()?.userId;
  }

  static bool isLogin() {
    String? accessToken = getValue(key: StorageKeys.accessToken);
    return accessToken != null && accessToken != "" && accessToken.isNotEmpty;
  }
}
