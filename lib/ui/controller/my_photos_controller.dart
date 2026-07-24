import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/api_endpoints.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:harismruti/api/repositories/gallery_repository.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/controller/ProfileController.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:path_provider/path_provider.dart';

enum MyPhotoPose { front, left, right, other }

enum MyPhotoReviewStatus { draft, pending, verified, rejected }

class MyPhotoItem {
  const MyPhotoItem({
    required this.path,
    required this.pose,
    required this.reviewStatus,
    this.id,
    this.remoteUrl,
    this.note,
  });

  final int? id;
  final String path;
  final MyPhotoPose pose;
  final MyPhotoReviewStatus reviewStatus;
  final String? remoteUrl;
  final String? note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'remote_url': remoteUrl,
    'pose': pose.name,
    'review_status': reviewStatus.name,
    'note': note,
  };

  factory MyPhotoItem.fromJson(Map<String, dynamic> json) {
    return MyPhotoItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
      path: json['path']?.toString() ?? '',
      remoteUrl: _normalizeRemoteImageUrl(
        json['public_url']?.toString() ??
            json['remote_url']?.toString() ??
            json['url']?.toString() ??
            json['authenticated_url']?.toString(),
      ),
      pose: MyPhotoPose.values.firstWhere(
        (pose) => pose.name == json['pose'],
        orElse: () => MyPhotoPose.other,
      ),
      reviewStatus: MyPhotoReviewStatus.values.firstWhere(
        (status) => status.name == json['review_status'],
        orElse: () => MyPhotoReviewStatus.pending,
      ),
      note: json['note']?.toString(),
    );
  }

  factory MyPhotoItem.fromRemote(dynamic raw) {
    final json = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    return MyPhotoItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
      path: '',
      remoteUrl: _normalizeRemoteImageUrl(
        json['public_url']?.toString() ??
            json['url']?.toString() ??
            json['authenticated_url']?.toString() ??
            json['remote_url']?.toString() ??
            json['image_url']?.toString() ??
            json['thumbnail_url']?.toString(),
      ),
      pose: MyPhotoPose.values.firstWhere(
        (pose) => pose.name == json['pose'],
        orElse: () => MyPhotoPose.other,
      ),
      reviewStatus: MyPhotoReviewStatus.values.firstWhere(
        (status) =>
            status.name ==
            (json['review_status'] ?? json['status'] ?? json['approval_status'])
                ?.toString()
                .toLowerCase(),
        orElse: () => MyPhotoReviewStatus.pending,
      ),
      note:
          json['note']?.toString() ??
          json['rejection_reason']?.toString() ??
          json['reason']?.toString(),
    );
  }

  bool get hasLocalFile => path.isNotEmpty && File(path).existsSync();
  bool get hasRemoteImage => remoteUrl != null && remoteUrl!.isNotEmpty;
}

String? _normalizeRemoteImageUrl(String? rawUrl) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty || value == 'null') return null;

  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    return uri.toString();
  }

  final apiBase = Uri.parse(ApiEndpoints.mainDomain);
  if (value.startsWith('/')) {
    final relativeUri = Uri.parse(value);
    return apiBase
        .replace(
          path: relativeUri.path,
          query: relativeUri.query.isEmpty ? null : relativeUri.query,
        )
        .toString();
  }
  return '${ApiEndpoints.mainDomain.replaceFirst(RegExp(r'/+$'), '')}/'
      '${value.replaceFirst(RegExp(r'^/+'), '')}';
}

class MyPhotoValidationResult {
  const MyPhotoValidationResult._(this.isValid, this.message);

  final bool isValid;
  final String message;

  const MyPhotoValidationResult.valid(String message) : this._(true, message);
  const MyPhotoValidationResult.invalid(String message)
    : this._(false, message);
}

class MyPhotosController extends GetxController {
  MyPhotosController({GalleryRepository? repository})
    : _repository = repository ?? const GalleryRepository();

  final GalleryRepository _repository;

