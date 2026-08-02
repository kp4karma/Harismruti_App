import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/ProfileController.dart';
import 'package:harismruti/ui/view/Profile/profile_screen.dart';
import 'package:harismruti/services/notification_history_service.dart';
import 'package:harismruti/ui/view/notification/notification_history_screen.dart';
import 'package:harismruti/utils/app_routes.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/storage_helper.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final accent = _appbarAccent(context);
    return Stack(
      children: [
        // Glass background layer
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: scheme.brightness == Brightness.dark
                        ? const [Color(0xC7241A18), Color(0xA6120E0D)]
                        : const [Color(0xD9FFFFFF), Color(0xA6FFF8F4)],
                  ),
                ),
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
                        color: Theme.of(context).colorScheme.onSurface,
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
                          color: accent,
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
                    _NotificationAppbarButton(
                      onTap: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                          settings: const RouteSettings(name: 'Notifications'),
                          builder: (_) => const NotificationHistoryScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ProfileAppbarButton(
                      onTap: () {
                        if (!StorageHelper.isLogin()) {
                          Get.toNamed(AppRoutes.loginMobile);
                          return;
                        }
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            settings: const RouteSettings(name: 'Profile'),
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

class _NotificationAppbarButton extends StatelessWidget {
  const _NotificationAppbarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationHistoryService.revision,
      builder: (_, __, ___) {
        final count = NotificationHistoryService.unreadCount;
        final accent = _appbarAccent(context);
        return IconButton(
          tooltip: 'Notifications',
          onPressed: onTap,
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: Icon(CupertinoIcons.bell, color: accent, size: 25),
          ),
        );
      },
    );
  }
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
      final accent = _appbarAccent(context);
      final isLoggedIn = StorageHelper.isLogin();
      final image = controller.profileImage.value;
      final avatarUrl = controller.avatarUrl;

      Widget avatarChild;
      if (!isLoggedIn) {
        avatarChild = Icon(CupertinoIcons.person, color: accent, size: 22);
      } else if (image != null) {
        avatarChild = ClipOval(
          child: Image.file(
            image,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _AppbarInitial(controller: controller),
          ),
        );
      } else if (avatarUrl.isNotEmpty) {
        avatarChild = ClipOval(
          child: Image.network(
            avatarUrl,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _AppbarInitial(controller: controller),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _AppbarInitial(controller: controller);
            },
          ),
        );
      } else {
        avatarChild = _AppbarInitial(controller: controller);
      }

      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withAlpha(28),
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: avatarChild,
        ),
      );
    });
  }
}

class _AppbarInitial extends StatelessWidget {
  final ProfileController controller;

  const _AppbarInitial({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Text(
      controller.avatarInitial,
      style: TextStyle(
        color: _appbarAccent(context),
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

Color _appbarAccent(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFFFB4A5)
      : primaryColor;
}
