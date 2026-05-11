import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/ProfileController.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/ui/view/Auth/login.dart';
import 'package:harismruti/ui/view/Profile/smruti_section_setting.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/size_config.dart';
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
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: () =>
                                      profileController.pickAndCropImage(),
                                  child: Obx(() {
                                    final image =
                                        profileController.profileImage.value;
                                    return CircleAvatar(
                                      radius: SizeConfig.widthMultiplier! * 15,
                                      backgroundColor: backgroundColor,
                                      backgroundImage: image != null
                                          ? FileImage(image)
                                          : null,
                                      child: image == null
                                          ? Icon(
                                              CupertinoIcons.person,
                                              color: primaryColor,
                                              size:
                                                  SizeConfig.widthMultiplier! *
                                                  10,
                                            )
                                          : null,
                                    );
                                  }),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Virendra Rathod',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '+91 98524 12211',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const Text(
                                  'virendra.v.rathod@gmail.com',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ProfileOption(
                    icon: Icons.favorite_border,
                    label: 'Favorites',
                    onTap: () {
                      // Handle navigation
                    },
                  ),
                  const SizedBox(height: 12),
                  _ProfileOption(
                    icon: Icons.tune,
                    label: 'Customize Sections',
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => SmrutiSectionSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ProfileOption(
                    icon: Icons.logout,
                    label: 'Logout',
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        CupertinoPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                  ),
                ],
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
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, color: Colors.brown),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
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
