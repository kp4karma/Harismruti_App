import 'dart:ui';

import 'package:flutter/material.dart';

class SwamiTabBar extends StatefulWidget {
  final List<String> tabs;
  final Function(int index)? onTabSelected;
  final VoidCallback? onSearchTap;
  final VoidCallback? onFilterTap;
  final int initialIndex;

  const SwamiTabBar({
    super.key,
    required this.tabs,
    this.onTabSelected,
    this.onSearchTap,
    this.onFilterTap,
    this.initialIndex = 0,
  });

  @override
  State<SwamiTabBar> createState() => _SwamiTabBarState();
}

class _SwamiTabBarState extends State<SwamiTabBar> {
  late int selectedIndex;
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _tabKeys;

  @override
  void initState() {
    super.initState();
    selectedIndex = _safeIndex(widget.initialIndex);
    _tabKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndex(selectedIndex, animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant SwamiTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final tabsChanged =
        oldWidget.tabs.length != widget.tabs.length ||
        Iterable<int>.generate(
          widget.tabs.length,
        ).any((index) => oldWidget.tabs[index] != widget.tabs[index]);
    if (tabsChanged) {
      _tabKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
    }

    final nextIndex = _safeIndex(widget.initialIndex);
    if (nextIndex != selectedIndex || tabsChanged) {
      selectedIndex = nextIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToIndex(selectedIndex, animate: false);
      });
    }
  }

  int _safeIndex(int index) {
    if (widget.tabs.isEmpty) return 0;
    return index.clamp(0, widget.tabs.length - 1);
  }

  void _scrollToIndex(int index, {bool animate = true}) {
    if (!mounted || index < 0 || index >= _tabKeys.length) return;
    final tabContext = _tabKeys[index].currentContext;
    if (tabContext == null) return;

    Scrollable.ensureVisible(
      tabContext,
      alignment: 0.5,
      duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
      curve: Curves.easeInOut,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showActions =
        widget.onSearchTap != null || widget.onFilterTap != null;

    return Stack(
      children: [
        // Background Blur
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  backgroundBlendMode: BlendMode.dstOut,
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [0.5, 0.7, 0.9, 1.0],
                    colors: [
                      Colors.transparent,
                      scheme.surface.withAlpha(60),
                      scheme.surface,
                      scheme.surface,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Tab bar & search icon
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SafeArea(
            minimum: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                // Tab Bar
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    elevation: 12,
                    shadowColor: Theme.of(context).shadowColor.withAlpha(100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    color: scheme.surfaceContainerHigh,
                    child: Stack(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: _scrollController,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ...List.generate(widget.tabs.length, (
                                          index,
                                        ) {
                                          final isSelected =
                                              selectedIndex == index;
                                          return GestureDetector(
                                            key: _tabKeys[index],
                                            onTap: () {
                                              setState(
                                                () => selectedIndex = index,
                                              );
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                    _scrollToIndex(index);
                                                  });
                                              if (widget.onTabSelected !=
                                                  null) {
                                                widget.onTabSelected!(index);
                                              }
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0xFF823D3D)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                              constraints: const BoxConstraints(
                                                minWidth: 150,
                                              ),
                                              child: Text(
                                                widget.tabs[index],
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : scheme.onSurface,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Right Fade
                        if (selectedIndex != widget.tabs.length - 1)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: 80,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      scheme.surfaceContainerHigh.withAlpha(0),
                                      scheme.surfaceContainerHigh,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Left Fade
                        if (selectedIndex != 0)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 80,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  gradient: LinearGradient(
                                    begin: Alignment.centerRight,
                                    end: Alignment.centerLeft,
                                    colors: [
                                      scheme.surfaceContainerHigh.withAlpha(0),
                                      scheme.surfaceContainerHigh,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                if (showActions) ...[
                  const SizedBox(width: 10),
                  if (widget.onSearchTap != null)
                    _BottomActionButton(
                      icon: Icons.search,
                      onTap: widget.onSearchTap,
                    ),
                  if (widget.onSearchTap != null && widget.onFilterTap != null)
                    const SizedBox(width: 8),
                  if (widget.onFilterTap != null)
                    _BottomActionButton(
                      icon: Icons.tune_rounded,
                      onTap: widget.onFilterTap,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _BottomActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        width: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF823D3D),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
