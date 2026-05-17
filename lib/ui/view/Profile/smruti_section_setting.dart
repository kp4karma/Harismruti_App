import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_string.dart';
import 'package:harismruti/widget/appbar/detail_appbar.dart';
import 'package:harismruti/widget/background/custom_background.dart';

class SmrutiSectionSettingsScreen extends StatelessWidget {
  final SmrutiSectionController controller =
      Get.find<SmrutiSectionController>();

  SmrutiSectionSettingsScreen({super.key});

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
          return ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.02).animate(animation),
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
              final isShown = section['is_show'] == true;

              return _PreferenceOptionTile(
                key: ValueKey(title),
                title: title,
                isShown: isShown,
                icon: _iconForSection(title),
                index: index,
                onTap: () =>
                    controller.updateSectionVisibilityByTitle(title, !isShown),
                onChanged: (value) {
                  controller.updateSectionVisibilityByTitle(title, value);
                },
              );
            },
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
      case SmrutiSectionKeys.ofSmruti:
        return Icons.person_search_rounded;
      case SmrutiSectionKeys.location:
        return Icons.place_rounded;
      case SmrutiSectionKeys.album:
        return Icons.photo_album_rounded;
      case SmrutiSectionKeys.collections:
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
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: primaryColor, size: 23),
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
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: primaryColor.withAlpha(170),
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
