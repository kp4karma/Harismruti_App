import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/controller/my_diary_controller.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';

double _galleryPhotoAspectRatio(GalleryPhoto photo) {
  final width = photo.width;
  final height = photo.height;
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 1.15;
  }
  return (width / height).clamp(0.72, 1.5);
}

class MyDiarySmruti extends StatelessWidget {
  const MyDiarySmruti({super.key});

  MyDiaryController get controller => Get.find<MyDiaryController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final latest = controller.latestEntry;
      final weekDates = controller.currentWeekDates();
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    CupertinoIcons.calendar,
                    color: primaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openDiary(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Diary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          latest?.title ?? 'Choose a date and write anything',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black.withAlpha(145),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _openDiary(context),
                  icon: Icon(CupertinoIcons.chevron_right, color: primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: weekDates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final date = weekDates[index];
                  return _WeekDatePill(
                    date: date,
                    isSelected: _isSameDate(date, DateTime.now()),
                    hasEntry: controller.hasEntryForDate(date),
                    onTap: () => _openDiaryDate(context, date),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  void _openDiary(BuildContext context) {
    if (!AuthRedirectHelper.ensureLoggedIn()) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        settings: const RouteSettings(name: 'My Diary'),
        builder: (_) => const MyDiaryScreen(),
      ),
    );
  }

  void _openDiaryDate(BuildContext context, DateTime date) {
    if (!AuthRedirectHelper.ensureLoggedIn()) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        settings: const RouteSettings(name: 'Diary Entry Detail'),
        builder: (_) => DiaryEntryDetailScreen(date: date),
      ),
    );
  }
}

class MyDiaryScreen extends StatelessWidget {
  const MyDiaryScreen({super.key});

  MyDiaryController get controller => Get.find<MyDiaryController>();