  static const int maxPhotos = 10;
  static const int _selfieTargetBytes = 500 * 1024;
  static const double _frontPoseLimit = 12;
  static const double _sidePoseLimit = 18;

  final RxList<MyPhotoItem> photos = <MyPhotoItem>[].obs;
  final RxList<GalleryPhoto> matchedPhotos = <GalleryPhoto>[].obs;
  final RxBool isUploading = false.obs;
  final RxBool isFetchingMatches = false.obs;
  final RxBool isCheckingMapping = false.obs;
  final RxBool hasPhoneMapping = false.obs;
  final RxnInt faceSearchRequestId = RxnInt();
  final RxString helperMessage = ''.obs;
  Timer? _statusTimer;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      minFaceSize: 0.08,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  final FaceDetector _lenientFaceDetector = FaceDetector(
    options: FaceDetectorOptions(
      minFaceSize: 0.03,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  List<MyPhotoPose> get requiredPoses => const [MyPhotoPose.front];

  int get remainingSlots => maxPhotos - photos.length;

  bool get canSubmitRequiredPhotos =>
      requiredPoses.every((pose) => photoForPose(pose) != null);

  bool get hasUnsavedChanges => photos.any(
    (photo) =>
        photo.reviewStatus == MyPhotoReviewStatus.draft ||
        photo.reviewStatus == MyPhotoReviewStatus.rejected,
  );

  bool get canSubmitTrainingSet =>
      canSubmitRequiredPhotos && !reviewLocked && hasUnsavedChanges;

  bool get hasRejectedPhotos =>
      photos.any((photo) => photo.reviewStatus == MyPhotoReviewStatus.rejected);

  bool get reviewLocked => isVerified;

  MyPhotoReviewStatus get overallReviewStatus {
    if (photos.isEmpty) return MyPhotoReviewStatus.draft;
    if (photos.any(
      (photo) => photo.reviewStatus == MyPhotoReviewStatus.rejected,
    )) {
      return MyPhotoReviewStatus.rejected;
    }
    if (photos.every(
      (photo) => photo.reviewStatus == MyPhotoReviewStatus.verified,
    )) {
      return MyPhotoReviewStatus.verified;
    }
    if (photos.any(
      (photo) => photo.reviewStatus == MyPhotoReviewStatus.pending,
    )) {
      return MyPhotoReviewStatus.pending;
    }
    return MyPhotoReviewStatus.draft;
  }

  bool get isVerified => overallReviewStatus == MyPhotoReviewStatus.verified;
  bool get canShowMatchedSmruti => hasPhoneMapping.value;
  bool get isRejected => overallReviewStatus == MyPhotoReviewStatus.rejected;
  bool get isPendingReview =>
      overallReviewStatus == MyPhotoReviewStatus.pending;

  bool get canEditUploads => !isVerified;

  @override
  void onInit() {
    super.onInit();
    _loadPhotos();
    refreshSmrutiFlow();
  }

  @override
  void onClose() {
    _statusTimer?.cancel();
    _faceDetector.close();
    _lenientFaceDetector.close();
    super.onClose();
  }

  MyPhotoItem? photoForPose(MyPhotoPose pose) {
    try {
      return photos.firstWhere((photo) => photo.pose == pose);
    } catch (_) {
      return null;
    }
  }

  Future<bool> addRequiredPhoto({
    required String path,
    required MyPhotoPose pose,
    bool allowFaceDetectionFallback = false,
  }) async {
    final existing = photoForPose(pose);
    if (existing != null && !canEditPhoto(existing)) {
      helperMessage.value = 'Verified photos cannot be changed.';
      return false;
    }
    final preparedPath = await _compressImageIfNeeded(path);
    final result = await validatePhoto(preparedPath, pose);
    helperMessage.value = result.message;
    if (!result.isValid &&
        !(allowFaceDetectionFallback &&
            _canUseCameraFallback(result.message))) {
      return false;
    }
    if (!result.isValid) {
      helperMessage.value =
          'Selfie captured. It will be verified after upload.';
    }

    photos.removeWhere((photo) => photo.pose == pose);
    photos.insert(
      0,
      MyPhotoItem(
        path: preparedPath,
        pose: pose,
        reviewStatus: MyPhotoReviewStatus.draft,
      ),
    );
    _sortPhotos();
    _savePhotos();
    return true;
  }

  bool _canUseCameraFallback(String message) {
    final lower = message.toLowerCase();
    return lower.contains('face not detected') ||
        lower.contains('could not read face angle') ||
        lower.contains('could not check face direction');
  }

  Future<void> removePhoto(MyPhotoItem item) async {
    if (!canEditPhoto(item)) {
      helperMessage.value = 'Verified photos cannot be removed.';
      return;
    }
    photos.remove(item);
    _savePhotos();
    if (item.id != null) {
      try {
        await _repository.deleteMyImage(item.id!);
      } catch (_) {}
    }
  }

  bool canEditPhoto(MyPhotoItem item) {
    return !isVerified && item.reviewStatus != MyPhotoReviewStatus.verified;
  }

  bool isPoseLocked(MyPhotoPose pose) {
    final item = photoForPose(pose);
    return item != null && !canEditPhoto(item);
  }

  Future<void> submitForReview() async {
    if (!canSubmitRequiredPhotos) {
      helperMessage.value = 'Front face selfie is compulsory.';
      return;
    }
    if (reviewLocked) {
      helperMessage.value = 'Verified photos cannot be changed.';
      return;
    }
    isUploading.value = true;
    try {
      // Recheck the phone mapping immediately before uploading. An admin may
      // have assigned this user while the screen was open.
      if (await _loadPhoneMapping()) return;
      final front = photoForPose(MyPhotoPose.front)!;
      final uploadPath = await _compressImageIfNeeded(front.path);
      final result = await _repository.submitMySmrutiSelfie(uploadPath);
      final requestId = int.tryParse('${result['request_id']}');
      faceSearchRequestId.value = requestId;
      if (requestId != null) {
        StorageHelper.setValue(
          key: StorageKeys.mySmrutiRequestId,
          value: requestId,
        );
      }
      final index = photos.indexOf(front);
      photos[index] = MyPhotoItem(
        path: front.path,
        pose: front.pose,
        reviewStatus: MyPhotoReviewStatus.pending,
      );
      _sortPhotos();
      if (Get.isRegistered<ProfileController>()) {
        final profileController = Get.find<ProfileController>();
        profileController.profileImage.value = File(front.path);
        profileController.loadUploadedProfileImageUrl();
      }
      helperMessage.value =
          result['message']?.toString() ??
          'Selfie submitted. Verification is pending admin approval.';
      _savePhotos();
      if (requestId != null) await _refreshRequestStatus(requestId);
    } catch (error) {
      helperMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> refreshSmrutiFlow() async {
    if (!StorageHelper.isLogin() || isCheckingMapping.value) return;
    if (kDebugMode) _debugProbeMyLibrary();
    isCheckingMapping.value = true;
    try {
      if (await _loadPhoneMapping()) return;
      final storedId = StorageHelper.getValue<int>(
        key: StorageKeys.mySmrutiRequestId,
      );
      if (storedId != null) {
        faceSearchRequestId.value = storedId;
        await _refreshRequestStatus(storedId);
      } else {
        await _loadRemotePhotos();
      }
    } catch (error) {
      helperMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isCheckingMapping.value = false;
    }
  }

  /// Debug-only: probes /me/library independently of which flow the account
  /// actually uses, purely to compare counts. Never touches matchedPhotos.
  Future<void> _debugProbeMyLibrary() async {
    try {
      final library = await _repository.getMyLibrary();
      final rawPhotos = library['photos'] is List
          ? (library['photos'] as List).length
          : 0;
      final mappedCount = library['photos'] is List
          ? (library['photos'] as List)
                .map(GalleryPhoto.fromJson)
                .where((photo) => photo.id > 0)
                .length
          : 0;
      debugPrint(
        'DEBUG_PROBE /me/library: raw_photos=$rawPhotos '
        'id_filtered=$mappedCount',
      );
    } catch (error) {
      debugPrint('DEBUG_PROBE /me/library failed: $error');
    }
  }

  // Safety cap on pages fetched, in case a backend that ignores the `page`
  // param keeps echoing the same data (would otherwise loop forever).
  static const int _maxMySmrutiPages = 50;

  Future<bool> _loadPhoneMapping() async {
    final firstPage = await _repository.getMySmruti();
    if (firstPage['found'] != true) {
      hasPhoneMapping.value = false;
      return false;
    }

    final seenIds = <int>{};
    final mapped = <GalleryPhoto>[];

    void addPage(Map<String, dynamic> result) {
      final pagePhotos =
          (result['photos'] is List ? result['photos'] as List : const [])
              .map(GalleryPhoto.fromJson)
              .where((photo) => photo.id > 0 && seenIds.add(photo.id))
              .toList();
      mapped.addAll(pagePhotos);
    }

    addPage(firstPage);
    var page = 1;
    while (page < _maxMySmrutiPages) {
      final beforeCount = mapped.length;
      page++;
      final nextPage = await _repository.getMySmruti(page: page);
      final nextPhotos = nextPage['photos'] is List
          ? nextPage['photos'] as List
          : const [];
      if (nextPhotos.isEmpty) break;
      addPage(nextPage);
      if (mapped.length == beforeCount) break; // no new photos, stop paging
    }

    matchedPhotos.assignAll(mapped);
    hasPhoneMapping.value = true;
    faceSearchRequestId.value = null;
    StorageHelper.removeValue(StorageKeys.mySmrutiRequestId);
    helperMessage.value = mapped.isEmpty
        ? 'Your phone number is assigned. Photos will appear when available.'
        : 'Your Smruti photos are ready.';
    return true;
  }

  Future<void> _refreshRequestStatus(int requestId) async {
    final result = await _repository.getMySmrutiRequestStatus(requestId);
    switch (result['status']?.toString()) {
      case 'accepted':
        _statusTimer?.cancel();
        helperMessage.value = 'Approved. Checking for your Smruti photos.';
        await _loadPhoneMapping();
        return;
      case 'rejected':
        _statusTimer?.cancel();
        StorageHelper.removeValue(StorageKeys.mySmrutiRequestId);
        faceSearchRequestId.value = null;
        final front = photoForPose(MyPhotoPose.front);
        if (front != null) {
          photos[photos.indexOf(front)] = MyPhotoItem(
            path: front.path,
            pose: front.pose,
            reviewStatus: MyPhotoReviewStatus.rejected,
            note: 'Rejected by admin. Please take a new front selfie.',
          );
          _savePhotos();
        }
        helperMessage.value =
            'Admin rejected the selfie. Please upload a new one.';
        return;
      default:
        helperMessage.value = 'Selfie submitted. Waiting for admin approval.';
        _startStatusPolling(requestId);
        return;
    }
  }

  void _startStatusPolling(int requestId) {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (isCheckingMapping.value) return;
      isCheckingMapping.value = true;
      try {
        if (!await _loadPhoneMapping()) {
          await _refreshRequestStatus(requestId);
        } else {
          _statusTimer?.cancel();
        }
      } catch (_) {
        // A temporary network error should not stop later status checks.
      } finally {
        isCheckingMapping.value = false;
      }
    });
  }

  Future<MyPhotoValidationResult> validatePhoto(
    String path,
    MyPhotoPose pose,
  ) async {
    final file = File(path);
    if (!file.existsSync()) {
      return const MyPhotoValidationResult.invalid('Image file was not found.');
    }

    final bytes = await file.readAsBytes();
    final image = await _decodeImage(bytes);
    final width = image.width;
    final height = image.height;
    final brightness = await _estimateBrightness(image);
    image.dispose();

    if (brightness != null && brightness < 34) {
      return const MyPhotoValidationResult.invalid(
        'Image is too dark. Please face the light and try again.',
      );
    }

    if (width < 480 || height < 480) {
      return const MyPhotoValidationResult.invalid(
        'Image is too small. Please upload a clear selfie.',
      );
    }

    final ratio = width / height;
    if (ratio < 0.45 || ratio > 2.2) {
      return const MyPhotoValidationResult.invalid(
        'Face image is not framed well. Please use a closer selfie.',
      );
    }

    final faceCheck = await _validateFacePose(
      path: path,
      pose: pose,
      imageWidth: width,
      imageHeight: height,
    );
    if (!faceCheck.isValid) return faceCheck;

    return MyPhotoValidationResult.valid(
      '${pose.label} selfie passed smart quality check.',
    );
  }

  Future<MyPhotoValidationResult> _validateFacePose({
    required String path,
    required MyPhotoPose pose,
    required int imageWidth,
    required int imageHeight,
  }) async {
    try {
      final inputImage = InputImage.fromFilePath(path);
      var faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        faces = await _lenientFaceDetector.processImage(inputImage);
      }

      if (faces.isEmpty) {
        return const MyPhotoValidationResult.invalid(
          'Face not detected yet. Move closer, keep your face centered, and hold still.',
        );
      }
      if (faces.length > 1) {
        return const MyPhotoValidationResult.invalid(
          'Multiple faces detected. Please upload only your selfie.',
        );
      }

      final face = faces.first;
      final faceArea = face.boundingBox.width * face.boundingBox.height;
      final imageArea = imageWidth * imageHeight;
      if (faceArea / imageArea < 0.07) {
        return const MyPhotoValidationResult.invalid(
          'Face is too far from camera. Please upload a closer selfie.',
        );
      }

      final centerX = face.boundingBox.center.dx / imageWidth;
      final centerY = face.boundingBox.center.dy / imageHeight;
      if (centerX < 0.22 ||
          centerX > 0.78 ||
          centerY < 0.18 ||
          centerY > 0.82) {
        return const MyPhotoValidationResult.invalid(
          'Face should be centered in the selfie.',
        );
      }

      final yAngle = face.headEulerAngleY;
      if (yAngle == null) {
        if (pose == MyPhotoPose.front || pose == MyPhotoPose.other) {
          return const MyPhotoValidationResult.valid('Face detected.');
        }
        return const MyPhotoValidationResult.invalid(
          'Could not read face angle. Please try another clear selfie.',
        );
      }

      return _validatePoseAngle(pose, yAngle);
    } catch (_) {
      return const MyPhotoValidationResult.invalid(
        'Could not check face direction. Please try another selfie.',
      );
    }
  }

  MyPhotoValidationResult _validatePoseAngle(MyPhotoPose pose, double yAngle) {
    switch (pose) {
      case MyPhotoPose.front:
        if (yAngle.abs() <= _frontPoseLimit) {
          return const MyPhotoValidationResult.valid('Front face detected.');
        }
        return const MyPhotoValidationResult.invalid(
          'This is not a front face selfie. Please look straight.',
        );
      case MyPhotoPose.left:
        if (yAngle <= -_sidePoseLimit) {
          return const MyPhotoValidationResult.valid(
            'Left side face detected.',
          );
        }
        return const MyPhotoValidationResult.invalid(
          'This is not a left side face selfie. Please turn face to left side.',
        );
      case MyPhotoPose.right:
        if (yAngle >= _sidePoseLimit) {
          return const MyPhotoValidationResult.valid(
            'Right side face detected.',
          );
        }
        return const MyPhotoValidationResult.invalid(
          'This is not a right side face selfie. Please turn face to right side.',
        );
      case MyPhotoPose.other:
        return const MyPhotoValidationResult.valid('Face detected.');
    }
  }

  Future<ui.Image> _decodeImage(List<int> bytes) async {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Compresses a My Smruti selfie capture toward ~300-500KB at up to 1080p,
  /// small enough for fast upload while keeping enough detail for face
  /// detection/matching. Scoped to this controller only — other gallery and
  /// camera flows in the app are untouched.
  Future<String> _compressImageIfNeeded(String path) async {
    final source = File(path);
    if (!source.existsSync()) return path;
    if (source.lengthSync() <= _selfieTargetBytes) return path;

    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    String? bestPath;

    const ladder = [
      (quality: 82, dimension: 1080),
      (quality: 72, dimension: 1080),
      (quality: 62, dimension: 960),
      (quality: 52, dimension: 800),
      (quality: 42, dimension: 720),
    ];

    for (final step in ladder) {
      final targetPath =
          '${tempDir.path}${Platform.pathSeparator}'
          'harismruti-selfie-$stamp-${step.quality}.jpg';
      final compressed = await FlutterImageCompress.compressAndGetFile(
        path,
        targetPath,
        quality: step.quality,
        minWidth: step.dimension,
        minHeight: step.dimension,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) continue;

      final compressedFile = File(compressed.path);
      if (!compressedFile.existsSync()) continue;
      bestPath = compressedFile.path;
      if (compressedFile.lengthSync() <= _selfieTargetBytes) {
        return compressedFile.path;
      }
    }

    final fallbackPath =
        '${tempDir.path}${Platform.pathSeparator}harismruti-selfie-$stamp-small.jpg';
    final fallback = await FlutterImageCompress.compressAndGetFile(
      path,
      fallbackPath,
      quality: 35,
      minWidth: 640,
      minHeight: 640,
      format: CompressFormat.jpeg,
    );
    if (fallback != null && File(fallback.path).existsSync()) {
      return fallback.path;
    }
    return bestPath ?? path;
  }

  Future<void> _deleteStaleTempFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      final tempDir = await getTemporaryDirectory();
      for (final path in paths) {
        if (!path.startsWith(tempDir.path)) continue;
        final file = File(path);
        if (file.existsSync()) {
          await file.delete().catchError((_) => file);
        }
      }
    } catch (_) {}
  }

