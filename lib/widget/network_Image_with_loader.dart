import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';

/// The app-wide network image widget.
///
/// Transient image/CDN failures are retried without exposing Flutter's broken
/// image indicator. The requested decode size follows the physical display
/// size so images remain sharp on high-density phones and tablets.
class NetworkImageWithLoader extends StatefulWidget {
  final String imageUrl;
  final String title;
  final Map<String, String>? headers;
  final BoxFit fit;

  const NetworkImageWithLoader({
    super.key,
    required this.imageUrl,
    required this.title,
    this.headers,
    this.fit = BoxFit.cover,
  });

  @override
  State<NetworkImageWithLoader> createState() => _NetworkImageWithLoaderState();
}

class _NetworkImageWithLoaderState extends State<NetworkImageWithLoader> {
  static const _maxAutomaticRetries = 3;

  Timer? _retryTimer;
  int _attempt = 0;
  bool _failedPermanently = false;
  bool _refreshingAuthentication = false;
  bool _authenticationRefreshAttempted = false;

  @override
  void didUpdateWidget(covariant NetworkImageWithLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.headers != widget.headers) {
      _reset();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _reset() {
    _retryTimer?.cancel();
    _attempt = 0;
    _failedPermanently = false;
    _authenticationRefreshAttempted = false;
  }

  Map<String, String>? get _currentHeaders {
    final result = <String, String>{...?widget.headers};
    final accessToken = StorageHelper.getValue<String>(
      key: StorageKeys.accessToken,
    );
    if (accessToken != null && accessToken.isNotEmpty) {
      result['Authorization'] = 'Bearer $accessToken';
    }
    return result.isEmpty ? null : result;
  }

  String get _displayImageUrl {
    final uri = Uri.tryParse(widget.imageUrl.trim());
    if (uri == null || uri.pathSegments.length < 3) return widget.imageUrl;

    final segments = uri.pathSegments.toList();
    final isPhotoThumbnail =
        segments.last == 'thumbnail' &&
        segments.length >= 3 &&
        segments[segments.length - 3] == 'photos';
    if (!isPhotoThumbnail) return widget.imageUrl;

    // Stored thumbnails are only 300x300. Portrait thumbnails can therefore
    // be narrower than a grid cell's physical pixel width and look blurred on
    // modern phones. Fetch the clear asset, then decode it at the exact display
    // width below so Flutter does not retain an oversized texture in memory.
    segments[segments.length - 1] = 'full';
    return uri.replace(pathSegments: segments).toString();
  }

  void _handleError(Object error) {
    if (_retryTimer != null || _failedPermanently) return;

    final errorText = error.toString().toLowerCase();
    final isAuthenticationError =
        errorText.contains('statuscode: 401') ||
        errorText.contains('statuscode: 403') ||
        errorText.contains('status code: 401') ||
        errorText.contains('status code: 403');
    if (isAuthenticationError &&
        !_refreshingAuthentication &&
        !_authenticationRefreshAttempted) {
      _refreshAuthenticationAndRetry();
      return;
    }

    if (_attempt >= _maxAutomaticRetries) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _failedPermanently = true);
      });
      return;
    }

    final delay = Duration(milliseconds: 500 * (1 << _attempt));
    _retryTimer = Timer(delay, () async {
      _retryTimer = null;
      if (!mounted) return;
      setState(() => _attempt++);
    });
  }

  Future<void> _refreshAuthenticationAndRetry() async {
    _refreshingAuthentication = true;
    _authenticationRefreshAttempted = true;
    try {
      await ApiClient.refreshAccessToken();
      if (mounted) setState(() => _attempt++);
    } finally {
      _refreshingAuthentication = false;
    }
  }

  void _retryNow() {
    setState(() {
      _attempt++;
      _failedPermanently = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.trim().isEmpty) return _errorPlaceholder();

    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final decodeWidth = (logicalWidth * devicePixelRatio).ceil().clamp(
          1,
          1600,
        );
        final displayImageUrl = _displayImageUrl;

        return CachedNetworkImage(
          key: ValueKey('$displayImageUrl#$_attempt'),
          imageUrl: displayImageUrl,
          httpHeaders: _currentHeaders,
          useOldImageOnUrlChange: true,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          memCacheWidth: decodeWidth,
          // Retaining 3000px copies of every viewed image could grow Android
          // app storage by hundreds of megabytes. 1200px remains sharp on a
          // phone while keeping the persistent cache compact.
          maxWidthDiskCache: 1200,
          placeholder: (_, _) => _progressivePlaceholder(decodeWidth),
          errorWidget: (_, _, error) {
            _handleError(error);
            return _failedPermanently
                ? _errorPlaceholder()
                : _progressivePlaceholder(decodeWidth);
          },
          fit: widget.fit,
        );
      },
    );
  }

  Widget _loadingPlaceholder() => const GalleryShimmerBox(
    width: double.infinity,
    height: double.infinity,
    borderRadius: 0,
  );

  Widget _progressivePlaceholder(int decodeWidth) {
    if (_displayImageUrl == widget.imageUrl) return _loadingPlaceholder();
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      httpHeaders: _currentHeaders,
      fit: widget.fit,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: decodeWidth,
      maxWidthDiskCache: 600,
      placeholder: (_, _) => _loadingPlaceholder(),
      errorWidget: (_, _, _) => _loadingPlaceholder(),
    );
  }

  Widget _errorPlaceholder() => ColoredBox(
    color: primaryColor.withAlpha(12),
    child: Center(
      child: IconButton(
        tooltip: 'Retry image',
        onPressed: widget.imageUrl.trim().isEmpty ? null : _retryNow,
        icon: Icon(CupertinoIcons.arrow_clockwise, color: primaryColor),
      ),
    ),
  );
}
