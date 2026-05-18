import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_routes.dart';
import 'package:harismruti/utils/storage_helper.dart';

class AuthRedirectHelper {
  const AuthRedirectHelper._();

  static bool ensureLoggedIn() {
    if (StorageHelper.isLogin()) return true;
    if (Get.isDialogOpen == true) return false;

    Get.dialog(
      AlertDialog(
        title: const Text('Sign in required'),
        content: const Text('Please sign in first to continue.'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              Get.back();
              Get.toNamed(AppRoutes.loginMobile);
            },
            child: const Text('Sign in now'),
          ),
        ],
      ),
    );
    return false;
  }
}