  Future<double?> _estimateBrightness(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;

    final bytes = byteData.buffer.asUint8List();
    const targetSamples = 1600;
    final pixelCount = image.width * image.height;
    final step = (pixelCount / targetSamples).ceil().clamp(1, pixelCount);
    var total = 0.0;
    var samples = 0;

    for (var pixel = 0; pixel < pixelCount; pixel += step) {
      final offset = pixel * 4;
      final red = bytes[offset];
      final green = bytes[offset + 1];
      final blue = bytes[offset + 2];
      total += (0.2126 * red) + (0.7152 * green) + (0.0722 * blue);
      samples++;
    }

    return samples == 0 ? null : total / samples;
  }

  void _loadPhotos() {
    final stored = StorageHelper.getValue<List>(
      key: StorageKeys.myPhotos,
      defaultValue: const [],
    );
    if (stored == null) return;

    final loaded = stored
        .whereType<Map>()
        .map((json) => MyPhotoItem.fromJson(Map<String, dynamic>.from(json)))
        .where((photo) => photo.hasLocalFile || photo.hasRemoteImage)
        .toList();

    photos.assignAll(loaded);
    _sortPhotos();
  }

  Future<void> _loadRemotePhotos() async {
    if (!StorageHelper.isLogin()) return;
    try {
      final library = await _repository.getMyLibrary();
      final remote = library['user_images'] is List
          ? (library['user_images'] as List)
                .map(MyPhotoItem.fromRemote)
                .where((photo) => photo.hasRemoteImage)
                .toList()
          : <MyPhotoItem>[];
      final matched =
          (library['photos'] is List ? library['photos'] as List : const [])
              .map(GalleryPhoto.fromJson)
              .where((photo) => photo.id > 0)
              .toList();
      debugPrint(
        'MyPhotosController._loadRemotePhotos: '
        'raw_photos=${library['photos'] is List ? (library['photos'] as List).length : 0} '
        'matched=${matched.length}',
      );
      matchedPhotos.assignAll(matched);
      if (remote.isNotEmpty) {
        final stalePaths = photos
            .where((photo) => photo.hasLocalFile)
            .map((photo) => photo.path)
            .toList();
        photos
          ..clear()
          ..addAll(remote);
        _sortPhotos();
        _savePhotos();
        await _deleteStaleTempFiles(stalePaths);
      }
      if (remote.any(
        (photo) => photo.reviewStatus == MyPhotoReviewStatus.verified,
      )) {
        await fetchServerMatches();
      }
    } catch (_) {}
  }

