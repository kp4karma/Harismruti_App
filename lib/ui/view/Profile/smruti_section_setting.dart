import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/SmrutiSectionController.dart';
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
          title: "Customize Sections",
        ),
        body: Obx(
          () => ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: controller.sections.length,
            onReorder: (oldIndex, newIndex) {
              controller.reorderSections(oldIndex, newIndex);
              controller.saveSectionsToStorage();
            },
            itemBuilder: (context, index) {
              final section = controller.sections[index];
              return Card(
                key: ValueKey(section['title']),
                margin: const EdgeInsets.symmetric(vertical: 6),
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(
                    Icons.drag_handle,
                    color: Colors.blueGrey,
                  ),
                  title: Text(section['title']),
                  trailing: Switch(
                    value: section['is_show'],
                    onChanged: (val) {
                      controller.updateSectionVisibility(index, val);
                      controller.saveSectionsToStorage();
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
