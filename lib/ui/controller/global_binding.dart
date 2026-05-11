import 'package:get/get.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';

class GlobalBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(GalleryController(), permanent: true);
    Get.lazyPut<SmrutiSectionController>(
      () => SmrutiSectionController(),
      fenix: true,
    );
  }
}
