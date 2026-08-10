import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _restartSheetVisible = false;

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
          _showRestartSheet(messengerKey);
        case UpdateStatus.restartRequired:
          _showRestartSheet(messengerKey);
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

  void _showRestartSheet(GlobalKey<ScaffoldMessengerState> messengerKey) {
    if (_restartSheetVisible) return;
    final context = messengerKey.currentContext;
    if (context == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showRestartSheet(messengerKey),
      );
      return;
    }

    _restartSheetVisible = true;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (sheetContext) => const _RequiredUpdateSheet(),
    ).whenComplete(() => _restartSheetVisible = false);
  }
}

class _RequiredUpdateSheet extends StatelessWidget {
  const _RequiredUpdateSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAndroid = Platform.isAndroid;
    return PopScope(
      canPop: false,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_alt_rounded,
                  color: scheme.onPrimaryContainer,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Update ready',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                isAndroid
                    ? 'The latest improvements have been downloaded. Reopen the app now to apply the update.'
                    : 'The latest improvements have been downloaded. Close the app from the App Switcher, then reopen it to continue.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              if (isAndroid)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: SystemNavigator.pop,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('REOPEN NOW'),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Swipe up to open the App Switcher, close HariSmruti, and open it again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
