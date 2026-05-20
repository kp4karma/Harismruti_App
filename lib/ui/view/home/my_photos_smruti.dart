import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/helper/image_service.dart';
import 'package:harismruti/ui/controller/my_photos_controller.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

class MyPhotosSmruti extends StatelessWidget {
  const MyPhotosSmruti({super.key});

  MyPhotosController get controller => Get.find<MyPhotosController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final requiredDone = controller.requiredPoses
          .where((pose) => controller.photoForPose(pose) != null)
          .length;
      final status = !StorageHelper.isLogin()
          ? 'Login required'
          : switch (controller.overallReviewStatus) {
              MyPhotoReviewStatus.verified => 'Verified',
              MyPhotoReviewStatus.pending => 'Verification pending',
              MyPhotoReviewStatus.rejected => 'Rejected - upload again',
              MyPhotoReviewStatus.draft => '$requiredDone/3 face views ready',
            };

      return GestureDetector(
        onTap: () {
          if (!AuthRedirectHelper.ensureLoggedIn()) return;
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const MyPhoneGuideScreen()),
          );
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  CupertinoIcons.person_crop_circle_badge_checkmark,
                  color: primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Smruti',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add training photos to find your smruti.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withAlpha(140),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      status,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_right, color: primaryColor),
            ],
          ),
        ),
      );
    });
  }
}

class MyPhoneGuideScreen extends StatelessWidget {
  const MyPhoneGuideScreen({super.key});

  MyPhotosController get controller => Get.find<MyPhotosController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF8F6F3),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'My Smruti',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white.withAlpha(135),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Obx(() {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.of(context).padding.top + kToolbarHeight + 10,
                  16,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RequiredCaptureGrid(controller: controller),
                    const SizedBox(height: 12),
                    _GalleryUploadCard(controller: controller),
                    if (controller.helperMessage.value.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _MessageBox(message: controller.helperMessage.value),
                    ],
                    const SizedBox(height: 12),
                    _SubmitCard(controller: controller),
                    const SizedBox(height: 16),
                    _MatchedPhotosSection(controller: controller),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/*
class _StepGuide extends StatelessWidget {
  final MyPhotosController controller;

  const _StepGuide({required this.controller});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _GuideStep(
        '1',
        'Take Front Pic',
        controller.photoForPose(MyPhotoPose.front) != null,
      ),
      _GuideStep(
        '2',
        'Take Left Side Pic',
        controller.photoForPose(MyPhotoPose.left) != null,
      ),
      _GuideStep(
        '3',
        'Take Right Side Pic',
        controller.photoForPose(MyPhotoPose.right) != null,
      ),
      _GuideStep(
        '4',
        'Add any 4 gallery images',
        controller.otherPhotos.length >= 4,
      ),
    ];

    if (MediaQuery.of(context).size.width > 0) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            for (final step in steps)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: step.done
                          ? const Color(0xFF167A3C)
                          : primaryColor.withAlpha(24),
                      child: Text(
                        step.done ? '✓' : step.index,
                        style: TextStyle(
                          color: step.done ? Colors.white : primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        step.title
                            .replaceAll('Take ', '')
                            .replaceAll(' Pic', '')
                            .replaceAll('Add any 4 gallery images', 'Gallery'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final step in steps)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: step.done
                      ? const Color(0xFF167A3C)
                      : primaryColor.withAlpha(24),
                  child: Text(
                    step.done ? '✓' : step.index,
                    style: TextStyle(
                      color: step.done ? Colors.white : primaryColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GuideStep {
  final String index;
  final String title;
  final bool done;

  const _GuideStep(this.index, this.title, this.done);
}

*/
class _RequiredCaptureGrid extends StatelessWidget {
  final MyPhotosController controller;

  const _RequiredCaptureGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      CupertinoIcons.camera_viewfinder,
                      color: primaryColor,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Required Live Selfie',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _StatusPill(
                    label:
                        '${controller.requiredPoses.where((pose) => controller.photoForPose(pose) != null).length}/3',
                    color: primaryColor,
                    background: primaryColor.withAlpha(14),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final pose in controller.requiredPoses) ...[
                _CapturePoseRow(
                  pose: pose,
                  item: controller.photoForPose(pose),
                  locked: controller.isPoseLocked(pose),
                  onTap: () => _openCapture(context, pose),
                ),
                if (pose != MyPhotoPose.right) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _openCapture(BuildContext context, MyPhotoPose pose) {
    if (controller.isPoseLocked(pose)) {
      controller.helperMessage.value =
          'This photo is locked. Retake is available only if admin rejects it.';
      return;
    }
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => MyPhoneCaptureScreen(pose: pose)),
    );
  }
}

