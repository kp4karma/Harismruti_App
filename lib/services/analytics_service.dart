import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:harismruti/utils/storage_helper.dart';

/// Central analytics boundary for the app.
///
/// Supply the Mixpanel project token at build time:
/// `--dart-define=MIXPANEL_TOKEN=<project-token>`.
/// Analytics intentionally becomes a no-op when no token is supplied, keeping
/// local development and tests free from accidental production events.
class AnalyticsService {
  AnalyticsService._();

  static const _token = String.fromEnvironment(
    'MIXPANEL_TOKEN',
    defaultValue: '2cef9a69bb22e3a50da621929234885e',
  );
  static final AnalyticsService instance = AnalyticsService._();

  Mixpanel? _client;
  bool get isEnabled => _client != null;

  Future<void> initialize() async {
    if (_token.isEmpty || _client != null) {
      if (_token.isEmpty && kDebugMode) {
        debugPrint(
          'Mixpanel is disabled. Add --dart-define=MIXPANEL_TOKEN=<token>.',
        );
      }
      return;
    }

    try {
      _client = await Mixpanel.init(_token, trackAutomaticEvents: true);
      final package = await PackageInfo.fromPlatform();
      await _client!.registerSuperProperties({
        'app_name': package.appName,
        'app_version': package.version,
        'build_number': package.buildNumber,
        'environment': kReleaseMode ? 'production' : 'development',
      });
      await identifyStoredUser();
      track('App Opened', properties: {'logged_in': StorageHelper.isLogin()});
    } catch (error) {
      _client = null;
      if (kDebugMode) debugPrint('Mixpanel initialization failed: $error');
    }
  }

  Future<void> identifyStoredUser() async {
    final client = _client;
    if (client == null) return;

    final rawProfile = StorageHelper.getValue<String>(
      key: StorageKeys.userProfile,
    );
    Map<String, dynamic> profile = const {};
    if (rawProfile != null && rawProfile.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawProfile);
        if (decoded is Map) profile = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    final profileId = _firstNonEmpty([
      profile['id'],
      profile['user_id'],
      profile['uuid'],
    ]);
    final anonymousDeviceId = StorageHelper.getValue<String>(
      key: StorageKeys.deviceId,
    );
    final distinctId = profileId.isNotEmpty ? profileId : anonymousDeviceId;
    if (distinctId == null || distinctId.isEmpty) return;

    client.identify(distinctId);
    final peopleProperties = <String, dynamic>{
      if (_firstNonEmpty([profile['city']]).isNotEmpty)
        'city': _firstNonEmpty([profile['city']]),
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    };
    final people = client.getPeople();
    for (final entry in peopleProperties.entries) {
      people.set(entry.key, entry.value);
    }
  }

  void track(String event, {Map<String, dynamic>? properties}) {
    final safeProperties = properties == null
        ? null
        : Map<String, dynamic>.fromEntries(
            properties.entries.where((entry) => entry.value != null),
          );
    _client?.track(event, properties: safeProperties);
  }

  void screen(String routeName) {
    final normalized = _friendlyScreenName(routeName);
    track('$normalized Screen Viewed', properties: {'screen_name': normalized});
  }

  void timeEvent(String event) => _client?.timeEvent(event);

  Future<void> flush() async => _client?.flush();

  Future<void> reset() async {
    _client?.reset();
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  String _friendlyScreenName(String routeName) {
    const namedRoutes = {
      '/splash': 'Splash',
      '/login': 'Login Home',
      '/login/mobile': 'Login',
      '/register': 'Register',
      '/home': 'Home',
    };
    final trimmed = routeName.trim();
    if (namedRoutes.containsKey(trimmed)) return namedRoutes[trimmed]!;
    if (trimmed.isEmpty || trimmed == 'unknown') return 'Unknown';
    return trimmed
        .replaceAll(RegExp(r'(PageRoute|Route)$'), '')
        .replaceAll(RegExp(r'[_/-]+'), ' ')
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .trim()
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

class AnalyticsRouteObserver extends NavigatorObserver {
  void _track(Route<dynamic>? route) {
    if (route == null || route is! PageRoute) return;
    AnalyticsService.instance.screen(
      route.settings.name ?? route.runtimeType.toString(),
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _track(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _track(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _track(previousRoute);
  }
}
