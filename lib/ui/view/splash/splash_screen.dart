import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/app_version_info.dart';
import 'package:harismruti/api/repositories/app_version_repository.dart';
import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/api/api_endpoints.dart';
import 'package:harismruti/helper/navigation_helper.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_images.dart';
import 'package:harismruti/utils/app_routes.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/background/animated_words_background.dart';
import 'package:harismruti/widget/internet_status_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introController;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _checkInternetAndNavigate();
  }

  Future<void> _checkInternetAndNavigate() async {
    final connectivity = await Connectivity().checkConnectivity();
    final hasInternet =
        connectivity.contains(ConnectivityResult.wifi) ||
        connectivity.contains(ConnectivityResult.mobile) ||
        connectivity.contains(ConnectivityResult.ethernet);

    if (!hasInternet) {
      Future.delayed(const Duration(milliseconds: 500), () {
        InternetStatusWidget.showNoInternetDialog();
      });
    }

    if (hasInternet && StorageHelper.isLogin()) {
      try {
        await ApiClient.get(
          ApiEndpoints.verifyToken,
          forceRefresh: true,
          cacheDuration: Duration.zero,
        ).timeout(const Duration(seconds: 2));
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Stored login verification failed: $error');
        }
      }
      if (!StorageHelper.isLogin()) {
        // ApiClient already chose the correct destination: public Home for a
        // device change, or the auth flow for other session failures.
        return;
      }
    }

    if (!mounted) return;

    NavigationHelper.navigateAndRemoveAll(AppRoutes.home);
    if (hasInternet) {
      unawaited(_checkVersionAfterAppOpen());
    }
  }

  Future<void> _checkVersionAfterAppOpen() async {
    // Let Home paint before starting this noncritical network request.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      final versionInfo = await const AppVersionRepository()
          .checkCurrentVersion()
          .timeout(const Duration(seconds: 5));
      if (versionInfo?.updateRequired == true) {
        await _showRequiredUpdateSheet(versionInfo!);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('App version check failed: $error');
      }
    }
  }

  Future<void> _showRequiredUpdateSheet(AppVersionInfo versionInfo) {
    final overlayContext = Get.overlayContext ?? Get.context;
    if (overlayContext == null) return Future<void>.value();
    return showModalBottomSheet<void>(
      context: overlayContext,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: ResponsiveBottomCenter(
            maxWidth: kSheetMaxWidth,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.system_update_alt_rounded,
                      color: primaryColor,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'New Version Available',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    versionInfo.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Installed ${ApiClient.currentAppVersion}  •  '
                    'Latest ${versionInfo.maxVersion}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => _openStore(versionInfo.storeUrl),
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Upgrade Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openStore(String storeUrl) async {
    final uri = Uri.tryParse(storeUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar(
        'Update unavailable',
        'Could not open the app store.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: AnimatedWordsBackground(
        topToBottom: true,
        opacity: 0.68,
        veilAlpha: 72,
        chipBackground: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.86,
                  colors: isDark
                      ? [
                          Colors.transparent,
                          const Color(0xFF241A18).withAlpha(54),
                          Colors.black.withAlpha(105),
                        ]
                      : [
                          Colors.white.withAlpha(8),
                          Colors.white.withAlpha(76),
                          const Color(0xFFF8F6F3).withAlpha(126),
                        ],
                  stops: const [0, 0.62, 1],
                ),
              ),
            ),
            SafeArea(
              child: AnimatedBuilder(
                animation: _introController,
                builder: (context, child) {
                  final value = Curves.easeOutBack.transform(
                    _introController.value,
                  );
                  return Opacity(
                    opacity: _introController.value,
                    child: Transform.scale(scale: value, child: child),
                  );
                },
                child: const Center(child: _CrazyLogoCelebration()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const List<Color> _wordColors = [
  Color(0xFF933525),
  Color(0xFFE05A47),
  Color(0xFFF6A20A),
  Color(0xFF2E8B7C),
  Color(0xFF2477A8),
  Color(0xFF7B4BB7),
  Color(0xFFC14683),
  Color(0xFF4E7D2D),
];

class _CrazyLogoCelebration extends StatefulWidget {
  const _CrazyLogoCelebration();

  @override
  State<_CrazyLogoCelebration> createState() => _CrazyLogoCelebrationState();
}

class _CrazyLogoCelebrationState extends State<_CrazyLogoCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      height: 330,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              ...List.generate(9, (index) {
                final angle =
                    (_controller.value * math.pi * 2) +
                    (index * math.pi * 2 / 9);
                final wave =
                    math.sin((_controller.value * math.pi * 2) + index) * 10;
                final radius = 118 + wave;
                final dx = math.cos(angle) * radius;
                final dy = math.sin(angle) * radius;
                final color = _wordColors[index % _wordColors.length];

                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: Transform.rotate(
                    angle: -angle * 0.35,
                    child: _OrbitSpark(color: color, index: index),
                  ),
                );
              }),
              const _SplashLogoCard(),
            ],
          );
        },
      ),
    );
  }
}

class _OrbitSpark extends StatelessWidget {
  final Color color;
  final int index;

  const _OrbitSpark({required this.color, required this.index});

  @override
  Widget build(BuildContext context) {
    final isDot = index.isEven;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: isDot ? 14 : 34,
          height: isDot ? 14 : 8,
          decoration: BoxDecoration(
            color: color.withAlpha(isDot ? 150 : 135),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(170)),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(70),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashLogoCard extends StatelessWidget {
  const _SplashLogoCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 238,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            isDark ? AppImages.darkThemeLogo : AppImages.lightThemeLogo,
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            "HariPrabodham Smruti",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? const Color(0xFFFFE7DF) : const Color(0xFF241A17),
              fontSize: 22,
              height: 1.08,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  color: isDark
                      ? const Color(0x99000000)
                      : const Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
