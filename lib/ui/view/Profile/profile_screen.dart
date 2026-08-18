import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/helper/navigation_helper.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/ui/controller/ProfileController.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/ui/controller/auth_controller.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/controller/my_photos_controller.dart';
import 'package:harismruti/ui/controller/theme_controller.dart';
import 'package:harismruti/ui/view/Profile/smruti_section_setting.dart';
import 'package:harismruti/ui/view/Profile/home_widget_settings.dart';
import 'package:harismruti/ui/view/home/my_photos_smruti.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_routes.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/appbar/detail_appbar.dart';
import 'package:harismruti/widget/app_version_label.dart';
import 'package:harismruti/widget/background/custom_background.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileController profileController = Get.put(ProfileController());
  final SmrutiSectionController smrutiController =
      Get.find<SmrutiSectionController>();
  final GlobalKey _mySmrutiKey = GlobalKey();
  TutorialCoachMark? _mySmrutiSpotlight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showMySmrutiSpotlightIfNeeded(),
    );
  }

  void _showMySmrutiSpotlightIfNeeded() {
    if (StorageHelper.hasKey(StorageKeys.mySmrutiSpotlightSeen)) return;
    if (_mySmrutiKey.currentContext == null) return;

    final targets = [
      TargetFocus(
        identify: "my-smruti-option",
        keyTarget: _mySmrutiKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Add Your Smruti",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Tap here to upload and manage your smruti photos.",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ];

    _mySmrutiSpotlight = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.8,
      hideSkip: true,
      onClickTarget: (_) => _dismissMySmrutiSpotlight(),
      onClickOverlay: (_) => _dismissMySmrutiSpotlight(),
      onFinish: _markMySmrutiSpotlightSeen,
    )..show(context: context);
  }

  void _dismissMySmrutiSpotlight() {
    _mySmrutiSpotlight?.finish();
  }

  void _markMySmrutiSpotlightSeen() {
    StorageHelper.setValue(
      key: StorageKeys.mySmrutiSpotlightSeen,
      value: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: Scaffold(
        appBar: DetailAppbar(
          onBackTap: () => Navigator.pop(context),
          title: "Profile",
        ),
        body: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    children: [
                      _ProfileIdCard(profileController: profileController),
                      const SizedBox(height: 12),
                      _AdminManagedProfileOption(
                        featureKey: 'customize_preferences',
                        child: _ProfileOption(
                          icon: Icons.tune_outlined,
                          label: 'Customize Preferences',
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                settings: const RouteSettings(
                                  name: 'Smruti Section Settings',
                                ),
                                builder: (context) =>
                                    SmrutiSectionSettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      Obx(
                        () => smrutiController.isFeatureEnabled('home_widgets')
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: _ProfileOption(
                                  icon: Icons.widgets_outlined,
                                  label: 'Home Screen Widgets',
                                  onTap: () => Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (_) =>
                                          const HomeWidgetSettingsScreen(),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      _AdminManagedProfileOption(
                        featureKey: 'my_smruti',
                        child: _ProfileOption(
                          key: _mySmrutiKey,
                          icon: Icons.face_retouching_natural_outlined,
                          label: 'My Smruti',
                          onTap: () => _openMySmrutiUpload(context),
                        ),
                      ),
                      _AdminManagedProfileOption(
                        featureKey: 'dark_mode',
                        child: Obx(() {
                          final themeController = Get.find<ThemeController>();
                          return _ProfileOption(
                            icon: themeController.isDarkMode.value
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                            label: 'Dark mode',
                            trailing: Switch.adaptive(
                              value: themeController.isDarkMode.value,
                              activeThumbColor: primaryColor,
                              onChanged: themeController.setDarkMode,
                            ),
                            onTap: () => themeController.setDarkMode(
                              !themeController.isDarkMode.value,
                            ),
                          );
                        }),
                      ),
                      _AdminManagedProfileOption(
                        featureKey: 'rate_app',
                        child: _ProfileOption(
                          icon: Icons.star_outline_rounded,
                          label: 'Rate this app',
                          onTap: _rateApp,
                        ),
                      ),
                      _AdminManagedProfileOption(
                        featureKey: 'logout',
                        child: _ProfileOption(
                          icon: Icons.logout_outlined,
                          label: 'Logout',
                          onTap: _logout,
                        ),
                      ),
                      _AdminManagedProfileOption(
                        featureKey: 'delete_account',
                        child: _ProfileOption(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete Account',
                          destructive: true,
                          onTap: () => _confirmDeleteAccount(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: AppVersionLabel(
                  style: TextStyle(
                    fontSize: 14,
                    color: primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() {
    StorageHelper.clearStorage();
    profileController.clearProfile();
    ApiClient.clearGetCache();
    if (Get.isRegistered<AuthController>()) {
      Get.find<AuthController>().notifyLoggedOut();
    }
    if (Get.isRegistered<GalleryController>()) {
      Get.find<GalleryController>().handleAuthChanged();
    }
    TopNotification.success('Logged out successfully.');
    NavigationHelper.navigateAndRemoveAll(AppRoutes.home);
  }

  Future<void> _rateApp() async {
    try {
      final inAppReview = InAppReview.instance;
      if (Platform.isAndroid) {
        await inAppReview.openStoreListing();
        return;
      }
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        return;
      }
      await inAppReview.openStoreListing();
    } catch (_) {
      TopNotification.error(
        'The app store could not be opened. Please try again later.',
      );
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This will permanently delete your account and all associated '
          'data. This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    StorageHelper.clearStorage();
    profileController.clearProfile();
    ApiClient.clearGetCache();
    NavigationHelper.navigateAndRemoveAll(AppRoutes.home);
  }
}

class _ProfileIdCard extends StatelessWidget {
  final ProfileController profileController;

  const _ProfileIdCard({required this.profileController});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Obx(() {
      final myPhotos = Get.isRegistered<MyPhotosController>()
          ? Get.find<MyPhotosController>()
          : null;
      final smrutiPhoto = myPhotos?.photoForPose(MyPhotoPose.front);
      final hasProfilePicture =
          smrutiPhoto != null ||
          profileController.profileImage.value != null ||
          profileController.hasUploadedProfileImage.value ||
          profileController.hasAccountAvatar;
      final rows = [
        _ProfileInfoRowData(
          icon: CupertinoIcons.phone,
          label: 'Mobile',
          value: profileController.displayMobile,
        ),
        _ProfileInfoRowData(
          icon: CupertinoIcons.mail,
          label: 'Email',
          value: profileController.displayEmail,
        ),
        _ProfileInfoRowData(
          icon: CupertinoIcons.location,
          label: 'City',
          value: profileController.displayCity,
        ),
      ].where((row) => row.value.isNotEmpty).toList();

      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 42 : 22),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: primaryColor.withAlpha(isDark ? 18 : 12),
              blurRadius: 18,
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withAlpha(24),
                          scheme.surface.withAlpha(105),
                        ]
                      : [
                          Colors.white.withAlpha(178),
                          scheme.surface.withAlpha(112),
                        ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(42)
                      : Colors.white.withAlpha(205),
                  width: 1.1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: hasProfilePicture
                            ? null
                            : () => _openMySmrutiUpload(context),
                        child: _ProfileAvatar(
                          profileController: profileController,
                          smrutiPhoto: smrutiPhoto,
                          showAddBadge: !hasProfilePicture,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    profileController.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (rows.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Divider(height: 1, color: scheme.outlineVariant),
                    const SizedBox(height: 5),
                  ],
                  Column(
                    children: [
                      for (int index = 0; index < rows.length; index++) ...[
                        _ProfileInfoRow(data: rows[index]),
                        if (index != rows.length - 1) const SizedBox(height: 2),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

void _openMySmrutiUpload(BuildContext context) {
  Navigator.push(
    context,
    CupertinoPageRoute(
      settings: const RouteSettings(name: 'My Smruti Guide'),
      builder: (_) => const MyPhoneGuideScreen(),
    ),
  );
}

class _ProfileAvatar extends StatelessWidget {
  final ProfileController profileController;
  final MyPhotoItem? smrutiPhoto;
  final bool showAddBadge;

  const _ProfileAvatar({
    required this.profileController,
    required this.smrutiPhoto,
    required this.showAddBadge,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = profileController.profileImage.value;
    final avatarUrl = profileController.avatarUrl;
    final accountAvatarUrl = profileController.accountAvatarUrl;
    final scale = tabletScale(context);
    final smrutiImage = smrutiPhoto;
    Widget accountAvatar() => accountAvatarUrl.isNotEmpty
        ? Image.network(
            accountAvatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _ProfileInitialAvatar(initial: profileController.avatarInitial),
            frameBuilder: (context, child, frame, _) {
              if (frame == null) {
                return _ProfileInitialAvatar(
                  initial: profileController.avatarInitial,
                );
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                profileController.markUploadedProfileImageAvailable();
              });
              return child;
            },
          )
        : _ProfileInitialAvatar(initial: profileController.avatarInitial);

    Widget smrutiOrAccountAvatar() {
      if (smrutiImage?.hasLocalFile == true) {
        return Image.file(
          File(smrutiImage!.path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => accountAvatar(),
        );
      }
      if (smrutiImage?.hasRemoteImage == true) {
        return Image.network(
          smrutiImage!.remoteUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => accountAvatar(),
        );
      }
      return accountAvatar();
    }

    final avatar = CircleAvatar(
      radius: 23 * scale,
      backgroundColor: scheme.surfaceContainerHighest,
      child: ClipOval(
        child: SizedBox(
          width: 42 * scale,
          height: 42 * scale,
          child: image != null
              ? Image.file(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => smrutiOrAccountAvatar(),
                )
              : avatarUrl.isNotEmpty
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => smrutiOrAccountAvatar(),
                  frameBuilder: (context, child, frame, _) {
                    if (frame == null) {
                      return _ProfileInitialAvatar(
                        initial: profileController.avatarInitial,
                      );
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      profileController.markUploadedProfileImageAvailable();
                    });
                    return child;
                  },
                )
              : smrutiOrAccountAvatar(),
        ),
      ),
    );
    if (!showAddBadge) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.surface, width: 2),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 12),
          ),
        ),
      ],
    );
  }
}

class _ProfileInitialAvatar extends StatelessWidget {
  final String initial;

  const _ProfileInitialAvatar({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: primaryColor.withAlpha(24),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: primaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProfileInfoRowData {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoRowData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _ProfileInfoRow extends StatelessWidget {
  final _ProfileInfoRowData data;

  const _ProfileInfoRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(data.icon, color: primaryColor, size: 15 * tabletScale(context)),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(
              data.label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminManagedProfileOption extends StatelessWidget {
  final String featureKey;
  final Widget child;

  const _AdminManagedProfileOption({
    required this.featureKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SmrutiSectionController>();
    return Obx(
      () => controller.isFeatureEnabled(featureKey)
          ? Padding(padding: const EdgeInsets.only(top: 6), child: child)
          : const SizedBox.shrink(),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final Widget? trailing;

  const _ProfileOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Colors.red.shade700
        : Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Theme.of(context).colorScheme.surface.withAlpha(230),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: destructive
                      ? Colors.red.withAlpha(10)
                      : primaryColor.withAlpha(10),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: destructive
                        ? Colors.red.withAlpha(42)
                        : primaryColor.withAlpha(36),
                  ),
                ),
                child: Icon(
                  icon,
                  color: destructive ? color : primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null)
                SizedBox(
                  width: 42,
                  height: 28,
                  child: FittedBox(fit: BoxFit.contain, child: trailing),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
