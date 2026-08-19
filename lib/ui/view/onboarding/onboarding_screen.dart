import 'package:flutter/material.dart';
import 'package:harismruti/helper/navigation_helper.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_routes.dart';
import 'package:harismruti/utils/storage_helper.dart';

class _OnboardingSlide {
  final String image;
  final String title;
  final String subtitle;

  const _OnboardingSlide({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}

const List<_OnboardingSlide> _slides = [
  _OnboardingSlide(
    image: 'assets/onboarding/onboarding_profile_button.png',
    title: 'To Get Your Smruti',
    subtitle: 'Tap the Profile icon, log in, and go to My Smruti.',
  ),
  _OnboardingSlide(
    image: 'assets/onboarding/onboarding_my_smruti.png',
    title: 'Tap "My Smruti"',
    subtitle: 'Capture your live selfie',
  ),
  _OnboardingSlide(
    image: 'assets/onboarding/onboarding_photo_tools.png',
    title: 'Explore Photo Options',
    subtitle:
        'Tap the Options icon to access features like Slideshow, Edit, Download, Wallpaper, and Tags.',
  ),
  _OnboardingSlide(
    image: 'assets/onboarding/onboarding_download_quality.png',
    title: 'Choose Download Quality',
    subtitle: 'Select your preferred photo quality before downloading.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    StorageHelper.setValue(key: StorageKeys.appOnboardingSeen, value: true);
    NavigationHelper.navigateAndRemoveAll(AppRoutes.home);
  }

  void _next() {
    if (_index == _slides.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(foregroundColor: primaryColor),
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Image.asset(
                              slide.image,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            slide.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? primaryColor
                          : primaryColor.withAlpha(60),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isLast ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
