import 'dart:ui';

import 'package:flutter/material.dart';

class SwamiTabBar extends StatefulWidget {
  final List<String> tabs;
  final Function(int index)? onTabSelected;
  final int initialIndex;

  const SwamiTabBar({
    super.key,
    required this.tabs,
    this.onTabSelected,
    this.initialIndex = 0,
  });

  @override
  State<SwamiTabBar> createState() => _SwamiTabBarState();
}

class _SwamiTabBarState extends State<SwamiTabBar> {
  late int selectedIndex;
  final ScrollController _scrollController = ScrollController();

  final double itemPadding = 4;
  final double itemWidth = 200;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
  }

  void scrollToIndex(int index) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double itemCenterOffset =
        index * (itemWidth + itemPadding * 2) + itemWidth / 2;
    final double targetOffset = itemCenterOffset - screenWidth / 2;

    final double clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Blur
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: const BoxDecoration(
                  backgroundBlendMode: BlendMode.dstOut,
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [0.5, 0.7, 0.9, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.white24,
                      Colors.white,
                      Colors.white,
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
            child: Row(
              children: [
                // Tab Bar
                Expanded(
                  child: Card(
                    elevation: 200,
                    shadowColor: Colors.black54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    color: Colors.white,
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _scrollController,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: List.generate(widget.tabs.length, (
                                index,
                              ) {
                                final isSelected = selectedIndex == index;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() => selectedIndex = index);
                                    scrollToIndex(index);
                                    if (widget.onTabSelected != null) {
                                      widget.onTabSelected!(index);
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF823D3D)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 150,
                                    ),
                                    child: Text(
                                      widget.tabs[index],
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
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
                                  gradient: const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [Colors.white24, Colors.white],
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
                                  gradient: const LinearGradient(
                                    begin: Alignment.centerRight,
                                    end: Alignment.centerLeft,
                                    colors: [Colors.white24, Colors.white],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Search Button
                Container(
                  height: 48,
                  width: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF823D3D),
                  ),
                  child: const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
