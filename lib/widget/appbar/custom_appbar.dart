import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/ui/controller/ProfileController.dart';
import 'package:harismruti/ui/view/Profile/profile_screen.dart';
import 'package:harismruti/utils/app_color.dart';

class CustomAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final bool? isShowSubTitle;
  final bool isLoginAppbar;
  final bool isCenterTitle;
  const CustomAppbar({
    super.key,
    this.isLoginAppbar = false,
    this.title,
    this.subtitle,
    this.isShowSubTitle = true,
    this.isCenterTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Glass background layer
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                color: Colors.white.withAlpha(125), // adjust to 0.0 if needed
              ),
            ),
          ),
        ),

        // Actual AppBar content
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          leading: title != null
              ? GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Icon(Icons.arrow_back_ios_new),
                )
              : null,
          titleSpacing: 16,
          title: Row(
            mainAxisAlignment: isCenterTitle
                ? MainAxisAlignment.center
                : MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: isCenterTitle
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? "HariPrabodham Smruti",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: Colors.black,
                      ),
                    ),
                    if (isShowSubTitle == true) SizedBox(height: 2),
                    if (isShowSubTitle == true)
                      Text(
                        subtitle ?? "He hari! Bas ek, tu raji tha...",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                  ],
                ),
              ),
              if (isLoginAppbar == false)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ProfileAppbarButton(
                      onTap: () {
                        if (!AuthRedirectHelper.ensureLoggedIn()) return;
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => ProfileScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);
}

class _ProfileAppbarButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ProfileAppbarButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
    return Obx(() {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primaryColor.withAlpha(22),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(180)),
          ),
          child: Text(
            controller.avatarInitial,
            style: TextStyle(
              color: primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    });
  }
}
