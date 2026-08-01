// lib/ui/controller/profile_controller.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/api_endpoints.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ProfileController extends GetxController {
  var profileImage = Rxn<File>();
  final RxMap<String, dynamic> profile = <String, dynamic>{}.obs;
  final RxString uploadedProfileImageUrl = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadStoredProfile();
    loadUploadedProfileImageUrl();
  }

  void loadStoredProfile() {
    profile.clear();
    final profileJson = StorageHelper.getValue<String>(
      key: StorageKeys.userProfile,
    );
    if (profileJson == null || profileJson.isEmpty) return;

    try {
      final decoded = jsonDecode(profileJson);
      if (decoded is Map) {
        profile.assignAll(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      profile.clear();
    }
  }

  String get displayName {
    return _firstNonEmpty([
      profile['name'],
      '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim(),
      'HariPrabodham Smruti User',
    ]);
  }

  String get avatarInitial {
    final name = displayName.trim();
    if (name.isEmpty) return 'H';
    return name.characters.first.toUpperCase();
  }

  String get displayId {
    return _firstNonEmpty([profile['id'], '']);
  }

  String get displayMobile {
    return _firstNonEmpty([profile['mobile'], profile['username'], '']);
  }

  String get displayEmail {
    return _firstNonEmpty([profile['email'], '']);
  }

  String get displayCity {
    return _firstNonEmpty([profile['city'], '']);
  }

  String get avatarUrl {
    if (uploadedProfileImageUrl.value.isNotEmpty) {
      return uploadedProfileImageUrl.value;
    }
    final avatar = profile['avatar']?.toString().trim() ?? '';
    if (avatar.isEmpty || avatar == 'img/default-avatar.jpg') return '';
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return avatar;
    }
    return 'https://staging-admin.suhrad.digital/${avatar.replaceFirst(RegExp(r'^/+'), '')}';
  }

  void loadUploadedProfileImageUrl() {
    uploadedProfileImageUrl.value = '';
    final token = StorageHelper.getValue<String>(key: StorageKeys.accessToken);
    if (token == null || token.isEmpty) return;
    final params = {
      'token': token,
      if (_mobileUserKey().isNotEmpty) 'user_key': _mobileUserKey(),
      if (ApiEndpoints.mobileApiKey.isNotEmpty)
        'api_key': ApiEndpoints.mobileApiKey,
    };
    uploadedProfileImageUrl.value = Uri.parse(
      '${ApiEndpoints.mainDomain}${ApiEndpoints.myProfileImage}',
    ).replace(queryParameters: params).toString();
  }

  void clearProfile() {
    profileImage.value = null;
    profile.clear();
    uploadedProfileImageUrl.value = '';
  }

  void updateDisplayName(String name) {
    final value = name.trim();
    if (value.isEmpty) return;
    profile['name'] = value;
    profile.refresh();
    StorageHelper.setValue(
      key: StorageKeys.userProfile,
      value: jsonEncode(Map<String, dynamic>.from(profile)),
    );
  }

  String _mobileUserKey() {
    for (final key in ['id', 'user_id', 'mobile', 'username', 'email']) {
      final value = profile[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  Future<void> pickAndCropImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'HariPrabodham Smruti',
          toolbarColor: primaryColor,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'HariPrabodham Smruti'),
      ],
    );

    if (croppedFile != null) {
      profileImage.value = File(croppedFile.path);
    }
  }
}