  @override
  Widget build(BuildContext context) {
    final month = DateTime.now();
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF8F6F3),
      appBar: _DiaryGlassAppBar(
        title: 'Calendar',
        leading: CupertinoIcons.chevron_left,
        onLeadingTap: () => Navigator.pop(context),
        actions: [
          _GlassIconButton(
            icon: CupertinoIcons.add,
            onTap: () => _openDate(context, DateTime.now()),
          ),
        ],
      ),
      body: Obx(() {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height:
                    MediaQuery.of(context).padding.top + kToolbarHeight + 22,
              ),
            ),
            SliverToBoxAdapter(
              child: ResponsiveCenter(
                maxWidth: kContentMaxWidth,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Center(
                        child: Text(
                          _formatMonth(month),
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const _WeekdayHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: controller.monthCalendarDates(month).length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 3,
                              crossAxisSpacing: 3,
                              childAspectRatio: 0.95,
                            ),
                        itemBuilder: (context, index) {
                          final date = controller.monthCalendarDates(
                            month,
                          )[index];
                          if (date == null) {
                            return const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFFFFFFFF),
                              ),
                            );
                          }
                          final entry = controller.entryForDate(date);
                          return _CalendarDateCell(
                            date: date,
                            entry: entry,
                            onTap: () => _openDate(context, date),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
              sliver: SliverList.separated(
                itemCount: controller.entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final entry = controller.entries[index];
                  return _DarkEntryTile(
                    entry: entry,
                    onTap: () => _openDate(context, entry.date),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  void _openDate(BuildContext context, DateTime date) {
    controller.selectDate(date);
    Navigator.push(
      context,
      CupertinoPageRoute(
        settings: const RouteSettings(name: 'Diary Entry Detail'),
        builder: (_) => DiaryEntryDetailScreen(date: date),
      ),
    );
  }
}

class DiaryEntryDetailScreen extends StatefulWidget {
  final DateTime date;
  final String? entryId;
  final List<String> initialImages;

  const DiaryEntryDetailScreen({
    super.key,
    required this.date,
    this.entryId,
    this.initialImages = const [],
  });

  @override
  State<DiaryEntryDetailScreen> createState() => _DiaryEntryDetailScreenState();
}

class _DiaryEntryDetailScreenState extends State<DiaryEntryDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _tagController;
  late final TextEditingController _locationController;
  final List<String> _tags = [];
  final List<String> _collections = [];
  final List<String> _images = [];
  double? _latitude;
  double? _longitude;
  String? _loadedEntryId;

  MyDiaryController get controller => Get.find<MyDiaryController>();

  @override
  void initState() {
    super.initState();
    final entry = _selectedEntry();
    _titleController = TextEditingController();
    _noteController = TextEditingController();
    _tagController = TextEditingController();
    _locationController = TextEditingController();
    _loadEntry(entry);
    if (entry == null && widget.initialImages.isNotEmpty) {
      _images.addAll(widget.initialImages);
    }
  }

  DiaryEntry? _selectedEntry() {
    final id = widget.entryId;
    if (id != null) {
      final entry = controller.entries.firstWhereOrNull(
        (item) => item.id == id,
      );
      if (entry != null) return entry;
    }
    return controller.entryForDate(widget.date);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _tagController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _loadEntry(DiaryEntry? entry) {
    _loadedEntryId = entry?.id;
    _titleController.text = entry?.title ?? '';
    _noteController.text = entry?.note ?? '';
    _locationController.text = entry?.locationName ?? '';
    _tags
      ..clear()
      ..addAll(entry?.tags ?? const []);
    _collections
      ..clear()
      ..addAll(entry?.collections ?? const []);
    _images
      ..clear()
      ..addAll(entry?.images ?? const []);
    _latitude = entry?.latitude;
    _longitude = entry?.longitude;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final entry = _selectedEntry();
      if (_loadedEntryId == null &&
          entry != null &&
          _titleController.text.isEmpty &&
          _noteController.text.isEmpty) {
        _loadEntry(entry);
      }
      return Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        backgroundColor: const Color(0xFFF8F6F3),
        appBar: _DiaryGlassAppBar(
          title: _formatDetailDate(widget.date),
          leading: CupertinoIcons.chevron_left,
          onLeadingTap: () => Navigator.pop(context),
          actions: [
            _GlassIconButton(
              icon: CupertinoIcons.calendar,
              onTap: () => Navigator.push(
                context,
                CupertinoPageRoute(
                  settings: const RouteSettings(name: 'My Diary'),
                  builder: (_) => const MyDiaryScreen(),
                ),
              ),
            ),
            if (entry != null)
              _GlassIconButton(
                icon: CupertinoIcons.delete,
                onTap: () => _confirmDelete(context, entry),
              ),
          ],
        ),
        bottomNavigationBar: _DiaryBottomActionBar(
          onTagTap: _showTagSheet,
          onImageTap: _pickDiaryImages,
          onLocationTap: _showLocationPicker,
          onDiscardTap: () => _discard(entry),
          onSaveTap: _save,
          hasLocation:
              _locationController.text.trim().isNotEmpty ||
              (_latitude != null && _longitude != null),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: _buildEditor(),
        ),
      );
    });
  }

  Widget _buildEditor() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context).padding.top + kToolbarHeight + 18,
        18,
        130,
      ),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primaryColor.withAlpha(14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                cursorColor: primaryColor,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.text,
                style: const TextStyle(
                  color: Color(0xFF322318),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
                decoration: _plainInputDecoration('Title'),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                cursorColor: primaryColor,
                autofocus: _noteController.text.isEmpty,
                minLines: 12,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  color: Color(0xFF322318),
                  fontSize: 20,
                  height: 1.35,
                ),
                decoration: _plainInputDecoration('Write anything here...'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_images.isNotEmpty) ...[
          _DiaryImageStrip(images: _images, onRemove: _removeImage),
          const SizedBox(height: 12),
        ],
        if (_tags.isNotEmpty) ...[
          _EditableTagWrap(tags: _tags, onRemove: _removeTag),
          const SizedBox(height: 10),
        ],
        if (_locationController.text.trim().isNotEmpty ||
            (_latitude != null && _longitude != null))
          _MetaChip(
            icon: CupertinoIcons.location,
            label: _locationButtonLabel(),
          ),
        const SizedBox(height: 18),
        _DateNotesList(
          entries: controller.entriesForDate(widget.date),
          selectedId: _loadedEntryId,
          onTap: (entry) => setState(() => _loadEntry(entry)),
          onNew: () => setState(() => _loadEntry(null)),
        ),
      ],
    );
  }

  InputDecoration _plainInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.black.withAlpha(90)),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    );
  }

  InputDecoration _darkInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.black.withAlpha(95)),
      filled: true,
      fillColor: Colors.white.withAlpha(235),
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: primaryColor.withAlpha(20)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: primaryColor.withAlpha(18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: primaryColor.withAlpha(145), width: 1.2),
      ),
    );
  }

  String _locationButtonLabel() {
    if (_locationController.text.trim().isNotEmpty) {
      return _locationController.text.trim();
    }
    if (_latitude != null && _longitude != null) return 'Location added';
    return 'Add location';
  }

  void _showTagSheet() {
    _showReusableValueSheet(
      title: 'Add tag',
      hint: 'Diary, Family, Travel...',
      controller: _tagController,
      suggestions: controller.allTags,
      selectedValues: _tags,
      onAdd: _addTag,
    );
  }

  Future<void> _pickDiaryImages() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResponsiveBottomCenter(
        maxWidth: kSheetMaxWidth,
        child: _DiaryPhotoSelectionSheet(initialSelected: _images),
      ),
    );
    if (selected == null) return;
    setState(() {
      _images
        ..clear()
        ..addAll(selected);
    });
  }

  void _showReusableValueSheet({
    required String title,
    required String hint,
    required TextEditingController controller,
    required List<String> suggestions,
    required List<String> selectedValues,
    required ValueChanged<String> onAdd,
  }) {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResponsiveBottomCenter(
        maxWidth: kSheetMaxWidth,
        child: _DiaryReusablePickerSheet(
          title: title,
          hint: hint,
          createLabel: title.replaceFirst('Add', 'Create new'),
          suggestions: suggestions,
          selectedValues: selectedValues,
          controller: controller,
        ),
      ),
    ).then((value) {
      final cleanValue = value?.trim();
      if (cleanValue == null || cleanValue.isEmpty) return;
      onAdd(cleanValue);
      controller.clear();
    });
  }

  void _addTag(String tag) {
    setState(() {
      if (!_tags.contains(tag)) _tags.add(tag);
    });
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  void _removeImage(String image) {
    setState(() => _images.remove(image));
  }

  void _showLocationPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Add location'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showManualLocationSheet();
            },
            child: const Text('Type location name'),
          ),
          if (_latitude != null || _locationController.text.isNotEmpty)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                setState(() {
                  _latitude = null;
                  _longitude = null;
                  _locationController.clear();
                });
                Navigator.pop(context);
              },
              child: const Text('Remove location'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showManualLocationSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFF8F6F3),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ResponsiveBottomCenter(
        maxWidth: kSheetMaxWidth,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Location name',
                style: TextStyle(
                  color: Color(0xFF322318),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                autofocus: true,
                style: const TextStyle(color: Color(0xFF322318)),
                decoration: _darkInputDecoration('Temple, home, city...'),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                color: primaryColor,
                borderRadius: BorderRadius.circular(16),
                onPressed: () {
                  setState(() {
                    _latitude = null;
                    _longitude = null;
                  });
                  Navigator.pop(context);
                },
                child: const Text(
                  'Save Location',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    TopNotification.show(title: 'My Diary', message: message);
  }

  void _discard(DiaryEntry? entry) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved diary changes will be removed.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              setState(() => _loadEntry(entry));
              Navigator.pop(context);
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (_noteController.text.trim().isEmpty) {
      _showMessage('Please write something before saving.');
      return;
    }
    controller.saveEntry(
      date: widget.date,
      title: _titleController.text,
      note: _noteController.text,
      tags: _tags,
      collections: _collections,
      images: _images,
      id: _loadedEntryId,
      locationName: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
    );
    _loadedEntryId = controller.entriesForDate(widget.date).firstOrNull?.id;
    setState(() {});
  }

  void _confirmDelete(BuildContext context, DiaryEntry entry) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete diary entry?'),
        content: Text(entry.title),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              controller.deleteEntry(entry.id);
              setState(() {
                _loadEntry(null);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DiaryGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final IconData leading;
  final VoidCallback onLeadingTap;
  final List<Widget> actions;

  const _DiaryGlassAppBar({
    required this.title,
    required this.leading,
    required this.onLeadingTap,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 12);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withAlpha(235),
                      Colors.white.withAlpha(178),
                      Colors.white.withAlpha(70),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AppBar(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leadingWidth: 66,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _GlassIconButton(icon: leading, onTap: onLeadingTap),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF322318),
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            for (final action in actions)
              Padding(padding: const EdgeInsets.only(right: 10), child: action),
            const SizedBox(width: 6),
          ],
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(205),
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor.withAlpha(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: primaryColor, size: 21),
          ),
        ),
      ),
    );
  }
}