class _CapturePoseRow extends StatelessWidget {
  final MyPhotoPose pose;
  final MyPhotoItem? item;
  final bool locked;
  final VoidCallback onTap;

  const _CapturePoseRow({
    required this.pose,
    required this.item,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = item == null
        ? 'Capture'
        : locked
        ? item!.reviewStatus.label
        : 'Retake';
    final statusColor = item == null || !locked
        ? primaryColor
        : item!.reviewStatus.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 78,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F6F3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: item == null
                  ? _FaceFramePlaceholder(pose: pose)
                  : _MyPhotoImage(item: item!),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pose.label} face',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    pose.instruction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black.withAlpha(130),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceFramePlaceholder extends StatelessWidget {
  final MyPhotoPose pose;

  const _FaceFramePlaceholder({required this.pose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEDE8E5),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            CupertinoIcons.person_crop_rectangle,
            color: primaryColor,
            size: 34,
          ),
          Positioned(
            left: 14,
            top: 14,
            child: _Corner(color: primaryColor, topLeft: true),
          ),
          Positioned(
            right: 14,
            top: 14,
            child: _Corner(color: primaryColor, topRight: true),
          ),
          Positioned(
            left: 14,
            bottom: 14,
            child: _Corner(color: primaryColor, bottomLeft: true),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: _Corner(color: primaryColor, bottomRight: true),
          ),
          Positioned(
            bottom: 34,
            left: 8,
            right: 8,
            child: Text(
              pose.instruction,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final Color color;
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  const _Corner({
    required this.color,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      width: 18,
      child: CustomPaint(
        painter: _CornerPainter(
          color: color,
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  _CornerPainter({
    required this.color,
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    if (topLeft) {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, 0)
        ..lineTo(0, size.height);
    } else if (topRight) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height);
    } else if (bottomLeft) {
      path
        ..moveTo(0, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height);
    } else if (bottomRight) {
      path
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GalleryUploadCard extends StatelessWidget {
  final MyPhotosController controller;

  const _GalleryUploadCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final otherPhotos = controller.otherPhotos;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gallery Photos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed:
                    controller.canEditUploads && controller.remainingSlots > 0
                    ? () => _pickOtherPhotos(context)
                    : null,
                icon: const Icon(CupertinoIcons.add, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(foregroundColor: primaryColor),
              ),
            ],
          ),
          Text(
            '${otherPhotos.length} selected. Add gallery photos if you want.',
            style: TextStyle(
              color: Colors.black.withAlpha(130),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: math.max(4, otherPhotos.length),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index < otherPhotos.length) {
                  return _SmallPhotoTile(item: otherPhotos[index]);
                }
                return _EmptyGallerySlot(
                  onTap: () => _pickOtherPhotos(context),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickOtherPhotos(BuildContext context) async {
    if (!controller.canEditUploads) {
      controller.helperMessage.value =
          'Uploaded photos are locked unless admin rejects them.';
      return;
    }
    final paths = await ImagePickerHelper.pickGalleryImages(
      allowMultiple: true,
      enableCrop: false,
    );
    final allowed = paths.take(controller.remainingSlots).toList();
    await controller.addOtherPhotos(allowed);
  }
}

class _SmallPhotoTile extends StatelessWidget {
  final MyPhotoItem item;

  const _SmallPhotoTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MyPhotosController>();
    return GestureDetector(
      onTap: () => _showPhotoActions(context, item),
      child: SizedBox(
        width: 70,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _MyPhotoImage(item: item),
            ),
            if (controller.canEditPhoto(item))
              Positioned(
                right: 5,
                top: 5,
                child: GestureDetector(
                  onTap: () => controller.removePhoto(item),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(115),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MyPhotoImage extends StatelessWidget {
  final MyPhotoItem item;

  const _MyPhotoImage({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.hasLocalFile) {
      return Image.file(File(item.path), fit: BoxFit.cover);
    }
    if (item.hasRemoteImage) {
      return NetworkImageWithLoader(imageUrl: item.remoteUrl!, title: '');
    }
    return Container(
      color: primaryColor.withAlpha(14),
      child: Icon(CupertinoIcons.photo, color: primaryColor),
    );
  }
}

class _EmptyGallerySlot extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyGallerySlot({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        decoration: BoxDecoration(
          color: primaryColor.withAlpha(14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(CupertinoIcons.photo, color: primaryColor),
      ),
    );
  }
}

class _SubmitCard extends StatelessWidget {
  final MyPhotosController controller;

  const _SubmitCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        controller.canSubmitTrainingSet && !controller.isUploading.value;
    final label = switch (controller.overallReviewStatus) {
      MyPhotoReviewStatus.verified => 'Verified',
      MyPhotoReviewStatus.pending => 'Pending Admin Approval',
      MyPhotoReviewStatus.rejected => 'Submit for Approval',
      MyPhotoReviewStatus.draft => 'Submit for Approval',
    };
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canSubmit
            ? controller.submitForReview
            : controller.isVerified
            ? controller.fetchServerMatches
            : null,
        icon: controller.isUploading.value || controller.isFetchingMatches.value
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(
                controller.isVerified
                    ? CupertinoIcons.checkmark_shield_fill
                    : CupertinoIcons.cloud_upload,
              ),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade700,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  final String message;

  const _MessageBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withAlpha(14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
    );
  }
}

class _MatchedPhotosSection extends StatelessWidget {
  final MyPhotosController controller;

  const _MatchedPhotosSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.overallReviewStatus == MyPhotoReviewStatus.draft) {
      return const SizedBox.shrink();
    }
    if (!controller.isVerified) {
      return _ReviewStatePanel(controller: controller);
    }
    final photos = controller.matchedPhotos;
    if (controller.isFetchingMatches.value && photos.isEmpty) {
      return const _ServerFetchPanel();
    }
    if (photos.isEmpty) {
      return _ReviewStatePanel(controller: controller);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Found photos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            _StatusPill(
              label: 'Verified',
              color: const Color(0xFF167A3C),
              background: const Color(0xFF167A3C).withAlpha(18),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          itemCount: photos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, index) {
            final item = photos[index];
            return _MatchedPhotoTile(photo: item);
          },
        ),
      ],
    );
  }
}

class _ReviewStatePanel extends StatelessWidget {
  final MyPhotosController controller;

  const _ReviewStatePanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.photos.isEmpty) return const SizedBox.shrink();
    final status = controller.overallReviewStatus;
    final title = switch (status) {
      MyPhotoReviewStatus.verified => 'Server fetching',
      MyPhotoReviewStatus.pending => 'Waiting for admin approval',
      MyPhotoReviewStatus.rejected => 'Upload needs changes',
      MyPhotoReviewStatus.draft => 'Ready to upload',
    };
    final message = switch (status) {
      MyPhotoReviewStatus.verified =>
        'Verified. We are fetching your matched smruti photos from the server.',
      MyPhotoReviewStatus.pending =>
        'Your live selfies are submitted. Editing is locked until admin review finishes.',
      MyPhotoReviewStatus.rejected =>
        'Rejected photos are visible above. Retake or remove them, then submit again.',
      MyPhotoReviewStatus.draft =>
        'Complete Front, Left and Right live selfies, then submit for approval.',
    };
    final color = status.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(status.icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.black.withAlpha(135),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerFetchPanel extends StatelessWidget {
  const _ServerFetchPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Fetching your smruti photos from server',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchedPhotoTile extends StatelessWidget {
  final GalleryPhoto photo;

  const _MatchedPhotoTile({required this.photo});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          NetworkImageWithLoader(imageUrl: photo.thumbnailUrl, title: ''),
          Positioned(
            left: 8,
            bottom: 8,
            child: _StatusPill(
              label: photo.title ?? 'Smruti',
              color: Colors.white,
              background: Colors.black.withAlpha(115),
            ),
          ),
        ],
      ),
    );
  }
}

void _showPhotoActions(BuildContext context, MyPhotoItem item) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: Colors.white.withAlpha(235),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionRow(
                icon: CupertinoIcons.hand_thumbsup,
                label: 'Like',
                onTap: () => Navigator.pop(context),
              ),
              _ActionRow(
                icon: CupertinoIcons.share,
                label: 'Share',
                onTap: () => Navigator.pop(context),
              ),
              _ActionRow(
                icon: CupertinoIcons.arrow_down_to_line,
                label: 'Download',
                onTap: () => Navigator.pop(context),
              ),
              _ActionRow(
                icon: CupertinoIcons.exclamationmark_bubble,
                label: 'Report irrelevant',
                color: const Color(0xFFC62828),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? primaryColor;
    return ListTile(
      leading: Icon(icon, color: resolved),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
      onTap: onTap,
    );
  }
}

class MyPhoneCaptureScreen extends StatefulWidget {
  final MyPhotoPose pose;

  const MyPhoneCaptureScreen({super.key, required this.pose});

  @override
  State<MyPhoneCaptureScreen> createState() => _MyPhoneCaptureScreenState();
}

class _MyPhoneCaptureScreenState extends State<MyPhoneCaptureScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _quality = 0.18;
  Timer? _timer;
  CameraController? _cameraController;
  bool _taking = false;
  bool _checking = false;
  bool _cameraReady = false;
  bool _autoProbePaused = false;
  int _faceMisses = 0;
  String _reason = 'Place your face inside the frame';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off).catchError((_) {});
      await _prepareCameraForFace(controller);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraReady = true;
        _reason = 'Hold your face inside the frame';
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (_) {
        _probeFaceQuality();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _quality = 0.12;
        _reason = 'Camera permission required';
      });
    }
  }

  Future<void> _probeFaceQuality() async {
    final camera = _cameraController;
    if (camera == null ||
        !camera.value.isInitialized ||
        camera.value.isTakingPicture ||
        _checking ||
        _taking ||
        _autoProbePaused) {
      return;
    }
    _checking = true;
    try {
      final file = await camera.takePicture();
      final controller = Get.find<MyPhotosController>();
      final result = await controller.validatePhoto(file.path, widget.pose);
      if (!mounted) return;

      if (result.isValid) {
        _faceMisses = 0;
        setState(() {
          _quality = 1;
          _reason = 'Face recognized successfully';
        });
        _timer?.cancel();
        _timer = null;
        await _acceptCapturedFile(file.path);
        return;
      }

      final nextScore = _scoreForReason(result.message);
      final needsLight = _needsMoreLight(result.message);
      final canUseFallback = _canUseCameraFallback(result.message);
      if (canUseFallback) {
        _faceMisses++;
      } else {
        _faceMisses = 0;
      }

      if (canUseFallback && _faceMisses >= 2) {
        setState(() {
          _quality = 0.92;
          _reason = 'Face looks clear. Capturing for verification...';
        });
        _timer?.cancel();
        _timer = null;
        await _acceptCapturedFile(file.path);
        return;
      }

      setState(() {
        _quality = canUseFallback
            ? (_faceMisses == 1 ? 0.74 : 0.86)
            : nextScore;
        _autoProbePaused = false;
        _reason = needsLight
            ? 'Face the light and hold still while scanning.'
            : result.message;
      });
      unawaited(File(file.path).delete().catchError((_) => File(file.path)));
    } catch (_) {
      if (mounted) {
        setState(() {
          _quality = 0.2;
          _reason = 'Keep still while scanning';
        });
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _acceptCapturedFile(String path) async {
    _taking = true;
    final controller = Get.find<MyPhotosController>();
    final ok = await controller.addRequiredPhoto(
      path: path,
      pose: widget.pose,
      allowFaceDetectionFallback: true,
    );
    if (!mounted) return;
    if (ok) {
      _timer?.cancel();
      _timer = null;
      Navigator.pop(context);
      return;
    }
    setState(() {
      _taking = false;
      _autoProbePaused = true;
      _quality = 0.52;
      _reason = controller.helperMessage.value;
    });
  }

  Future<void> _prepareCameraForFace(CameraController camera) async {
    await camera.setFocusMode(FocusMode.auto).catchError((_) {});
    await camera.setExposureMode(ExposureMode.auto).catchError((_) {});
    await camera.setFocusPoint(const Offset(0.5, 0.45)).catchError((_) {});
    await camera.setExposurePoint(const Offset(0.5, 0.45)).catchError((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 220));
  }

  bool _needsMoreLight(String reason) {
    final lower = reason.toLowerCase();
    return lower.contains('dark') ||
        lower.contains('light') ||
        lower.contains('brightness') ||
        lower.contains('exposure');
  }

  bool _canUseCameraFallback(String reason) {
    final lower = reason.toLowerCase();
    return lower.contains('face not detected') ||
        lower.contains('could not read face angle') ||
        lower.contains('could not check face direction');
  }

  double _scoreForReason(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('face not detected') || lower.contains('center')) {
      return 0.74;
    }
    if (lower.contains('multiple')) return 0.32;
    if (lower.contains('far') || lower.contains('closer')) return 0.48;
    if (lower.contains('left') || lower.contains('right')) return 0.62;
    if (lower.contains('small') || lower.contains('framed')) return 0.55;
    if (lower.contains('direction') || lower.contains('angle')) return 0.68;
    return 0.74;
  }

  @override
  Widget build(BuildContext context) {
    final score = (_quality * 100).clamp(0, 100).round();
    final ready = score >= 90;
    final good = score >= 82;
    final statusColor = ready
        ? const Color(0xFF167A3C)
        : good
        ? primaryColor
        : const Color(0xFFC62828);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.chevron_left,
                        color: primaryColor,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              Text(
                '${widget.pose.label} Face',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Please look into the camera and hold still',
                style: TextStyle(
                  color: Colors.black.withAlpha(120),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              _AnimatedFaceScanner(
                animation: _controller,
                quality: _quality,
                pose: widget.pose,
                color: statusColor,
                cameraController: _cameraController,
                cameraReady: _cameraReady,
              ),
              const SizedBox(height: 34),
              _ScanStatusPill(reason: _reason, color: statusColor),
              const SizedBox(height: 18),
              _ProgressBubble(score: score, color: statusColor, ready: ready),
              const SizedBox(height: 16),
              _QualityChecklist(score: score, color: statusColor),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ready ? statusColor : primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primaryColor.withAlpha(120),
                    disabledForegroundColor: Colors.white.withAlpha(210),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _taking
                        ? 'Taking Photo...'
                        : ready
                        ? 'Capturing automatically...'
                        : 'Scanning Face...',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedFaceScanner extends StatelessWidget {
  final Animation<double> animation;
  final double quality;
  final MyPhotoPose pose;
  final Color color;
  final CameraController? cameraController;
  final bool cameraReady;

  const _AnimatedFaceScanner({
    required this.animation,
    required this.quality,
    required this.pose,
    required this.color,
    required this.cameraController,
    required this.cameraReady,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return SizedBox(
          height: 360,
          width: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    height: 286,
                    width: 262,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(190),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(color: Colors.white.withAlpha(150)),
                    ),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Container(
                  height: 230,
                  width: 230,
                  color: color.withAlpha(22),
                  child:
                      cameraReady &&
                          cameraController != null &&
                          cameraController!.value.isInitialized
                      ? _SquareCameraPreview(controller: cameraController!)
                      : Icon(
                          CupertinoIcons.camera_viewfinder,
                          color: color.withAlpha(130),
                          size: 72,
                        ),
                ),
              ),
              CustomPaint(
                size: const Size(246, 246),
                painter: _SquareFramePainter(color: color),
              ),
              Positioned(
                left: 33,
                right: 33,
                top: 70 + animation.value * 176,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: color.withAlpha(150),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SquareCameraPreview extends StatelessWidget {
  final CameraController controller;

  const _SquareCameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);

    final previewAspectRatio = previewSize.height / previewSize.width;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 230,
            height: 230 / previewAspectRatio,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _SquareFramePainter extends CustomPainter {
  final Color color;

  const _SquareFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 48.0;
    final rect = Rect.fromLTWH(6, 6, size.width - 12, size.height - 12);

    canvas.drawLine(
      rect.topLeft,
      rect.topLeft.translate(cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft.translate(0, cornerLength),
      paint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight.translate(-cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight.translate(0, cornerLength),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft.translate(cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft.translate(0, -cornerLength),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight.translate(-cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight.translate(0, -cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SquareFramePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ScanStatusPill extends StatelessWidget {
  final String reason;
  final Color color;

  const _ScanStatusPill({required this.reason, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(210),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(55)),
      ),
      child: Text(
        reason,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProgressBubble extends StatelessWidget {
  final int score;
  final Color color;
  final bool ready;

  const _ProgressBubble({
    required this.score,
    required this.color,
    required this.ready,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      width: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 2.5,
            color: color,
            backgroundColor: Colors.black.withAlpha(14),
          ),
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: ready
                  ? Icon(CupertinoIcons.checkmark_alt, color: color, size: 20)
                  : Text(
                      '$score%',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityChecklist extends StatelessWidget {
  final int score;
  final Color color;

  const _QualityChecklist({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    final checks = [
      _Check('Same person', score >= 82),
      _Check('Eyes open', score >= 86),
      _Check('Good exposure', score >= 90),
      _Check('Not blurry', score >= 94),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: checks
          .map(
            (check) => _StatusPill(
              label: check.label,
              color: check.done ? color : const Color(0xFFC62828),
              background: Colors.white.withAlpha(210),
            ),
          )
          .toList(),
    );
  }
}

class _Check {
  final String label;
  final bool done;

  const _Check(this.label, this.done);
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