  Future<void> fetchServerMatches() async {
    if (!StorageHelper.isLogin() || !isVerified || isFetchingMatches.value) {
      return;
    }
    isFetchingMatches.value = true;
    try {
      if (Get.isRegistered<GalleryController>()) {
        final galleryController = Get.find<GalleryController>();
        await galleryController.loadMyLibrary();
        await galleryController.loadHome(force: true);
      }
      final library = await _repository.getMyLibrary();
      final matched =
          (library['photos'] is List ? library['photos'] as List : const [])
              .map(GalleryPhoto.fromJson)
              .where((photo) => photo.id > 0)
              .toList();
      debugPrint(
        'MyPhotosController.fetchServerMatches: '
        'raw_photos=${library['photos'] is List ? (library['photos'] as List).length : 0} '
        'matched=${matched.length}',
      );
      matchedPhotos.assignAll(matched);
      helperMessage.value = matched.isEmpty
          ? 'Verified. We are fetching your smruti from the server.'
          : 'Verified. Your smruti photos are ready.';
    } catch (error) {
      helperMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isFetchingMatches.value = false;
    }
  }

  void _savePhotos() {
    StorageHelper.setValue(
      key: StorageKeys.myPhotos,
      value: photos.map((photo) => photo.toJson()).toList(),
    );
  }

