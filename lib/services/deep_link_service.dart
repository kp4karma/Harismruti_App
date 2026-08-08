import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/api/repositories/gallery_repository.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_routes.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  Uri? _pendingUri;
  Uri? _activeUri;
  Uri? _lastReceivedUri;
  DateTime? _lastReceivedAt;
  bool _isProcessing = false;
  final GalleryRepository _repository = const GalleryRepository();

  Future<void> start() async {
    if (_subscription != null) return;

    _subscription = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object error) {
        debugPrint('Deep link stream failed: $error');
      },
    );

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handle(initialUri);
    } catch (error) {
      debugPrint('Unable to read the initial deep link: $error');
    }
  }

  static Uri photoUri(GalleryPhoto photo) {
    if (photo.id <= 0) throw ArgumentError.value(photo.id, 'photo.id');
    final token = base64Url
        .encode(utf8.encode('${photo.id}'))
        .replaceAll('=', '');
    return Uri.https('hariprabodham.app', '/hps/$token');
  }

  void _handle(Uri uri) {
    final isHttpsLink =
        uri.scheme == 'https' &&
        uri.host == 'hariprabodham.app' &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'hps';
    if (!isHttpsLink) return;

    final now = DateTime.now();
    final isImmediateDuplicate =
        uri == _lastReceivedUri &&
        _lastReceivedAt != null &&
        now.difference(_lastReceivedAt!) < const Duration(seconds: 2);
    if (isImmediateDuplicate || uri == _activeUri) return;

    _lastReceivedUri = uri;
    _lastReceivedAt = now;
    _pendingUri = uri;
    unawaited(_processPendingLink());
  }

  Future<void> _processPendingLink() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      while (_pendingUri != null) {
        final uri = _pendingUri!;
        _pendingUri = null;
        _activeUri = uri;
        await _openSharedPhoto(uri.pathSegments.last);
        _activeUri = null;
      }
    } finally {
      _activeUri = null;
      _isProcessing = false;
      // A link can arrive between the loop's final null check and this
      // cleanup. Start another pass so that event is never lost.
      if (_pendingUri != null) unawaited(_processPendingLink());
    }
  }

  Future<void> _openSharedPhoto(String token) async {
    try {
      final photo = await _loadSharedPhoto(token);
      if (!await _waitForNavigator()) {
        // The URL is only deduplicated briefly, so tapping it again can retry
        // after an abnormally slow or interrupted startup.
        debugPrint('Shared photo navigation timed out during app startup');
        return;
      }

      await WidgetsBinding.instance.endOfFrame;
      Get.to<void>(
        () => GalleryFullscreenViewer(
          photos: [photo],
          initialIndex: 0,
          title: photo.title?.trim().isNotEmpty == true
              ? photo.title!
              : 'HariPrabodham Smruti',
        ),
      );
    } catch (error) {
      debugPrint('Unable to open shared photo: $error');
    }
  }

  Future<GalleryPhoto> _loadSharedPhoto(String token) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await _repository.getSharedPhoto(token);
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 350 * (attempt + 1)),
          );
        }
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  Future<bool> _waitForNavigator() async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      final navigator = Get.key.currentState;
      if (navigator != null &&
          navigator.mounted &&
          Get.currentRoute.isNotEmpty &&
          Get.currentRoute != AppRoutes.splash) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }
}
