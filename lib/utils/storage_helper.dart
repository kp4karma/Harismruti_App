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
  static const String myPhotos = 'myPhotos';
  static const String myDiaryEntries = 'myDiaryEntries';
  static const String myPhotosSubmitted = 'myPhotosSubmitted';
  static const String favoritePhotos = 'favoritePhotos';
  static const String galleryPhotoSnapshots = 'galleryPhotoSnapshots';
  static const String photoUserTags = 'photoUserTags';
  static const String userCollections = 'userCollections';
  static const String authCarouselImages = 'authCarouselImages';
  static const String reorderTutorialSeen = 'reorderTutorialSeenV2';
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
    _box.erase();
    if (reorderTutorialSeen == true) {
      setValue(key: StorageKeys.reorderTutorialSeen, value: true);
    }
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