  void _sortPhotos() {
    photos.sort((a, b) => a.pose.sortOrder.compareTo(b.pose.sortOrder));
    photos.refresh();
  }
}

extension MyPhotoPoseLabel on MyPhotoPose {
  String get label {
    switch (this) {
      case MyPhotoPose.front:
        return 'Front';
      case MyPhotoPose.left:
        return 'Left';
      case MyPhotoPose.right:
        return 'Right';
      case MyPhotoPose.other:
        return 'Other Pose';
    }
  }

  String get instruction {
    switch (this) {
      case MyPhotoPose.front:
        return 'Look straight at the camera';
      case MyPhotoPose.left:
        return 'Turn face to left side';
      case MyPhotoPose.right:
        return 'Turn face to right side';
      case MyPhotoPose.other:
        return 'Old or different pose selfie';
    }
  }

  int get sortOrder {
    switch (this) {
      case MyPhotoPose.front:
        return 0;
      case MyPhotoPose.left:
        return 1;
      case MyPhotoPose.right:
        return 2;
      case MyPhotoPose.other:
        return 3;
    }
  }
}

extension MyPhotoReviewStatusLabel on MyPhotoReviewStatus {
  String get label {
    switch (this) {
      case MyPhotoReviewStatus.pending:
        return 'Pending';
      case MyPhotoReviewStatus.draft:
        return 'Ready';
      case MyPhotoReviewStatus.verified:
        return 'Verified';
      case MyPhotoReviewStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case MyPhotoReviewStatus.pending:
        return const Color(0xFF8A6A00);
      case MyPhotoReviewStatus.draft:
        return const Color(0xFF246B8F);
      case MyPhotoReviewStatus.verified:
        return const Color(0xFF167A3C);
      case MyPhotoReviewStatus.rejected:
        return const Color(0xFFC62828);
    }
  }

  Color get backgroundColor => color.withValues(alpha: 0.12);

  IconData get icon {
    switch (this) {
      case MyPhotoReviewStatus.pending:
        return Icons.hourglass_top_rounded;
      case MyPhotoReviewStatus.draft:
        return Icons.cloud_upload_rounded;
      case MyPhotoReviewStatus.verified:
        return Icons.verified_rounded;
      case MyPhotoReviewStatus.rejected:
        return Icons.error_rounded;
    }
  }
}
