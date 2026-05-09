import 'package:get/get.dart';

class NavigationHelper {
  static void navigateTo(String routeName, {dynamic arguments}) {
    Get.toNamed(routeName, arguments: arguments);
  }

  static void navigateAndRemoveAll(String routeName, {dynamic arguments}) {
    Get.offAllNamed(routeName, arguments: arguments);
  }

  static void navigateAndReplace(String routeName, {dynamic arguments}) {
    Get.offNamed(routeName, arguments: arguments);
  }

  static void goBack() {
    if (Get.previousRoute.isNotEmpty) {
      Get.back();
    }
  }

  static void goBackWithResult(dynamic result) {
    Get.back(result: result);
  }
}
