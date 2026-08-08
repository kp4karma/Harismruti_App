import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The shared app bar used throughout the app.
///
/// It keeps navigation controls readable in both themes and lets content show
/// through a softly tinted blur instead of an opaque toolbar.
class FrostedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FrostedAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.centerTitle,
    this.leadingWidth,
    this.titleSpacing,
    this.height = kToolbarHeight,
    this.onBackTap,
    this.backgroundColor,
  });

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool? centerTitle;
  final double? leadingWidth;
  final double? titleSpacing;
  final double height;
  final VoidCallback? onBackTap;
  final Color? backgroundColor;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final resolvedLeading =
        leading ??
        (automaticallyImplyLeading && canPop
            ? FrostedBackButton(onPressed: onBackTap)
            : null);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (backgroundColor ?? scheme.surface).withAlpha(
              scheme.brightness == Brightness.dark ? 188 : 174,
            ),
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant.withAlpha(75)),
            ),
          ),
          child: AppBar(
            title: title,
            actions: actions,
            leading: resolvedLeading,
            automaticallyImplyLeading: false,
            centerTitle: centerTitle,
            leadingWidth: leadingWidth,
            titleSpacing: titleSpacing,
            backgroundColor: Colors.transparent,
            foregroundColor: scheme.onSurface,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
        ),
      ),
    );
  }
}

class FrostedBackButton extends StatelessWidget {
  const FrostedBackButton({super.key, this.onPressed, this.iconColor});

  final VoidCallback? onPressed;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      icon: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withAlpha(190),
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outlineVariant.withAlpha(110)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            CupertinoIcons.chevron_left,
            color: iconColor ?? scheme.onSurface,
            size: 18,
          ),
        ),
      ),
    );
  }
}
