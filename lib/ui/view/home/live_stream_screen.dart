import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:harismruti/bootstrap.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LiveStreamScreen extends StatefulWidget {
  const LiveStreamScreen({super.key, required this.url});

  final String url;

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  Timer? _recordingCheckTimer;
  int _progress = 0;
  String? _error;
  bool _protectionReady = false;
  bool _isRecording = false;
  bool _isAppVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enterLandscapeMode());
    unawaited(_enableProtectionAndLoad());
  }

  Future<void> _enterLandscapeMode() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _enableProtectionAndLoad() async {
    // Keep the stream unloaded until the OS-level secure surface is active.
    await ScreenProtector.protectDataLeakageOn();
    await ScreenProtector.preventScreenshotOn();
    await ScreenProtector.protectDataLeakageWithColor(Colors.black);

    if (!mounted) return;
    final accessToken = StorageHelper.getValue<String>(
      key: StorageKeys.accessToken,
    );
    final requestHeaders = <String, String>{};
    if (accessToken != null && accessToken.isNotEmpty) {
      requestHeaders['Authorization'] = 'Bearer $accessToken';
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _error = null);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _error = error.description);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url), headers: requestHeaders);
    _controller = controller;
    setState(() => _protectionReady = true);

    await _checkForRecording();
    _recordingCheckTimer = Timer.periodic(
      const Duration(milliseconds: 750),
      (_) => unawaited(_checkForRecording()),
    );
  }

  Future<void> _checkForRecording() async {
    final recording = await ScreenProtector.isRecording();
    if (mounted && recording != _isRecording) {
      setState(() => _isRecording = recording);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    if (mounted && visible != _isAppVisible) {
      setState(() => _isAppVisible = visible);
    }
    if (visible) {
      unawaited(ScreenProtector.protectDataLeakageOn());
      unawaited(ScreenProtector.preventScreenshotOn());
      unawaited(_checkForRecording());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingCheckTimer?.cancel();
    unawaited(ScreenProtector.protectDataLeakageOff());
    unawaited(ScreenProtector.preventScreenshotOff());
    unawaited(ScreenProtector.protectDataLeakageWithColorOff());
    unawaited(
      SystemChrome.setPreferredOrientations(defaultOrientationsForDevice()),
    );
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final concealStream =
        !_protectionReady ||
        !_isAppVisible ||
        _isRecording ||
        controller == null;

    final player = concealStream
        ? _ProtectedStreamPlaceholder(isRecording: _isRecording)
        : _error == null
        ? WebViewWidget(controller: controller)
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white70,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Unable to load the live stream',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                    ),
                    onPressed: controller.reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          player,
          if (_progress < 100)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress / 100,
                minHeight: 2,
                color: primaryColor,
                backgroundColor: Colors.transparent,
              ),
            ),
          Positioned.fill(
            child: SafeArea(
              minimum: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: _GlassBackButton(
                  onTap: () => Navigator.maybePop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.black.withAlpha(85),
          child: InkWell(
            onTap: onTap,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProtectedStreamPlaceholder extends StatelessWidget {
  const _ProtectedStreamPlaceholder({required this.isRecording});

  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRecording
                    ? Icons.screen_lock_portrait_rounded
                    : Icons.security_rounded,
                color: Colors.white70,
                size: 52,
              ),
              const SizedBox(height: 14),
              Text(
                isRecording
                    ? 'Screen recording detected'
                    : 'Securing live stream…',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isRecording) ...[
                const SizedBox(height: 8),
                const Text(
                  'Stop screen recording to continue watching.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
