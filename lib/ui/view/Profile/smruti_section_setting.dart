import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_string.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/appbar/detail_appbar.dart';
import 'package:harismruti/widget/background/custom_background.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

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
  final GlobalKey _firstDragHandleKey = GlobalKey();
  TutorialCoachMark? _tutorialCoachMark;
  bool _tutorialShown = false;

  @override
  void initState() {
    super.initState();
    _tutorialShown =
        StorageHelper.getValue<bool>(
          key: StorageKeys.reorderTutorialSeen,
          defaultValue: false,
        ) ??
        false;
  }

  void _showReorderTutorial() {
    if (_tutorialShown || _firstDragHandleKey.currentContext == null) return;

    _tutorialShown = true;
    final tutorialCoachMark = TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'reorder-home-section',
          keyTarget: _firstDragHandleKey,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: _ReorderCoachContent(onGotIt: _finishTutorial),
            ),
          ],
        ),
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.72,
      hideSkip: true,
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
      pulseEnable: true,
      onClickTarget: (_) => _finishTutorial(),
      onClickOverlay: (_) => _finishTutorial(),
      onFinish: _markTutorialSeen,
      onSkip: () {
        _markTutorialSeen();
        return true;
      },
    );
    _tutorialCoachMark = tutorialCoachMark;
    tutorialCoachMark.show(context: context);
  }

  void _finishTutorial() {
    _markTutorialSeen();
    _tutorialCoachMark?.finish();
  }

  void _markTutorialSeen() {
    _tutorialShown = true;
    StorageHelper.setValue(key: StorageKeys.reorderTutorialSeen, value: true);
  }

  @override
  void dispose() {
    _tutorialCoachMark?.finish();
    super.dispose();
  }

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
          if (sections.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => mounted ? _showReorderTutorial() : null,
            );
          }
          return Column(
            children: [
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
                    final isShown = section['is_show'] == true;

                    return _PreferenceOptionTile(
                      key: ValueKey(title),
                      title: title,
                      isShown: isShown,
                      icon: _iconForSection(title),
                      index: index,
                      dragHandleKey: index == 0 ? _firstDragHandleKey : null,
                      onTap: () => controller.updateSectionVisibilityByTitle(
                        title,
                        !isShown,
                      ),
                      onChanged: (value) {
                        controller.updateSectionVisibilityByTitle(title, value);
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

class _ReorderCoachContent extends StatelessWidget {
  final VoidCallback onGotIt;

  const _ReorderCoachContent({required this.onGotIt});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width - 32,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(45),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.drag_handle_rounded, color: primaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Reorder sections',
                  style: TextStyle(
                    color: Color(0xFF322318),
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Hold this handle and drag up or down to change the Home screen order.',
            style: TextStyle(
              color: Colors.black.withAlpha(170),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onGotIt,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceOptionTile extends StatelessWidget {
  final String title;
  final bool isShown;
  final IconData icon;
  final int index;
  final GlobalKey? dragHandleKey;
  final VoidCallback onTap;
  final ValueChanged<bool> onChanged;

  const _PreferenceOptionTile({
    super.key,
    required this.title,
    required this.isShown,
    required this.icon,
    required this.index,
    this.dragHandleKey,
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
                  child: SizedBox(
                    key: dragHandleKey,
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
