import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Checks for Shorebird patches without delaying app startup.
///
/// A downloaded patch becomes active after the app is fully closed and opened
/// again. Shorebird does not safely hot-restart a running Flutter application.
class ShorebirdUpdateService {
  ShorebirdUpdateService({
    ShorebirdUpdater? updater,
    this.minimumCheckInterval = const Duration(minutes: 15),
  }) : _updater = updater ?? ShorebirdUpdater();

  final ShorebirdUpdater _updater;
  final Duration minimumCheckInterval;

  DateTime? _lastCheckAt;
  bool _isChecking = false;

  Future<void> checkForUpdate(
    GlobalKey<ScaffoldMessengerState> messengerKey, {
    bool force = false,
  }) async {
    if (!_updater.isAvailable || _isChecking) {
      return;
    }

    final now = DateTime.now();
    final lastCheckAt = _lastCheckAt;
    if (!force &&
        lastCheckAt != null &&
        now.difference(lastCheckAt) < minimumCheckInterval) {
      return;
    }

    _isChecking = true;
    _lastCheckAt = now;

    try {
      final status = await _updater.checkForUpdate();
      switch (status) {
        case UpdateStatus.outdated:
          await _updater.update();
          _showRestartBanner(messengerKey);
        case UpdateStatus.restartRequired:
          _showRestartBanner(messengerKey);
        case UpdateStatus.upToDate:
        case UpdateStatus.unavailable:
          return;
      }
    } on UpdateException catch (error) {
      if (kDebugMode) {
        debugPrint('Shorebird update failed: ${error.message}');
      }
    } on Exception catch (error) {
      if (kDebugMode) {
        debugPrint('Shorebird update check failed: $error');
      }
    } finally {
      _isChecking = false;
    }
  }

  void _showRestartBanner(GlobalKey<ScaffoldMessengerState> messengerKey) {
    final messenger = messengerKey.currentState;
    if (messenger == null) {
      return;
    }

    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          content: const Text(
            'A new app update is ready. Close and reopen the app to apply it.',
          ),
          leading: const Icon(Icons.system_update_alt_rounded),
          actions: [
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: const Text('LATER'),
            ),
          ],
        ),
      );
  }
}
