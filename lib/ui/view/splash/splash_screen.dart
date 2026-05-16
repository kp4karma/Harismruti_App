import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/helper/navigation_helper.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_images.dart';
import 'package:harismruti/utils/app_routes.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/carousel/auth_recent_carousel.dart';
import 'package:harismruti/widget/internet_status_widget.dart';

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
      duration: const Duration(milliseconds: 900),
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

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    if (StorageHelper.isLogin()) {
      NavigationHelper.navigateAndRemoveAll(AppRoutes.home);
      return;
    }

    NavigationHelper.navigateAndReplace(AppRoutes.login);
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthRecentCarousel(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withAlpha(190),
                  Colors.white.withAlpha(70),
                  Colors.white.withAlpha(220),
                ],
                stops: const [0, 0.48, 1],
              ),
            ),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: _introController,
              builder: (context, child) {
                final value = Curves.easeOutCubic.transform(
                  _introController.value,
                );
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 18 * (1 - value)),
                    child: Transform.scale(
                      scale: 0.94 + (value * 0.06),
                      child: child,
                    ),
                  ),
                );
              },
              child: const Center(child: _SplashLogoCard()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashLogoCard extends StatelessWidget {
  const _SplashLogoCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: 236,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(205),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white.withAlpha(230)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(28),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AppImages.appLogo, width: 104, height: 104),
              const SizedBox(height: 18),
              const Text(
                "HariPrabodham Smruti",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF241A17),
                  fontSize: 22,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your gallery of smruti.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
