import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DetailAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackTap;
  final double? elevation;
  final bool centerTitle;
  final Color iconColor;
  final Color backgroundColor;

  const DetailAppbar({
    super.key,
    required this.title,
    this.onBackTap,
    this.elevation = 0,
    this.centerTitle = true,
    this.iconColor = const Color(0xFF322318),
    this.backgroundColor = Colors.transparent,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      scrolledUnderElevation: 0,
      backgroundColor: backgroundColor,
      elevation: elevation,
      centerTitle: centerTitle,
      // leadingWidth: SizeConfig.widthMultiplier! * 20,
      leading: GestureDetector(
        onTap: onBackTap ?? () => Navigator.pop(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Icon(
                  CupertinoIcons.left_chevron,
                  color: iconColor,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
      title: Text(title, style: const TextStyle(letterSpacing: 1)),
    );
  }
}
