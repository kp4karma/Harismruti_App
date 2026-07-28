import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_string.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/widget/appbar/detail_appbar.dart';
import 'package:harismruti/widget/background/custom_background.dart';

class SmrutiSectionSettingsScreen extends StatefulWidget {
  const SmrutiSectionSettingsScreen({super.key});

  @override
  State<SmrutiSectionSettingsScreen> createState() =>
      _SmrutiSectionSettingsScreenState();
}

class _SmrutiSectionSettingsScreenState
    extends State<SmrutiSectionSettingsScreen> {
  final SmrutiSectionController controller =
      Get.find<SmrutiSectionController>();

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: Scaffold(
        appBar: DetailAppbar(
          onBackTap: () => Navigator.pop(context),
          title: "Customize Preferences",
        ),
        body: Obx(() {
          final sections = controller.customizableSections();
          return ResponsiveCenter(
            maxWidth: kContentMaxWidth,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _ReorderSectionHeader(),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.transparent,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 1,
                            end: 1.02,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    physics: const BouncingScrollPhysics(),
                    itemCount: sections.length,
                    onReorder: controller.reorderCustomizableSections,
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      final title = section['title'].toString();
                      final displayName = section['display_name']
                          ?.toString()
                          .trim();
                      final isShown = section['is_show'] == true;

                      return _PreferenceOptionTile(
                        key: ValueKey(title),
                        title: displayName?.isNotEmpty == true
                            ? displayName!
                            : title,
                        isShown: isShown,
                        icon: _iconForSection(title),
                        index: index,
                        onTap: () => controller.updateSectionVisibilityByTitle(
                          title,
                          !isShown,
                        ),
                        onChanged: (value) {
                          controller.updateSectionVisibilityByTitle(
                            title,
                            value,
                          );
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: controller.resetToDefaultOrder,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text(
                          'Set to Default Order',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  IconData _iconForSection(String title) {
    switch (title) {
      case SmrutiSectionKeys.recent:
        return Icons.auto_awesome_rounded;
      case SmrutiSectionKeys.withSmruti:
        return Icons.groups_rounded;
      case SmrutiSectionKeys.ofDarshan:
        return Icons.person_search_rounded;
      case SmrutiSectionKeys.location:
        return Icons.place_rounded;
      case SmrutiSectionKeys.album:
        return Icons.photo_album_rounded;
      case SmrutiSectionKeys.yearCollection:
      case SmrutiSectionKeys.myCollection:
        return Icons.collections_bookmark_rounded;
      case SmrutiSectionKeys.myPhotos:
        return Icons.face_retouching_natural_rounded;
      case SmrutiSectionKeys.myDiary:
        return Icons.edit_note_rounded;
      case SmrutiSectionKeys.myFavorite:
        return Icons.favorite_rounded;
      default:
        return Icons.grid_view_rounded;
    }
  }
}

/// Section title with a tap-triggered help popover explaining drag-to-reorder,
/// replacing the old auto-shown coach-mark dialog.
class _ReorderSectionHeader extends StatefulWidget {
  const _ReorderSectionHeader();

  @override
  State<_ReorderSectionHeader> createState() => _ReorderSectionHeaderState();
}

class _ReorderSectionHeaderState extends State<_ReorderSectionHeader> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _popoverEntry;

  @override
  void dispose() {
    _removePopover();
    super.dispose();
  }

  void _togglePopover() {
    if (_popoverEntry != null) {
      _removePopover();
      return;
    }
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) =>
          _ReorderHelpPopover(layerLink: _layerLink, onDismiss: _removePopover),
    );
    _popoverEntry = entry;
    overlay.insert(entry);
  }

  void _removePopover() {
    _popoverEntry?.remove();
    _popoverEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Row(
        children: [
          Icon(Icons.drag_handle_rounded, color: primaryColor, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Drag to reorder',
              style: TextStyle(
                color: Color(0xFF322318),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          GestureDetector(
            onTap: _togglePopover,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withAlpha(16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Platform.isIOS
                    ? CupertinoIcons.info
                    : Icons.help_outline_rounded,
                color: primaryColor,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReorderHelpPopover extends StatelessWidget {
  final LayerLink layerLink;
  final VoidCallback onDismiss;

  const _ReorderHelpPopover({required this.layerLink, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-screen barrier: tapping anywhere outside the popover dismisses it,
        // without blocking the list once the popover itself is closed.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const SizedBox.shrink(),
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 10),
          child: Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              // Absorb taps on the card itself so they don't fall through to the barrier.
              onTap: () {},
              child: Container(
                width: 260,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(45),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.drag_handle_rounded,
                          color: primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Reorder sections',
                            style: TextStyle(
                              color: Color(0xFF322318),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hold the handle and drag up or down to change the Home screen order.',
                      style: TextStyle(
                        color: Colors.black.withAlpha(170),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreferenceOptionTile extends StatelessWidget {
  final String title;
  final bool isShown;
  final IconData icon;
  final int index;
  final VoidCallback onTap;
  final ValueChanged<bool> onChanged;

  const _PreferenceOptionTile({
    super.key,
    required this.title,
    required this.isShown,
    required this.icon,
    required this.index,
    required this.onTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withAlpha(14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 46 * tabletScale(context),
                  height: 46 * tabletScale(context),
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: primaryColor,
                    size: 23 * tabletScale(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF322318),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isShown ? 'Shown on home' : 'Hidden from home',
                        style: TextStyle(
                          color: Colors.black.withAlpha(128),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(value: isShown, onChanged: onChanged),
                ReorderableDragStartListener(
                  index: index,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Icon(
                        Icons.drag_handle_rounded,
                        color: primaryColor.withAlpha(170),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
