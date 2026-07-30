import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/api/repositories/gallery_repository.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_filter_sheet.dart';

class _FilterWidgetController extends GalleryController {
  _FilterWidgetController() : super(repository: const GalleryRepository());

  // Deliberately isolate this widget test from GalleryController network and
  // storage startup work.
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> resetFiltersForSheet() async {}

  @override
  Future<void> loadFilters({
    Map<String, List<String>> selected = const {},
    bool force = false,
  }) async {}

  @override
  List<GalleryFilterGroup> filtersWithUserTagsForSelection(
    Map<String, List<String>> selected,
  ) {
    const option = GalleryFilterOption(
      value: 'value',
      label: 'Example',
      count: 3,
    );
    return const [
      GalleryFilterGroup(
        slug: 'my_smruti_with',
        title: 'With',
        options: [option],
      ),
      GalleryFilterGroup(
        slug: 'my_smruti_location',
        title: 'Location',
        options: [option],
      ),
      GalleryFilterGroup(
        slug: 'my_smruti_smruti_of',
        title: 'Smruti Of',
        options: [option],
      ),
      GalleryFilterGroup(
        slug: 'my_smruti_darshan_of',
        title: 'Darshan Of',
        options: [option],
      ),
      GalleryFilterGroup(slug: 'subject', title: 'Smruti', options: [option]),
    ];
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put<GalleryController>(_FilterWidgetController());
  });

  tearDown(Get.reset);

  testWidgets('groups My Smruti under matching main-category subheaders', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GalleryFilterSheet())),
    );
    await tester.pump();

    expect(find.text('My Smruti'), findsOneWidget);
    expect(find.text('Darshan With'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Smruti'), findsWidgets);
    expect(find.text('Darshan Of'), findsOneWidget);
  });
}
