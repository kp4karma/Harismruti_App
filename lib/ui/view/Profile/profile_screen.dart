import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/helper/navigation_helper.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/ui/controller/ProfileController.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/ui/view/Profile/smruti_section_setting.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_routes.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/appbar/detail_appbar.dart';
import 'package:harismruti/widget/background/custom_background.dart';

class ProfileScreen extends StatelessWidget {
  final ProfileController profileController = Get.put(ProfileController());
  final SmrutiSectionController smrutiController =
      Get.find<SmrutiSectionController>();

  ProfileScreen({super.key});

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
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ProfileIdCard(profileController: profileController),
                      const SizedBox(height: 16),
                      _ProfileOption(
                        icon: Icons.tune,
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
                      const SizedBox(height: 12),
                      _ProfileOption(
                        icon: Icons.logout,
                        label: 'Logout',
                        onTap: _logout,
                      ),
                      const SizedBox(height: 12),
                      _ProfileOption(
                        icon: Icons.delete_outline,
                        label: 'Delete Account',
                        destructive: true,
                        onTap: () => _confirmDeleteAccount(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "V 1.0.0",
                    style: TextStyle(
                      fontSize: 16,
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
    TopNotification.success('Logged out successfully.');
    NavigationHelper.navigateAndRemoveAll(AppRoutes.home);
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
    return Obx(() {
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

      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(105),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(170)),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withAlpha(18),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _ProfileAvatar(profileController: profileController),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profileController.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  children: [
                    for (int index = 0; index < rows.length; index++) ...[
                      _ProfileInfoRow(data: rows[index]),
                      if (index != rows.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _ProfileAvatar extends StatelessWidget {
  final ProfileController profileController;

  const _ProfileAvatar({required this.profileController});

  @override
  Widget build(BuildContext context) {
    final image = profileController.profileImage.value;
    final avatarUrl = profileController.avatarUrl;
    final scale = tabletScale(context);
    return CircleAvatar(
      radius: 28 * scale,
      backgroundColor: Colors.white.withAlpha(170),
      child: ClipOval(
        child: SizedBox(
          width: 50 * scale,
          height: 50 * scale,
          child: image != null
              ? Image.file(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _ProfileInitialAvatar(
                    initial: profileController.avatarInitial,
                  ),
                )
              : avatarUrl.isNotEmpty
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _ProfileInitialAvatar(
                    initial: profileController.avatarInitial,
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _ProfileInitialAvatar(
                      initial: profileController.avatarInitial,
                    );
                  },
                )
              : _ProfileInitialAvatar(initial: profileController.avatarInitial),
        ),
      ),
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
          fontSize: 24,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(82),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(130)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30 * tabletScale(context),
                height: 30 * tabletScale(context),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(100),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white.withAlpha(145)),
                ),
                child: Icon(
                  data.icon,
                  color: primaryColor,
                  size: 16 * tabletScale(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.label,
                      style: TextStyle(
                        color: primaryColor.withAlpha(170),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      data.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _ProfileOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red.shade700 : Colors.brown;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 16, color: color),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
