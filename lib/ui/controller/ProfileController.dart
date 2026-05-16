// lib/ui/controller/profile_controller.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ProfileController extends GetxController {
  var profileImage = Rxn<File>();
  final RxMap<String, dynamic> profile = <String, dynamic>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadStoredProfile();
  }

  void loadStoredProfile() {
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
      'Hari Smruti User',
    ]);
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
    final avatar = profile['avatar']?.toString().trim() ?? '';
    if (avatar.isEmpty || avatar == 'img/default-avatar.jpg') return '';
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return avatar;
    }
    return 'https://staging-admin.suhrad.digital/${avatar.replaceFirst(RegExp(r'^/+'), '')}';
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
          toolbarTitle: 'Hari Smruti',
          toolbarColor: primaryColor,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Hari Smruti'),
      ],
    );

    if (croppedFile != null) {
      profileImage.value = File(croppedFile.path);
    }
  }
}
