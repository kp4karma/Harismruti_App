import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/utils/storage_helper.dart';

class ThemeController extends GetxController {
  ThemeController()
    : isDarkMode = StorageHelper.getValue<bool>(
        key: StorageKeys.darkMode,
        defaultValue: false,
      )!.obs;

  final RxBool isDarkMode;

  ThemeMode get themeMode =>
      isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  void setDarkMode(bool enabled) {
    if (isDarkMode.value == enabled) return;
    isDarkMode.value = enabled;
    StorageHelper.setValue(key: StorageKeys.darkMode, value: enabled);
  }
}
