import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Shared tablet-responsive vocabulary. Detection is based on the shortest
/// side of the screen (not raw width) so it stays stable across rotation --
/// a tablet's width jumps past the phone breakpoint the moment it rotates to
/// landscape, but its shortest side never does.
const double kTabletBreakpoint = 600;
const double kLargeTabletBreakpoint = 900;

/// Max-width caps used to keep phone-shaped content (forms, sheets, settings
/// lists) from stretching edge-to-edge on a tablet.
const double kFormMaxWidth = 480;
const double kSheetMaxWidth = 560;
const double kContentMaxWidth = 640;

bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= kTabletBreakpoint;

bool isLargeTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= kLargeTabletBreakpoint;

/// Context-free tablet detection (physical screen size), safe to call from
/// `initState()` or anywhere else a `BuildContext` isn't available/settled
/// yet -- `MediaQuery.sizeOf(context)` cannot be used in `initState()`.
Size _physicalSizeInDp() {
  final view = ui.PlatformDispatcher.instance.views.first;
  return view.physicalSize / view.devicePixelRatio;
}

bool isTabletDevice() => _physicalSizeInDp().shortestSide >= kTabletBreakpoint;

bool isLargeTabletDevice() =>
    _physicalSizeInDp().shortestSide >= kLargeTabletBreakpoint;

/// Multiplier for bumping fixed icon/avatar/card/marker sizes on larger
/// screens: 1.0 on phone, 1.25 on tablet, 1.45 on large tablet (11-12"+).
double tabletScale(BuildContext context) {
  final shortestSide = MediaQuery.sizeOf(context).shortestSide;
  if (shortestSide >= kLargeTabletBreakpoint) return 1.45;
  if (shortestSide >= kTabletBreakpoint) return 1.25;
  return 1.0;
}

/// Number of columns for full information cards. Phones keep the original
/// single-column layout while tablets and desktop-sized windows use the
/// available horizontal space.
int responsiveCardColumnCount(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1400) return 4;
  if (width >= 1000) return 3;
  if (width >= kTabletBreakpoint) return 2;
  return 1;
}

/// Number of columns for image-first masonry galleries.
int responsiveImageColumnCount(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1400) return 6;
  if (width >= 1100) return 5;
  if (width >= kLargeTabletBreakpoint) return 4;
  if (width >= kTabletBreakpoint) return 3;
  return 2;
}

/// Caps [child] to [maxWidth] and centers it. A no-op on phone widths (the
/// constraint never binds), so phone layout is byte-for-byte unchanged;
/// on tablet it keeps phone-shaped content (forms, sheets, settings rows)
/// from stretching edge-to-edge.
class ResponsiveCenter extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ResponsiveCenter({
    super.key,
    required this.maxWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Caps [child] to [maxWidth], centers it horizontally, and keeps it attached
/// to the bottom edge. Use this for modal bottom-sheet content.
class ResponsiveBottomCenter extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ResponsiveBottomCenter({
    super.key,
    required this.maxWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
