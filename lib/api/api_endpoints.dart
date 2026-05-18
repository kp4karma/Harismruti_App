enum Environment { debug, profile, production }

class ApiEndpoints {
  static Environment currentEnvironment = Environment.debug;

  static const String _defaultLiveDomain =
      "https://hpsmruti.suhrad.digital/api/v1/mobile";
  // static const String _defaultLiveDomain =
  //     "http://192.168.31.71:8000/api/v1/mobile";
  // "http://10.0.2.2:8000/api/v1/mobile";
  static final String _apiBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: _defaultLiveDomain,
  );
  static final String mobileApiKey = String.fromEnvironment(
    "MOBILE_API_KEY",
    defaultValue:
        "9606245936490b64a8ed41ccc0c8ebfb2022c9ac714a2e20094a5bb49bc98f47",
  );

  static String get mainDomain {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    return currentEnvironment == Environment.production
        ? _defaultLiveDomain
        : _defaultLiveDomain;
  }

  static String get home => "/home";
  static String get recent => "/recent";
  static String get collections => "/collections";
  static String get attributes => "/attributes";
  static String get filters => "/filters";
  static String get smrutiOf => "/smruti-of";
  static String get people => "/people";
  static String get filteredPhotos => "/filtered/photos";
  static String get login => "/auth/login";
  static String get verifyOtp => "/auth/verify-otp";
  static String get register => "/auth/register";
  static String get refresh => "/auth/refresh";
  static String get myLibrary => "/me/library";
  static String get myFavorites => "/me/favorites";
  static String get myTags => "/me/tags";
  static String get myCollections => "/me/collections";
  static String get myImages => "/me/images";
  static String get myProfileImage => "/me/profile-image";
  static String get myDiary => "/me/diary";

  static String collectionMonths(int year) => "/collections/$year/months";
  static String collectionDays(int year, int month) =>
      "/collections/$year/$month/days";
  static String collectionDayPhotos(int year, int month, int day) =>
      "/collections/$year/$month/$day/photos";
  static String collectionYearPhotos(int year) => "/collections/$year/photos";
  static String byAttributePhotos(String slug) => "/by-attribute/$slug/photos";
  static String photoAttributes(int photoId) => "/photos/$photoId/attributes";
  static String subLocations(String location) =>
      "/locations/${Uri.encodeComponent(location)}/sub-locations";
  static String personPhotos(int groupId) => "/people/$groupId/photos";
  static String myFavorite(int photoId) => "/me/favorites/$photoId";
  static String myTag(int photoId, String tag) =>
      "/me/tags/$photoId/${Uri.encodeComponent(tag)}";
  static String myCollection(String name) =>
      "/me/collections/${Uri.encodeComponent(name)}";
  static String myDiaryEntry(String entryId) =>
      "/me/diary/${Uri.encodeComponent(entryId)}";
  static String myImage(int imageId) => "$mainDomain/me/images/$imageId";
  static String faceThumbnail(int faceId) =>
      "$mainDomain/faces/$faceId/thumbnail";
  static String photoThumbnail(int photoId) =>
      "$mainDomain/photos/$photoId/thumbnail";
  static String photoFull(int photoId) => "$mainDomain/photos/$photoId/full";
}

