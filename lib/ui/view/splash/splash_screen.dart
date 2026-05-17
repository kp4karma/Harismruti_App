import 'dart:math' as math;
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/helper/navigation_helper.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_images.dart';
import 'package:harismruti/utils/app_routes.dart';
import 'package:harismruti/widget/background/animated_words_background.dart';
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

    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    NavigationHelper.navigateAndRemoveAll(AppRoutes.home);
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
                  colors: [
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
              Transform.rotate(
                angle: math.sin(_controller.value * math.pi * 2) * 0.025,
                child: const _SplashLogoCard(),
              ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: 238,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(208),
            borderRadius: BorderRadius.circular(38),
            border: Border.all(color: Colors.white.withAlpha(235)),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withAlpha(30),
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
            ],
          ),
        ),
      ),
    );
  }
}
