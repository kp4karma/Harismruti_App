import 'package:get/get.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/ui/controller/auth_controller.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/controller/my_diary_controller.dart';
import 'package:harismruti/ui/controller/my_photos_controller.dart';

class GlobalBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthController(), permanent: true);
    Get.put(GalleryController(), permanent: true);
    Get.put(MyPhotosController(), permanent: true);
    Get.put(MyDiaryController(), permanent: true);
    Get.lazyPut<SmrutiSectionController>(
      () => SmrutiSectionController(),
      fenix: true,
    );
  }
}
