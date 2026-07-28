import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/api/repositories/gallery_repository.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  Uri? _lastHandledUri;
  final GalleryRepository _repository = const GalleryRepository();

  Future<void> start() async {
    if (_subscription != null) return;

    _subscription = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object error) {
        debugPrint('Deep link stream failed: $error');
      },
    );

    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) _handle(initialUri);
  }

  static Uri photoUri(GalleryPhoto photo) {
    if (photo.id <= 0) throw ArgumentError.value(photo.id, 'photo.id');
    final token = base64Url
        .encode(utf8.encode('${photo.id}'))
        .replaceAll('=', '');
    return Uri.https('hpsmruti.suhrad.digital', '/hps/$token');
  }

  void _handle(Uri uri) {
    if (uri == _lastHandledUri) return;
    final isHttpsLink =
        uri.scheme == 'https' &&
        uri.host == 'hpsmruti.suhrad.digital' &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'hps';
    if (!isHttpsLink) return;

    _lastHandledUri = uri;
    unawaited(_openSharedPhoto(uri.pathSegments.last));
  }

  Future<void> _openSharedPhoto(String token) async {
    try {
      final photo = await _repository.getSharedPhoto(token);
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (Get.currentRoute == '/splash' &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      if (Get.currentRoute == '/splash') {
        debugPrint('Shared photo navigation timed out while app was starting');
        return;
      }
      Get.to(
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
}
