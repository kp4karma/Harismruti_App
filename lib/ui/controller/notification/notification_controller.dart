import 'package:get/get.dart';

class NotificationController extends GetxController {
  RxBool isNotificationNavigation = false.obs;

  void toggleNotificationNavigation() {
    isNotificationNavigation.value = !isNotificationNavigation.value;
  }
}
