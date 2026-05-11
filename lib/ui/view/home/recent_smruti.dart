import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_swiper_view/flutter_swiper_view.dart';
import 'package:flutter_tilt/flutter_tilt.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class RecentSmruti extends StatefulWidget {
  final bool autoplay;
  const RecentSmruti({super.key, this.autoplay = true});

  @override
  State<RecentSmruti> createState() => _RecentSmrutiState();
}

class _RecentSmrutiState extends State<RecentSmruti> {
  AxisDirection _axisDirection = AxisDirection.right;
  final GalleryController galleryController = Get.find<GalleryController>();

  void _handleTilt(TiltDataModel data) {
    final double tiltX = data.angle.dy;

    if (tiltX > 2.5) {
      setState(() {
        _axisDirection = AxisDirection.left;
      });
    } else if (tiltX < -2.5) {
      setState(() {
        _axisDirection = AxisDirection.right;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final photos = galleryController.recentPhotos;
      if (galleryController.isLoading.value && photos.isEmpty) {
        return GallerySectionLoader(height: 300.h);
      }
      if (photos.isEmpty) {
        return GalleryEmptyState(height: 220.h);
      }

      return Tilt(
        tiltConfig: TiltConfig(
          enableGestureSensors: true,
          enableGestureTouch: false,
          enableGestureHover: false,
          sensorFactor: 30,
          angle: 5,
          direction: [TiltDirection.left, TiltDirection.right],
          sensorMoveDuration: const Duration(milliseconds: 100),
          sensorRevertFactor: 0.05,
          enableSensorRevert: true,
        ),
        shadowConfig: ShadowConfig(color: Colors.white, disable: true),
        onGestureMove: (data, _) => _handleTilt(data),
        child: Swiper(
          itemBuilder: (BuildContext context, int index) {
            final photo = photos[index];
            return Card(
              elevation: 0,
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: NetworkImageWithLoader(
                  imageUrl: photo.thumbnailUrl,
                  title: photo.title ?? 'Recent Smruti',
                  headers: galleryController.imageHeaders,
                ),
              ),
            );
          },
          itemCount: photos.length,
          itemWidth: 300.h,
          itemHeight: 300.h,
          layout: SwiperLayout.STACK,
          loop: photos.length > 1,
          axisDirection: _axisDirection,
          autoplayDisableOnInteraction: false,
          physics: const BouncingScrollPhysics(),
          autoplay: widget.autoplay && photos.length > 1,
          scrollDirection: Axis.horizontal,
        ),
      );
    });
  }
}
