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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: scheme.brightness == Brightness.dark
                  ? [
                      (backgroundColor ?? scheme.surface).withAlpha(224),
                      scheme.surfaceContainerHigh.withAlpha(188),
                    ]
                  : [
                      Colors.white.withAlpha(226),
                      (backgroundColor ?? scheme.surfaceContainer).withAlpha(
                        190,
                      ),
                    ],
            ),
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant.withAlpha(110)),
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
    return FrostedAppBarIconButton(
      icon: CupertinoIcons.chevron_left,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      iconColor: iconColor,
    );
  }
}

/// A consistent frosted control for app-bar and detail-screen actions.
class FrostedAppBarIconButton extends StatelessWidget {
  const FrostedAppBarIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(7),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              child: Tooltip(
                message: tooltip ?? '',
                excludeFromSemantics: tooltip == null,
                child: Ink(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              scheme.onSurface.withAlpha(30),
                              scheme.surfaceContainerHigh.withAlpha(205),
                            ]
                          : [
                              Colors.white.withAlpha(242),
                              scheme.surfaceContainerHigh.withAlpha(218),
                            ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.outlineVariant.withAlpha(isDark ? 125 : 90),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withAlpha(isDark ? 55 : 32),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? scheme.onSurface,
                    size: 21,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
