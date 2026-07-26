import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/bootstrap.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/ui/controller/my_photos_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

double _galleryPhotoAspectRatio(GalleryPhoto photo) {
  final width = photo.width;
  final height = photo.height;
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 1.15;
  }
  return (width / height).clamp(0.72, 1.5);
}

class MyPhotosSmruti extends StatelessWidget {
  const MyPhotosSmruti({super.key});

  MyPhotosController get controller => Get.find<MyPhotosController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final matchedPhotos = controller.matchedPhotos;
      if (matchedPhotos.isNotEmpty) {
        return SizedBox(
          height: 190,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: matchedPhotos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final photo = matchedPhotos[index];
              return GestureDetector(
                onTap: () {
                  if (!AuthRedirectHelper.ensureLoggedIn()) return;
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => GalleryFullscreenViewer(
                        photos: matchedPhotos.toList(growable: false),
                        initialIndex: index,
                        title: 'My Smruti',
                      ),
                    ),
                  );
                },
                child: SizedBox(
                  width: 142,
                  child: _MatchedPhotoTile(photo: photo),
                ),
              );
            },
          ),
        );
      }

      final requiredDone = controller.requiredPoses
          .where((pose) => controller.photoForPose(pose) != null)
          .length;
      final status = !StorageHelper.isLogin()
          ? 'Login required'
          : !controller.isFlowInitialized.value
          ? 'Checking status'
          : controller.smrutiLookupFinished
          ? 'Smruti not found'
          : switch (controller.overallReviewStatus) {
              MyPhotoReviewStatus.verified => 'Verified',
              MyPhotoReviewStatus.pending => 'Verification pending',
              MyPhotoReviewStatus.rejected => 'Rejected - upload again',
              MyPhotoReviewStatus.draft =>
                requiredDone > 0 ? 'Selfie ready to submit' : 'Add your selfie',
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
                      controller.hasMatchedSmruti
                          ? 'Photos linked with your phone number.'
                          : !controller.isFlowInitialized.value
                          ? 'Checking your Smruti status.'
                          : controller.smrutiLookupFinished
                          ? 'No matching Smruti photos are available.'
                          : 'Add a live front selfie to find your smruti.',
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
              if (controller.isFlowInitialized.value)
                Icon(CupertinoIcons.chevron_right, color: primaryColor),
            ],
          ),
        ),
      );
    });
  }
}

class MyPhoneGuideScreen extends StatefulWidget {
  const MyPhoneGuideScreen({super.key});

  @override
  State<MyPhoneGuideScreen> createState() => _MyPhoneGuideScreenState();
}

class _MyPhoneGuideScreenState extends State<MyPhoneGuideScreen> {
  MyPhotosController get controller => Get.find<MyPhotosController>();

  bool _showEditor = false;
  Worker? _photosWorker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.refreshSmrutiFlow();
    });
    _showEditor = controller.canShowUploadSection;
    _photosWorker = ever<List<MyPhotoItem>>(controller.photos, (_) {
      if (!mounted || !_showEditor) return;
      if (controller.isVerified) {
        setState(() => _showEditor = false);
      }
    });
  }

  @override
  void dispose() {
    _photosWorker?.dispose();
    super.dispose();
  }

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
        if (!controller.isFlowInitialized.value &&
            controller.photos.isEmpty &&
            controller.matchedPhotos.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: primaryColor),
          );
        }

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
                    if ((controller.photos.isNotEmpty ||
                            controller.isServerPendingSmruti.value) &&
                        !controller.smrutiLookupFinished) ...[
                      _ReviewStatePanel(controller: controller),
                      const SizedBox(height: 12),
                    ],
                    if (controller.canShowUploadSection)
                      _EditorToggleButton(
                        controller: controller,
                        isOpen: _showEditor,
                        onPressed: () {
                          setState(() => _showEditor = !_showEditor);
                        },
                      ),
                    if (_showEditor && controller.canShowUploadSection) ...[
                      const SizedBox(height: 12),
                      _FrontSelfieCard(controller: controller),
                    ],
                    if (controller.helperMessage.value.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      if (!_shouldHideHelperMessage(controller))
                        _MessageBox(message: controller.helperMessage.value),
                    ],
                    if (_showEditor && controller.canShowUploadSection) ...[
                      const SizedBox(height: 12),
                      _SubmitCard(
                        controller: controller,
                        onSubmitted: () {
                          if (!mounted) return;
                          setState(
                            () => _showEditor = controller.isPendingReview,
                          );
                        },
                      ),
                    ],
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

