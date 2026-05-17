import 'package:get/get.dart';
import 'package:harismruti/utils/app_routes.dart';
import 'package:harismruti/utils/storage_helper.dart';

class AuthRedirectHelper {
  const AuthRedirectHelper._();

  static bool ensureLoggedIn() {
    if (StorageHelper.isLogin()) return true;
    Get.toNamed(AppRoutes.loginMobile);
    return false;
  }
}
