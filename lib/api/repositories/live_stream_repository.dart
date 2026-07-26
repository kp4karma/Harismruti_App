import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/api/api_endpoints.dart';

class LiveStreamRepository {
  const LiveStreamRepository();

  Future<String?> fetchLiveStreamUrl({bool forceRefresh = false}) async {
    final response = await ApiClient.get(
      ApiEndpoints.liveStream,
      forceRefresh: forceRefresh,
      cacheDuration: const Duration(minutes: 2),
    );
    return _findUrl(response.data);
  }

  String? _findUrl(dynamic value) {
    if (value is String) return _streamUrl(value);
    if (value is List) {
      for (final item in value) {
        final url = _findUrl(item);
        if (url != null) return url;
      }
      return null;
    }
    if (value is Map) {
      final data = value['data'];
      if (data is Map && data.containsKey('live_stream')) {
        return _findUrl(data['live_stream']);
      }
      if (value.containsKey('live_stream')) {
        return _findUrl(value['live_stream']);
      }

      const preferredKeys = [
        'video_url',
        'live_stream_url',
        'livestream_url',
        'stream_url',
        'live_url',
        'url',
        'link',
      ];
      for (final key in preferredKeys) {
        final url = _findUrl(value[key]);
        if (url != null) return url;
      }
      for (final key in ['data', 'livestream', 'live_stream', 'stream']) {
        final url = _findUrl(value[key]);
        if (url != null) return url;
      }
    }
    return null;
  }

  String? _streamUrl(String value) {
    final candidate = value.trim();
    if (candidate.isEmpty ||
        candidate.toLowerCase() == 'null' ||
        candidate.toLowerCase() == 'false') {
      return null;
    }

    final iframeSource = RegExp(
      '''src\\s*=\\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(candidate)?.group(1);
    final urlValue = iframeSource ?? candidate;
    final uri = Uri.tryParse(urlValue);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return urlValue;
  }
}