class _EditorToggleButton extends StatelessWidget {
  final MyPhotosController controller;
  final bool isOpen;
  final VoidCallback onPressed;

  const _EditorToggleButton({
    required this.controller,
    required this.isOpen,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = isOpen
        ? 'Close Photo Form'
        : switch (controller.overallReviewStatus) {
            MyPhotoReviewStatus.rejected => 'Edit & Resubmit Photos',
            MyPhotoReviewStatus.pending => 'Add / Edit Photos',
            MyPhotoReviewStatus.verified => 'Verified',
            MyPhotoReviewStatus.draft =>
              controller.photos.isEmpty ? 'Add Photos' : 'Add / Edit Photos',
          };

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          isOpen
              ? CupertinoIcons.chevron_up
              : CupertinoIcons.photo_on_rectangle,
        ),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
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
class _FrontSelfieCard extends StatelessWidget {
  final MyPhotosController controller;

  const _FrontSelfieCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    const pose = MyPhotoPose.front;
    final item = controller.photoForPose(pose);
    final locked = controller.isPoseLocked(pose);
    final hasPhoto = item != null;
    final statusColor = hasPhoto && locked
        ? item.reviewStatus.color
        : hasPhoto
        ? const Color(0xFF167A3C)
        : primaryColor;
    final statusLabel = hasPhoto && locked
        ? item.reviewStatus.label
        : hasPhoto
        ? 'Ready'
        : 'Required';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              _StatusPill(
                label: statusLabel,
                color: statusColor,
                background: statusColor.withAlpha(14),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => _openCapture(context),
            child: Container(
              height: 190,
              width: 190,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                border: Border.all(
                  color: hasPhoto
                      ? statusColor.withAlpha(160)
                      : primaryColor.withAlpha(70),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withAlpha(hasPhoto ? 26 : 14),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: hasPhoto
                  ? _MyPhotoImage(item: item)
                  : _FaceFramePlaceholder(pose: pose),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            pose.instruction,
            style: TextStyle(
              color: Colors.black.withAlpha(130),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openCapture(context),
              icon: Icon(
                hasPhoto
                    ? CupertinoIcons.arrow_2_circlepath
                    : CupertinoIcons.camera_fill,
                size: 17,
              ),
              label: Text(
                hasPhoto && locked
                    ? item.reviewStatus.label
                    : hasPhoto
                    ? 'Retake Selfie'
                    : 'Capture Selfie',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor.withAlpha(90)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCapture(BuildContext context) {
    const pose = MyPhotoPose.front;
    if (controller.isPoseLocked(pose)) {
      controller.helperMessage.value =
          'This photo is locked. Retake is available only if admin rejects it.';
      return;
    }
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => const MyPhoneCaptureScreen(pose: pose),
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

class _MyPhotoImage extends StatelessWidget {
  final MyPhotoItem item;

  const _MyPhotoImage({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.hasLocalFile) {
      return Image.file(File(item.path), fit: BoxFit.cover);
    }
    if (item.hasRemoteImage) {
      final controller = Get.find<MyPhotosController>();
      return NetworkImageWithLoader(
        imageUrl: item.remoteUrl!,
        title: '',
        headers: controller.imageHeaders,
      );
    }
    return Container(
      color: primaryColor.withAlpha(14),
      child: Icon(CupertinoIcons.photo, color: primaryColor),
    );
  }
}

class _SubmitCard extends StatelessWidget {
  final MyPhotosController controller;
  final VoidCallback? onSubmitted;

  const _SubmitCard({required this.controller, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    final isSubmitting = controller.isUploading.value;
    final isFetching = controller.isFetchingMatches.value;
    final canSubmit =
        controller.canSubmitTrainingSet && !isSubmitting && !isFetching;
    final label = isSubmitting
        ? 'Submitting...'
        : isFetching
        ? 'Fetching Smruti...'
        : switch (controller.overallReviewStatus) {
            MyPhotoReviewStatus.verified => 'Verified',
            MyPhotoReviewStatus.pending =>
              controller.hasUnsavedChanges
                  ? 'Update & Submit for Approval'
                  : 'Pending Admin Approval',
            MyPhotoReviewStatus.rejected => 'Submit for Approval',
            MyPhotoReviewStatus.draft => 'Submit for Approval',
          };
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canSubmit
            ? () async {
                await controller.submitForReview();
                if (controller.isPendingReview) {
                  onSubmitted?.call();
                }
              }
            : controller.isVerified
            ? controller.fetchServerMatches
            : null,
        icon: isSubmitting || isFetching
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
          disabledBackgroundColor: isSubmitting || isFetching
              ? primaryColor
              : Colors.grey.shade300,
          disabledForegroundColor: isSubmitting || isFetching
              ? Colors.white
              : Colors.grey.shade700,
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
    if (!controller.smrutiLookupFinished || !controller.isFlowInitialized.value) {
      return const SizedBox.shrink();
    }
    final photos = controller.matchedPhotos;
    if (controller.isFetchingMatches.value && photos.isEmpty) {
      return const _ServerFetchPanel();
    }
    if (photos.isEmpty) {
      if (controller.overallReviewStatus != MyPhotoReviewStatus.verified) {
        return const SizedBox.shrink();
      }
      return const _SmrutiNotFoundPanel();
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
        MasonryGridView.count(
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          itemCount: photos.length,
          crossAxisCount: MediaQuery.sizeOf(context).width >= 680 ? 3 : 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          itemBuilder: (context, index) {
            final item = photos[index];
            return AspectRatio(
              aspectRatio: _galleryPhotoAspectRatio(item),
              child: _MatchedPhotoTile(photo: item),
            );
          },
        ),
      ],
    );
  }
}

bool _shouldHideHelperMessage(MyPhotosController controller) {
  if (!controller.isFlowInitialized.value) return true;
  if (controller.hasMatchedSmruti) return true;
  final status = controller.overallReviewStatus;
  if (status == MyPhotoReviewStatus.pending) return true;
  if (status == MyPhotoReviewStatus.verified && !controller.smrutiLookupFinished) {
    return true;
  }
  return false;
}

class _ReviewStatePanel extends StatelessWidget {
  final MyPhotosController controller;

  const _ReviewStatePanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.photos.isEmpty && !controller.isServerPendingSmruti.value) {
      return const SizedBox.shrink();
    }
    final status = controller.isServerPendingSmruti.value
        ? MyPhotoReviewStatus.pending
        : controller.overallReviewStatus;
    final title = switch (status) {
      MyPhotoReviewStatus.verified =>
        controller.hasMatchedSmruti
            ? 'Smruti found'
            : controller.smrutiLookupFinished
            ? 'Smruti not found'
            : 'Server fetching',
      MyPhotoReviewStatus.pending => 'Waiting for admin approval',
      MyPhotoReviewStatus.rejected => 'Upload needs changes',
      MyPhotoReviewStatus.draft => 'Ready to upload',
    };
    final message = switch (status) {
      MyPhotoReviewStatus.verified =>
        controller.hasMatchedSmruti
            ? 'Your matched Smruti photos are ready.'
            : controller.smrutiLookupFinished
            ? 'Your selfie was accepted, but no matching Smruti photos are available.'
            : 'Verified. We are fetching your matched smruti photos from the server.',
      MyPhotoReviewStatus.pending =>
        'Your selfie is waiting for admin review. Retake will be available if it is rejected.',
      MyPhotoReviewStatus.rejected =>
        'Rejected photos are visible above. Retake or remove them, then submit again.',
      MyPhotoReviewStatus.draft =>
        'Complete your front face live selfie, then submit for approval.',
    };
    final color = status.color;
    final pendingSelfie = status == MyPhotoReviewStatus.pending
        ? controller.photoForPose(MyPhotoPose.front)
        : null;
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
          if (pendingSelfie != null)
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: color.withAlpha(12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(75)),
              ),
              child: _MyPhotoImage(item: pendingSelfie),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(status.icon, color: color, size: 24),
            ),
          const SizedBox(width: 12),
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

class _SmrutiNotFoundPanel extends StatelessWidget {
  const _SmrutiNotFoundPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.photo_on_rectangle,
            color: primaryColor,
            size: 34,
          ),
          const SizedBox(height: 10),
          const Text(
            'Smruti not found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'No matching Smruti photos are available for your account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withAlpha(135),
              fontSize: 12,
              fontWeight: FontWeight.w700,
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
      child: NetworkImageWithLoader(
        imageUrl: photo.thumbnailUrl,
        title: '',
        fit: BoxFit.cover,
      ),
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
    // This capture UI is a fixed, non-scrolling layout tuned for portrait;
    // force portrait here regardless of device class so it can't overflow
    // in landscape now that tablets are allowed to rotate.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initCamera();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(defaultOrientationsForDevice());
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
