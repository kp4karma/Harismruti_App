import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: backgroundColor == Colors.transparent
              ? scheme.surface.withAlpha(158)
              : backgroundColor.withAlpha(190),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          centerTitle: centerTitle,
          leading: GestureDetector(
            onTap: onBackTap ?? () => Navigator.pop(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh.withAlpha(175),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.outlineVariant.withAlpha(110),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Icon(
                      CupertinoIcons.left_chevron,
                      color: iconColor ?? scheme.onSurface,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          title: Text(title, style: const TextStyle(letterSpacing: 1)),
          actions: actions,
        ),
      ),
    );
  }
}
