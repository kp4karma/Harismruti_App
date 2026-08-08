import 'package:flutter/material.dart';
import 'package:harismruti/widget/appbar/frosted_appbar.dart';

class DetailAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackTap;
  final double? elevation;
  final bool centerTitle;
  final Color? iconColor;
  final Color backgroundColor;
  final List<Widget>? actions;

  const DetailAppbar({
    super.key,
    required this.title,
    this.onBackTap,
    this.elevation = 0,
    this.centerTitle = true,
    this.iconColor,
    this.backgroundColor = Colors.transparent,
    this.actions,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return FrostedAppBar(
      centerTitle: centerTitle,
      leading: FrostedBackButton(onPressed: onBackTap, iconColor: iconColor),
      backgroundColor: backgroundColor == Colors.transparent
          ? null
          : backgroundColor,
      title: Text(title, style: const TextStyle(letterSpacing: 1)),
      actions: actions,
    );
  }
}