class _DiaryBottomActionBar extends StatelessWidget {
  final VoidCallback onTagTap;
  final VoidCallback onImageTap;
  final VoidCallback onLocationTap;
  final VoidCallback onDiscardTap;
  final VoidCallback onSaveTap;
  final bool hasLocation;

  const _DiaryBottomActionBar({
    required this.onTagTap,
    required this.onImageTap,
    required this.onLocationTap,
    required this.onDiscardTap,
    required this.onSaveTap,
    required this.hasLocation,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            MediaQuery.of(context).padding.bottom + 14,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withAlpha(70),
                Colors.white.withAlpha(215),
                Colors.white,
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BottomGlassIconButton(
                icon: CupertinoIcons.tag,
                onTap: onTagTap,
                tooltip: 'Tags',
              ),
              _BottomGlassIconButton(
                icon: CupertinoIcons.photo_on_rectangle,
                onTap: onImageTap,
                tooltip: 'Images',
              ),
              _BottomGlassIconButton(
                icon: hasLocation
                    ? CupertinoIcons.location_fill
                    : CupertinoIcons.location,
                onTap: onLocationTap,
                tooltip: 'Location',
              ),
              _BottomGlassIconButton(
                icon: CupertinoIcons.arrow_counterclockwise,
                onTap: onDiscardTap,
                tooltip: 'Discard',
              ),
              _BottomGlassIconButton(
                icon: CupertinoIcons.check_mark,
                onTap: onSaveTap,
                tooltip: 'Save',
                isPrimary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool isPrimary;

  const _BottomGlassIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: isPrimary ? primaryColor : Colors.white.withAlpha(225),
            shape: BoxShape.circle,
            border: Border.all(
              color: isPrimary
                  ? Colors.transparent
                  : primaryColor.withAlpha(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isPrimary ? 25 : 10),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: isPrimary ? Colors.white : primaryColor,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _PickerEmptyState extends StatelessWidget {
  final String message;

  const _PickerEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(225),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withAlpha(16)),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.info_circle, color: primaryColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.black.withAlpha(135),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryImageStrip extends StatelessWidget {
  final List<String> images;
  final ValueChanged<String> onRemove;

  const _DiaryImageStrip({required this.images, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final image = images[index];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: image.startsWith('http')
                      ? Image.network(image, fit: BoxFit.cover)
                      : Image.file(File(image), fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: GestureDetector(
                  onTap: () => onRemove(image),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(130),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DateNotesList extends StatelessWidget {
  final List<DiaryEntry> entries;
  final String? selectedId;
  final ValueChanged<DiaryEntry> onTap;
  final VoidCallback onNew;

  const _DateNotesList({
    required this.entries,
    required this.selectedId,
    required this.onTap,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Notes on this date',
              style: TextStyle(
                color: Color(0xFF322318),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            _BottomGlassIconButton(
              icon: CupertinoIcons.add,
              onTap: onNew,
              tooltip: 'New note',
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          _PickerEmptyState(message: 'No saved notes for this date yet.')
        else
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => onTap(entry),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selectedId == entry.id
                        ? primaryColor.withAlpha(24)
                        : Colors.white.withAlpha(235),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selectedId == entry.id
                          ? primaryColor.withAlpha(80)
                          : primaryColor.withAlpha(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF322318),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              entry.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.black.withAlpha(130),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (entry.images.isNotEmpty)
                        Icon(CupertinoIcons.photo, color: primaryColor),
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

class _DiaryPhotoSelectionSheet extends StatefulWidget {
  final List<String> initialSelected;

  const _DiaryPhotoSelectionSheet({required this.initialSelected});

  @override
  State<_DiaryPhotoSelectionSheet> createState() =>
      _DiaryPhotoSelectionSheetState();
}

class _DiaryPhotoSelectionSheetState extends State<_DiaryPhotoSelectionSheet> {
  final GalleryController _galleryController = Get.find<GalleryController>();
  late final Set<String> _selected = widget.initialSelected.toSet();

  @override
  Widget build(BuildContext context) {
    final photos = _galleryController.recentPhotos.toList(growable: false)
      ..sort((a, b) {
        final aDate = a.takenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.takenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              color: const Color(0xFFF8F6F3).withAlpha(248),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    _DiaryPhotoSelectionHeader(
                      selectedCount: _selected.length,
                      onCancel: () => Navigator.pop(context),
                      onDone: () => Navigator.pop(context, _selected.toList()),
                    ),
                    Expanded(
                      child: photos.isEmpty
                          ? const _PickerEmptyState(
                              message:
                                  'No recent photos are loaded yet. Pull home to refresh and try again.',
                            )
                          : MasonryGridView.count(
                              controller: scrollController,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                24,
                              ),
                              itemCount: photos.length,
                              crossAxisCount: responsiveImageColumnCount(
                                context,
                              ),
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                              itemBuilder: (context, index) {
                                final photo = photos[index];
                                final value = photo.fullUrl.isNotEmpty
                                    ? photo.fullUrl
                                    : photo.thumbnailUrl;
                                final selected = _selected.contains(value);
                                final selectedIndex = _selected
                                    .toList()
                                    .indexOf(value);
                                return AspectRatio(
                                  aspectRatio: _galleryPhotoAspectRatio(photo),
                                  child: _DiarySelectablePhotoTile(
                                    photo: photo,
                                    selected: selected,
                                    selectedIndex: selectedIndex,
                                    headers: _galleryController.imageHeaders,
                                    onTap: () {
                                      setState(() {
                                        if (selected) {
                                          _selected.remove(value);
                                        } else {
                                          _selected.add(value);
                                        }
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DiaryPhotoSelectionHeader extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  const _DiaryPhotoSelectionHeader({
    required this.selectedCount,
    required this.onCancel,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(218),
        border: Border(bottom: BorderSide(color: primaryColor.withAlpha(16))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(35),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: onCancel,
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Select Photos',
                      style: TextStyle(
                        color: Color(0xFF322318),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedCount == 0
                          ? 'Recent to past'
                          : '$selectedCount selected',
                      style: TextStyle(
                        color: Colors.black.withAlpha(135),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDone,
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiarySelectablePhotoTile extends StatelessWidget {
  final GalleryPhoto photo;
  final bool selected;
  final int selectedIndex;
  final Map<String, String>? headers;
  final VoidCallback onTap;

  const _DiarySelectablePhotoTile({
    required this.photo,
    required this.selected,
    required this.selectedIndex,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 0.93 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetworkImageWithLoader(
              imageUrl: photo.thumbnailUrl,
              title: photo.title ?? 'Diary photo',
              headers: headers,
              fit: BoxFit.cover,
            ),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(70),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
            Positioned(
              top: 7,
              right: 7,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                width: selected ? 27 : 22,
                height: selected ? 27 : 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? primaryColor : Colors.black.withAlpha(45),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.6),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: selected
                      ? Text(
                          '${selectedIndex + 1}',
                          key: ValueKey(selectedIndex),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : const SizedBox(key: ValueKey('empty')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryReusablePickerSheet extends StatefulWidget {
  final String title;
  final String hint;
  final String createLabel;
  final List<String> suggestions;
  final List<String> selectedValues;
  final TextEditingController controller;

  const _DiaryReusablePickerSheet({
    required this.title,
    required this.hint,
    required this.createLabel,
    required this.suggestions,
    required this.selectedValues,
    required this.controller,
  });

  @override
  State<_DiaryReusablePickerSheet> createState() =>
      _DiaryReusablePickerSheetState();
}

class _DiaryReusablePickerSheetState extends State<_DiaryReusablePickerSheet> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    widget.controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSearchChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  List<String> get _availableValues {
    final query = widget.controller.text.trim().toLowerCase();
    final values = widget.suggestions
        .where(
          (value) => !widget.selectedValues.any(
            (selected) => selected.toLowerCase() == value.toLowerCase(),
          ),
        )
        .where((value) => query.isEmpty || value.toLowerCase().contains(query))
        .toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  void _createNew() {
    final value = widget.controller.text.trim();
    if (value.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final values = _availableValues;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6F3).withAlpha(246),
              border: Border(
                top: BorderSide(color: primaryColor.withAlpha(18)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          primaryColor.withAlpha(34),
                          primaryColor.withAlpha(12),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF322318),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 54),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _createNew,
                          child: Text(
                            widget.createLabel,
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: widget.controller,
                          focusNode: _focusNode,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              CupertinoIcons.search,
                              color: primaryColor,
                            ),
                            hintText: widget.hint,
                            filled: true,
                            fillColor: Colors.white.withAlpha(235),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _createNew(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        values.isEmpty
                            ? 'No existing items'
                            : 'Select from existing',
                        style: TextStyle(
                          color: Colors.black.withAlpha(150),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: values.isEmpty
                        ? _PickerEmptyState(
                            message:
                                'Create one now, then it will appear here next time.',
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                            itemCount: values.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final value = values[index];
                              return _ReusablePickerTile(
                                label: value,
                                subtitle:
                                    widget.title.toLowerCase().contains(
                                      'collection',
                                    )
                                    ? 'Collection'
                                    : 'Tag',
                                icon:
                                    widget.title.toLowerCase().contains(
                                      'collection',
                                    )
                                    ? CupertinoIcons.collections
                                    : CupertinoIcons.tag,
                                onTap: () => Navigator.pop(context, value),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReusablePickerTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ReusablePickerTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(235),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withAlpha(16)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primaryColor.withAlpha(22),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF322318),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.black.withAlpha(125),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.circle, color: primaryColor, size: 24),
          ],
        ),
      ),
    );
  }
}

class _WeekDatePill extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool hasEntry;
  final VoidCallback onTap;

  const _WeekDatePill({
    required this.date,
    required this.isSelected,
    required this.hasEntry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : const Color(0xFFF6F1EE),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: hasEntry ? primaryColor : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _weekdayShort(date),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black54,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${date.day}',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 5,
              width: 5,
              decoration: BoxDecoration(
                color: hasEntry
                    ? isSelected
                          ? Colors.white
                          : primaryColor
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  day,
                  style: TextStyle(
                    color: Colors.black.withAlpha(145),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarDateCell extends StatelessWidget {
  final DateTime date;
  final DiaryEntry? entry;
  final VoidCallback onTap;

  const _CalendarDateCell({
    required this.date,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDate(date, DateTime.now());
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: entry == null ? Colors.white : primaryColor.withAlpha(28),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isToday
                ? primaryColor
                : entry == null
                ? Colors.black.withAlpha(14)
                : primaryColor.withAlpha(80),
            width: isToday ? 1.4 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: isToday || entry != null
                      ? primaryColor
                      : Colors.black87,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (entry != null)
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Text(
                  entry!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DarkEntryTile extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;

  const _DarkEntryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(238),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withAlpha(14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${entry.date.day}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF322318),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black.withAlpha(135),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableTagWrap extends StatelessWidget {
  final List<String> tags;
  final ValueChanged<String> onRemove;

  const _EditableTagWrap({required this.tags, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          GestureDetector(
            onTap: () => onRemove(tag),
            child: _MetaChip(icon: CupertinoIcons.xmark_circle, label: tag),
          ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primaryColor.withAlpha(42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primaryColor, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _weekdayShort(DateTime date) {
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return days[date.weekday % 7];
}

String _formatMonth(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String _formatDetailDate(DateTime date) {
  final year = date.year.toString().substring(2);
  return '${_weekdayShort(date)}, ${date.day} ${_monthShort(date)} $year';
}

String _monthShort(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[date.month - 1];
}
