import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/helper/auth_redirect_helper.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/controller/my_diary_controller.dart';
import 'package:harismruti/ui/controller/theme_controller.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/widget/appbar/frosted_appbar.dart';
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
          color: Theme.of(context).colorScheme.surfaceContainer,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (latest != null)
                  IconButton(
                    tooltip: 'Edit latest entry',
                    onPressed: () => _openDiaryDate(
                      context,
                      latest.date,
                      entryId: latest.id,
                    ),
                    icon: Icon(CupertinoIcons.pencil, color: primaryColor),
                  ),
                IconButton(
                  tooltip: "Create today's entry",
                  onPressed: () =>
                      _openDiaryDate(context, DateTime.now(), createNew: true),
                  icon: Icon(
                    CupertinoIcons.add_circled_solid,
                    color: primaryColor,
                  ),
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

  void _openDiaryDate(
    BuildContext context,
    DateTime date, {
    String? entryId,
    bool createNew = false,
  }) {
    if (!AuthRedirectHelper.ensureLoggedIn()) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        settings: const RouteSettings(name: 'Diary Entry Detail'),
        builder: (_) => DiaryEntryDetailScreen(
          date: date,
          entryId: entryId,
          createNew: createNew,
        ),
      ),
    );
  }
}

class MyDiaryScreen extends StatefulWidget {
  const MyDiaryScreen({super.key});

  @override
  State<MyDiaryScreen> createState() => _MyDiaryScreenState();
}

class _MyDiaryScreenState extends State<MyDiaryScreen> {
  int _page = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  final _search = TextEditingController();

  MyDiaryController get controller => Get.find<MyDiaryController>();

  static const _titles = [
    'Calendar',
    'Timeline',
    'Map',
    'Attachments',
    'Search',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _DiaryGlassAppBar(
        title: _titles[_page],
        leading: CupertinoIcons.chevron_left,
        onLeadingTap: () => Navigator.pop(context),
        actions: [
          FrostedAppBarIconButton(
            icon: CupertinoIcons.settings,
            tooltip: 'Diary settings',
            onPressed: () => _showSettings(context),
          ),
          FrostedAppBarIconButton(
            icon: CupertinoIcons.ellipsis,
            tooltip: 'More options',
            onPressed: () => _showMore(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        tooltip: 'New diary entry',
        onPressed: () => _showDatePicker(context),
        child: const Icon(CupertinoIcons.add),
      ),
      bottomNavigationBar: _DiaryGlassNavigation(
        selectedIndex: _page,
        onDestinationSelected: (value) => setState(() => _page = value),
      ),
      body: Obx(
        () => switch (_page) {
          0 => _calendar(context),
          1 => _DiaryTimeline(
            entries: controller.entries,
            onTap: (e) => _openEntry(context, e),
          ),
          2 => _DiaryMapList(
            entries: controller.entries
                .where(
                  (e) => e.locationName?.isNotEmpty == true || e.hasLocation,
                )
                .toList(),
            onTap: (e) => _openEntry(context, e),
          ),
          3 => _DiaryAttachments(
            entries: controller.entries,
            onTap: (e) => _openEntry(context, e),
          ),
          _ => _DiarySearch(
            entries: controller.entries,
            search: _search,
            onTap: (e) => _openEntry(context, e),
          ),
        },
      ),
    );
  }

  Widget _calendar(BuildContext context) => CustomScrollView(
    physics: const BouncingScrollPhysics(),
    slivers: [
      SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.of(context).padding.top + kToolbarHeight + 22,
        ),
      ),
      SliverToBoxAdapter(
        child: ResponsiveCenter(
          maxWidth: kContentMaxWidth,
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    ),
                    icon: const Icon(CupertinoIcons.chevron_left),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1),
                    ),
                    icon: const Icon(CupertinoIcons.chevron_right),
                  ),
                ],
              ),
              const _WeekdayHeader(),
              for (final month in List.generate(
                3,
                (index) => DateTime(_month.year, _month.month + index),
              ))
                _monthSection(context, month),
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 110)),
    ],
  );

  Widget _monthSection(BuildContext context, DateTime month) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Text(
          _formatMonth(month),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: controller.monthCalendarDates(month).length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: .86,
          ),
          itemBuilder: (context, index) {
            final date = controller.monthCalendarDates(month)[index];
            if (date == null) return const SizedBox.shrink();
            final entry = controller.entryForDate(date);
            return _CalendarDateCell(
              date: date,
              entry: entry,
              entryCount: controller.entriesForDate(date).length,
              onTap: () => _openDate(context, date),
            );
          },
        ),
      ),
    ],
  );

  Future<void> _openDate(
    BuildContext context,
    DateTime date, {
    bool createNew = false,
  }) async {
    controller.selectDate(date);
    final entries = controller.entriesForDate(date);
    if (!createNew && entries.isNotEmpty) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DateEntryChooser(date: date, entries: entries),
      );
      if (!context.mounted || choice == null) return;
      if (choice == _DateEntryChooser.newEntryId) {
        createNew = true;
      } else {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => DiaryEntryDetailScreen(date: date, entryId: choice),
          ),
        );
        return;
      }
    } else if (entries.isEmpty) {
      createNew = true;
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        settings: const RouteSettings(name: 'Diary Entry Detail'),
        builder: (_) =>
            DiaryEntryDetailScreen(date: date, createNew: createNew),
      ),
    );
  }

  void _openEntry(BuildContext context, DiaryEntry entry) => Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (_) =>
          DiaryEntryDetailScreen(date: entry.date, entryId: entry.id),
    ),
  );

  Future<void> _showDatePicker(BuildContext context) async {
    final date = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close date picker',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const _DiaryNewEntryPicker(),
    );
    if (date != null && context.mounted) {
      _openDate(context, date, createNew: true);
    }
  }

  void _showMore(BuildContext context) => showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => CupertinoActionSheet(
      title: Text('${_titles[_page]} options'),
      actions: [
        for (final label in ['Tags', 'Export', 'On this day'])
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showUnavailable(label);
            },
            child: Text(label),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ),
  );

  Future<void> _showSettings(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DiarySettingsSheet(),
    );
    if (mounted) setState(() {});
  }

  void _showUnavailable(String label) => TopNotification.show(
    title: label,
    message: '$label will be available after diary synchronization completes.',
  );
}

class _DiaryNewEntryPicker extends StatefulWidget {
  const _DiaryNewEntryPicker();
  @override
  State<_DiaryNewEntryPicker> createState() => _DiaryNewEntryPickerState();
}

class _DateEntryChooser extends StatelessWidget {
  const _DateEntryChooser({required this.date, required this.entries});
  static const newEntryId = '__new_diary_entry__';
  final DateTime date;
  final List<DiaryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .72,
          ),
          color: scheme.surface.withAlpha(235),
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            MediaQuery.paddingOf(context).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 42, child: Divider(thickness: 4)),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDetailDate(date),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${entries.length} ${entries.length == 1 ? 'note' : 'notes'}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, newEntryId),
                    icon: const Icon(CupertinoIcons.add),
                    label: const Text('New note'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final entry = entries[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      leading: entry.images.isEmpty
                          ? CircleAvatar(
                              backgroundColor: primaryColor.withAlpha(24),
                              child: Icon(
                                CupertinoIcons.doc_text,
                                color: primaryColor,
                              ),
                            )
                          : _DiaryThumb(path: entry.images.first, size: 52),
                      title: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${_time(entry.createdAt)}\n${entry.note}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(CupertinoIcons.chevron_right),
                      onTap: () => Navigator.pop(context, entry.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiaryNewEntryPickerState extends State<_DiaryNewEntryPicker> {
  DateTime selected = DateTime.now();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Material(
              color: scheme.surface.withAlpha(225),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CalendarDatePicker(
                        initialDate: selected,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2200),
                        onDateChanged: (value) =>
                            setState(() => selected = value),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, selected),
                          child: const Text(
                            'New entry',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _DiaryTimeline extends StatelessWidget {
  const _DiaryTimeline({required this.entries, required this.onTap});
  final List<DiaryEntry> entries;
  final ValueChanged<DiaryEntry> onTap;
  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _DiaryEmpty(
        icon: CupertinoIcons.book,
        title: 'Your story starts here',
        message: 'Tap + to write your first entry.',
      );
    }
    final settings = Map<String, dynamic>.from(
      StorageHelper.getValue<Map>(
            key: StorageKeys.myDiarySettings,
            defaultValue: const {},
          ) ??
          const {},
    );
    final showTimes = settings['showTimes'] as bool? ?? true;
    final showTags = settings['showTags'] as bool? ?? true;
    final previewPictures = settings['previewPictures'] as bool? ?? true;
    final fullEntries = settings['fullEntries'] as bool? ?? false;
    String? month;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 86,
        18,
        100,
      ),
      itemCount: entries.length,
      itemBuilder: (_, index) {
        final entry = entries[index];
        final heading = _formatMonth(entry.date);
        final showHeading = heading != month;
        month = heading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeading)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
                child: Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Semantics(
              button: true,
              label: 'Edit ${entry.title}',
              child: InkWell(
                onTap: () => onTap(entry),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 58,
                        child: Column(
                          children: [
                            Text(
                              _weekday(entry.date),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${entry.date.day}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showTimes)
                              Text(
                                _time(entry.createdAt),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              entry.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.note,
                              maxLines: fullEntries ? null : 3,
                              overflow: fullEntries
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                            ),
                            if (showTags && entry.tags.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 6,
                                  children: entry.tags
                                      .map(
                                        (tag) => Chip(
                                          label: Text(tag),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (previewPictures && entry.images.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: _DiaryThumb(
                            path: entry.images.first,
                            size: 66,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}

class _DiaryAttachments extends StatelessWidget {
  const _DiaryAttachments({required this.entries, required this.onTap});
  final List<DiaryEntry> entries;
  final ValueChanged<DiaryEntry> onTap;
  @override
  Widget build(BuildContext context) {
    final media = <(DiaryEntry, Map<String, dynamic>, String)>[
      for (final e in entries)
        for (final image in e.images)
          (e, {'uri': image, 'name': e.title}, 'photo'),
      for (final e in entries)
        for (final audio in e.audioAttachments) (e, audio, 'audio'),
      for (final e in entries)
        for (final file in e.fileAttachments) (e, file, 'file'),
    ];
    if (media.isEmpty) {
      return const _DiaryEmpty(
        icon: CupertinoIcons.paperclip,
        title: 'No attachments',
        message: 'Photos added to entries will appear here.',
      );
    }
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.paddingOf(context).top + 86,
        12,
        100,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
      ),
      itemCount: media.length,
      itemBuilder: (_, i) {
        final item = media[i];
        return GestureDetector(
          onTap: () {
            if (item.$3 == 'photo') {
              onTap(item.$1);
            } else if (item.$3 == 'audio') {
              showModalBottomSheet<void>(
                context: context,
                builder: (_) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 104,
                      child: _AudioAttachmentTile(item: item.$2),
                    ),
                  ),
                ),
              );
            } else {
              _openDiaryFile(item.$2);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.$3 == 'photo')
                _DiaryThumb(path: item.$2['uri']?.toString() ?? '', size: 200)
              else
                ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.$3 == 'audio'
                            ? CupertinoIcons.waveform
                            : CupertinoIcons.doc,
                        size: 34,
                        color: primaryColor,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          item.$2['name']?.toString() ??
                              (item.$3 == 'audio' ? 'Audio recording' : 'File'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned(
                left: 5,
                bottom: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item.$1.date.day}/${item.$1.date.month}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DiaryMapList extends StatelessWidget {
  const _DiaryMapList({required this.entries, required this.onTap});
  final List<DiaryEntry> entries;
  final ValueChanged<DiaryEntry> onTap;
  @override
  Widget build(BuildContext context) => entries.isEmpty
      ? const _DiaryEmpty(
          icon: CupertinoIcons.map,
          title: 'No places yet',
          message: 'Add a location to an entry to see it here.',
        )
      : ListView.builder(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + 86,
            16,
            100,
          ),
          itemCount: entries.length,
          itemBuilder: (_, i) => ListTile(
            leading: CircleAvatar(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              child: const Icon(CupertinoIcons.location),
            ),
            title: Text(entries[i].locationName ?? 'Pinned location'),
            subtitle: Text(
              '${entries[i].title} • ${_shortDate(entries[i].date)}',
            ),
            trailing: const Icon(CupertinoIcons.chevron_right),
            onTap: () => onTap(entries[i]),
          ),
        );
}

class _DiarySearch extends StatefulWidget {
  const _DiarySearch({
    required this.entries,
    required this.search,
    required this.onTap,
  });
  final List<DiaryEntry> entries;
  final TextEditingController search;
  final ValueChanged<DiaryEntry> onTap;
  @override
  State<_DiarySearch> createState() => _DiarySearchState();
}

class _DiarySearchState extends State<_DiarySearch> {
  @override
  void initState() {
    super.initState();
    widget.search.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    widget.search.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.search.text.trim().toLowerCase();
    final found = widget.entries
        .where(
          (e) =>
              '${e.title} ${e.note} ${e.tags.join(' ')} ${e.collections.join(' ')} ${e.locationName ?? ''} ${e.dateKey}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 86,
        16,
        100,
      ),
      children: [
        TextField(
          controller: widget.search,
          autofocus: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(CupertinoIcons.search),
            hintText: 'Search diary',
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: widget.search.clear,
                    icon: const Icon(CupertinoIcons.clear_circled_solid),
                  ),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (found.isEmpty)
          const _DiaryEmpty(
            icon: CupertinoIcons.search,
            title: 'No entries found',
            message: 'Try a heading, tag, place, or date.',
          )
        else
          ...found.map(
            (e) => ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 5),
              leading: e.images.isEmpty
                  ? const Icon(CupertinoIcons.book)
                  : _DiaryThumb(path: e.images.first, size: 52),
              title: Text(e.title),
              subtitle: Text(
                '${_shortDate(e.date)}\n${e.note}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              onTap: () => widget.onTap(e),
            ),
          ),
      ],
    );
  }
}

class _DiaryThumb extends StatelessWidget {
  const _DiaryThumb({required this.path, required this.size});
  final String path;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox.square(
      dimension: size,
      child: path.startsWith('http')
          ? Image.network(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFFE5E5E8),
                child: Icon(CupertinoIcons.photo),
              ),
            )
          : Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFFE5E5E8),
                child: Icon(CupertinoIcons.photo),
              ),
            ),
    ),
  );
}

class _DiaryEmpty extends StatelessWidget {
  const _DiaryEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: primaryColor),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DiarySettingsSheet extends StatefulWidget {
  const _DiarySettingsSheet();
  @override
  State<_DiarySettingsSheet> createState() => _DiarySettingsSheetState();
}

class _DiarySettingsSheetState extends State<_DiarySettingsSheet> {
  late Map<String, dynamic> values;
  @override
  void initState() {
    super.initState();
    values = Map<String, dynamic>.from(
      StorageHelper.getValue<Map>(
            key: StorageKeys.myDiarySettings,
            defaultValue: const {},
          ) ??
          const {},
    );
  }

  bool value(String key, [bool fallback = true]) =>
      values[key] as bool? ?? fallback;
  void setValue(String key, bool enabled) {
    setState(() => values[key] = enabled);
    StorageHelper.setValue(key: StorageKeys.myDiarySettings, value: values);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Center(child: SizedBox(width: 40, child: Divider(thickness: 4))),
        const Text(
          'Diary settings',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        SwitchListTile.adaptive(
          value: Theme.of(context).brightness == Brightness.dark,
          onChanged: (enabled) {
            if (Get.isRegistered<ThemeController>()) {
              Get.find<ThemeController>().setDarkMode(enabled);
            }
            setState(() {});
          },
          secondary: const Icon(CupertinoIcons.circle_lefthalf_fill),
          title: const Text('Dark appearance'),
        ),
        for (final item in const [
          ('entryHeadings', 'Entry headings', CupertinoIcons.text_cursor),
          ('showTimes', 'Show entry times', CupertinoIcons.time),
          ('previewPictures', 'Preview pictures', CupertinoIcons.photo),
          ('showTags', 'Show tags in timeline', CupertinoIcons.tag),
          (
            'fullEntries',
            'Full entries in timeline',
            CupertinoIcons.text_justify,
          ),
        ])
          SwitchListTile.adaptive(
            value: value(item.$1, item.$1 != 'fullEntries'),
            onChanged: (enabled) => setValue(item.$1, enabled),
            secondary: Icon(item.$3),
            title: Text(item.$2),
          ),
      ],
    ),
  );
}

class _DiaryGlassNavigation extends StatelessWidget {
  const _DiaryGlassNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withAlpha(210),
            border: Border(
              top: BorderSide(color: scheme.outlineVariant.withAlpha(120)),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            indicatorColor: primaryColor.withAlpha(28),
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(CupertinoIcons.calendar),
                label: 'Calendar',
              ),
              NavigationDestination(
                icon: Icon(CupertinoIcons.list_bullet),
                label: 'Timeline',
              ),
              NavigationDestination(
                icon: Icon(CupertinoIcons.map),
                label: 'Map',
              ),
              NavigationDestination(
                icon: Icon(CupertinoIcons.paperclip),
                label: 'Attachments',
              ),
              NavigationDestination(
                icon: Icon(CupertinoIcons.search),
                label: 'Search',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _weekday(DateTime d) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
String _time(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String _shortDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

class DiaryEntryDetailScreen extends StatefulWidget {
  final DateTime date;
  final String? entryId;
  final List<String> initialImages;
  final bool createNew;

  const DiaryEntryDetailScreen({
    super.key,
    required this.date,
    this.entryId,
    this.initialImages = const [],
    this.createNew = false,
  });

  @override
  State<DiaryEntryDetailScreen> createState() => _DiaryEntryDetailScreenState();
}

class _DiaryEntryDetailScreenState extends State<DiaryEntryDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _tagController;
  late final TextEditingController _collectionController;
  late final TextEditingController _locationController;
  final List<String> _tags = [];
  final List<String> _collections = [];
  final List<String> _images = [];
  final List<Map<String, dynamic>> _audioAttachments = [];
  final List<Map<String, dynamic>> _fileAttachments = [];
  final AudioRecorder _audioRecorder = AudioRecorder();
  final SpeechToText _speech = SpeechToText();
  bool _isRecordingAudio = false;
  double? _latitude;
  double? _longitude;
  int _rating = 0;
  String? _loadedEntryId;
  late bool _creatingNew;

  MyDiaryController get controller => Get.find<MyDiaryController>();

  @override
  void initState() {
    super.initState();
    _creatingNew = widget.createNew;
    final entry = _selectedEntry();
    _titleController = TextEditingController();
    _noteController = TextEditingController();
    _tagController = TextEditingController();
    _collectionController = TextEditingController();
    _locationController = TextEditingController();
    _loadEntry(entry);
    if (entry == null && widget.initialImages.isNotEmpty) {
      _images.addAll(widget.initialImages);
    }
  }

  DiaryEntry? _selectedEntry() {
    if (_creatingNew) return null;
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
    _collectionController.dispose();
    _locationController.dispose();
    _audioRecorder.dispose();
    _speech.stop();
    super.dispose();
  }

  void _loadEntry(DiaryEntry? entry) {
    if (entry != null) _creatingNew = false;
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
    _audioAttachments
      ..clear()
      ..addAll(entry?.audioAttachments ?? const []);
    _fileAttachments
      ..clear()
      ..addAll(entry?.fileAttachments ?? const []);
    _latitude = entry?.latitude;
    _longitude = entry?.longitude;
    _rating = entry?.rating ?? 0;
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
      return PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _save(silent: true);
        },
        child: Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: _DiaryEditorAppBar(
            date: widget.date,
            time: entry?.createdAt ?? DateTime.now(),
            onBack: () {
              _save(silent: true);
              Navigator.pop(context);
            },
            onPrevious: () => _moveDay(-1),
            onNext: () => _moveDay(1),
            onMenu: () => _showEditorMenu(entry),
          ),
          bottomNavigationBar: _DiaryBottomActionBar(
            onTagTap: _showTagSheet,
            onImageTap: _pickDiaryImages,
            onLocationTap: _showLocationPicker,
            onNewNoteTap: _startNewNote,
            onAudioTap: _toggleAudioRecording,
            onFileTap: _pickFiles,
            isRecordingAudio: _isRecordingAudio,
            hasLocation:
                _locationController.text.trim().isNotEmpty ||
                (_latitude != null && _longitude != null),
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: _buildEditor(),
          ),
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
        210,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 18),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                cursorColor: primaryColor,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.text,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _plainInputDecoration(context, 'Heading'),
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 30,
                  height: 1.35,
                ),
                decoration: _plainInputDecoration(context, 'Text'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_images.isNotEmpty) ...[
          _DiaryImageStrip(images: _images, onRemove: _removeImage),
          const SizedBox(height: 12),
        ],
        if (_audioAttachments.isNotEmpty || _fileAttachments.isNotEmpty) ...[
          _DiaryFileStrip(
            audio: _audioAttachments,
            files: _fileAttachments,
            onRemoveAudio: (item) =>
                setState(() => _audioAttachments.remove(item)),
            onRemoveFile: (item) =>
                setState(() => _fileAttachments.remove(item)),
          ),
          const SizedBox(height: 12),
        ],
        if (_tags.isNotEmpty) ...[
          _EditableTagWrap(tags: _tags, onRemove: _removeTag),
          const SizedBox(height: 10),
        ],
        if (_collections.isNotEmpty) ...[
          _EditableTagWrap(
            tags: _collections,
            icon: CupertinoIcons.collections,
            onRemove: (value) => setState(() => _collections.remove(value)),
          ),
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
        ),
      ],
    );
  }

  InputDecoration _plainInputDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      filled: false,
      fillColor: Colors.transparent,
      hintStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    );
  }

  InputDecoration _darkInputDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withAlpha(18)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
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

  void _showCollectionSheet() {
    _showReusableValueSheet(
      title: 'Add to collection',
      hint: 'Search or Create Collection',
      controller: _collectionController,
      suggestions: controller.allCollections,
      selectedValues: _collections,
      onAdd: (value) => setState(() {
        if (!_collections.any(
          (item) => item.toLowerCase() == value.toLowerCase(),
        )) {
          _collections.add(value);
        }
      }),
    );
  }

  void _moveDay(int days) {
    _save(silent: true);
    final date = widget.date.add(Duration(days: days));
    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(builder: (_) => DiaryEntryDetailScreen(date: date)),
    );
  }

  void _startNewNote() {
    _save(silent: true);
    setState(() {
      _creatingNew = true;
      _loadEntry(null);
    });
  }

  void _showEditorMenu(DiaryEntry? entry) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (menuContext) => CupertinoActionSheet(
        actions: [
          for (final item in const [
            (CupertinoIcons.sparkles, 'Suggestions'),
            (CupertinoIcons.mic, 'Dictate'),
            (CupertinoIcons.time, 'Insert timestamp'),
            (CupertinoIcons.link, 'Link to entry'),
            (CupertinoIcons.share, 'Share'),
            (CupertinoIcons.arrow_up_right_square, 'Export'),
            (CupertinoIcons.arrow_counterclockwise, 'On this day'),
            (CupertinoIcons.calendar_badge_plus, 'Change date/time'),
            (CupertinoIcons.doc_text, 'Select template'),
            (CupertinoIcons.collections, 'Collections'),
          ])
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(menuContext);
                if (item.$2 == 'Collections') {
                  _showCollectionSheet();
                } else if (item.$2 == 'Dictate') {
                  _startDictation();
                } else if (item.$2 == 'Share') {
                  _shareEntry();
                } else if (item.$2 == 'Export') {
                  _exportEntry();
                } else if (item.$2 == 'Suggestions') {
                  _showSuggestions();
                } else if (item.$2 == 'Select template') {
                  _showTemplates();
                } else if (item.$2 == 'On this day') {
                  _showOnThisDay();
                } else if (item.$2 == 'Link to entry') {
                  _showEntryLinks();
                } else if (item.$2 == 'Change date/time') {
                  _changeDate();
                } else if (item.$2 == 'Insert timestamp') {
                  final stamp = _time(DateTime.now());
                  final text = _noteController.text;
                  _noteController.text =
                      '$text${text.isEmpty ? '' : '\n'}$stamp ';
                  _noteController.selection = TextSelection.collapsed(
                    offset: _noteController.text.length,
                  );
                } else {
                  _showMessage('${item.$2} is not available yet.');
                }
              },
              child: Row(
                children: [
                  Icon(item.$1),
                  const SizedBox(width: 14),
                  Text(item.$2),
                ],
              ),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              _save();
              Navigator.pop(menuContext);
            },
            child: const Text('Save'),
          ),
          if (entry != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(menuContext);
                _confirmDelete(context, entry);
              },
              child: const Text('Delete'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(menuContext),
          child: const Text('Cancel'),
        ),
      ),
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
              _useCurrentLocation();
            },
            child: const Text('Use current location'),
          ),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
              Text(
                'Location name',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                autofocus: true,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: _darkInputDecoration(
                  context,
                  'Temple, home, city...',
                ),
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

  Future<void> _toggleAudioRecording() async {
    if (_isRecordingAudio) {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() {
        _isRecordingAudio = false;
        if (path != null && path.isNotEmpty) {
          _audioAttachments.add({
            'uri': path,
            'name':
                'Recording ${_shortDate(DateTime.now())} ${_time(DateTime.now())}',
            'mime_type': 'audio/mp4',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      });
      return;
    }
    if (!await _audioRecorder.hasPermission()) {
      _showMessage('Microphone permission is required to record audio.');
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}${Platform.pathSeparator}diary_audio_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    if (mounted) setState(() => _isRecordingAudio = true);
  }

  String get _entryShareText =>
      '${_titleController.text.trim()}\n${_formatDetailDate(widget.date)}\n\n${_noteController.text.trim()}${_tags.isEmpty ? '' : '\n\n${_tags.map((tag) => '#$tag').join(' ')}'}';

  Future<void> _shareEntry() async {
    await SharePlus.instance.share(
      ShareParams(
        text: _entryShareText,
        subject: _titleController.text.trim().isEmpty
            ? 'Diary entry'
            : _titleController.text.trim(),
      ),
    );
  }

  Future<void> _exportEntry() async {
    final directory = await getTemporaryDirectory();
    final safeName =
        (_titleController.text.trim().isEmpty
                ? 'diary-entry'
                : _titleController.text.trim())
            .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-');
    final file = File(
      '${directory.path}${Platform.pathSeparator}$safeName.txt',
    );
    await file.writeAsString(_entryShareText, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'Export diary entry'),
    );
  }

  Future<void> _startDictation() async {
    final available = await _speech.initialize();
    if (!available || !mounted) {
      _showMessage(
        'Speech recognition is unavailable or permission was denied.',
      );
      return;
    }
    var transcript = '';
    await _speech.listen(
      onResult: (result) => transcript = result.recognizedWords,
    );
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Dictating…'),
        content: const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('Speak naturally, then tap Insert.'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              _speech.stop();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              await _speech.stop();
              if (transcript.trim().isNotEmpty) {
                final current = _noteController.text;
                _noteController.text =
                    '$current${current.isEmpty ? '' : ' '}${transcript.trim()}';
                _noteController.selection = TextSelection.collapsed(
                  offset: _noteController.text.length,
                );
                setState(() {});
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  void _showSuggestions() => _showInsertChoices('Suggestions', const [
    'What made today meaningful?',
    'What are you grateful for?',
    'Describe one moment you want to remember.',
    'What did you learn today?',
  ]);

  void _showTemplates() => _showInsertChoices('Select template', const [
    'Gratitude\n\nToday I am grateful for…\n\nA moment I want to remember…',
    'Daily reflection\n\nToday’s highlight…\n\nWhat I learned…\n\nTomorrow I will…',
    'Travel memory\n\nPlace…\n\nPeople…\n\nWhat happened…\n\nHow it felt…',
  ]);

  void _showInsertChoices(String title, List<String> values) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final value in values)
            CupertinoActionSheetAction(
              onPressed: () {
                final current = _noteController.text;
                _noteController.text =
                    '$current${current.isEmpty ? '' : '\n\n'}$value';
                _noteController.selection = TextSelection.collapsed(
                  offset: _noteController.text.length,
                );
                setState(() {});
                Navigator.pop(sheetContext);
              },
              child: Text(value.split('\n').first),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showOnThisDay() {
    final matches = controller.entries
        .where(
          (entry) =>
              entry.id != _loadedEntryId &&
              entry.date.month == widget.date.month &&
              entry.date.day == widget.date.day,
        )
        .toList();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('On this day'),
        message: matches.isEmpty
            ? const Text('No entries from this date in earlier years.')
            : null,
        actions: [
          for (final entry in matches)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => DiaryEntryDetailScreen(
                      date: entry.date,
                      entryId: entry.id,
                    ),
                  ),
                );
              },
              child: Text('${entry.date.year} — ${entry.title}'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Close'),
        ),
      ),
    );
  }

  void _showEntryLinks() {
    final entries = controller.entries
        .where((entry) => entry.id != _loadedEntryId)
        .take(20)
        .toList();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Link to entry'),
        message: entries.isEmpty
            ? const Text('No other entries are available.')
            : null,
        actions: [
          for (final entry in entries)
            CupertinoActionSheetAction(
              onPressed: () {
                final current = _noteController.text;
                _noteController.text =
                    '$current${current.isEmpty ? '' : '\n'}[[${entry.id}|${entry.title}]]';
                _noteController.selection = TextSelection.collapsed(
                  offset: _noteController.text.length,
                );
                setState(() {});
                Navigator.pop(sheetContext);
              },
              child: Text('${_shortDate(entry.date)} — ${entry.title}'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showMessage('Location services are turned off.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage(
        permission == LocationPermission.deniedForever
            ? 'Location permission is permanently denied. Enable it in device settings.'
            : 'Location permission was denied.',
      );
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        if (_locationController.text.trim().isEmpty) {
          _locationController.text = 'Current location';
        }
      });
    } catch (_) {
      _showMessage('Current location could not be determined.');
    }
  }

  Future<void> _changeDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: widget.date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (selected == null || !mounted) return;
    await controller.saveEntry(
      date: selected,
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
      rating: _rating,
      audioAttachments: _audioAttachments,
      fileAttachments: _fileAttachments,
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(
        builder: (_) =>
            DiaryEntryDetailScreen(date: selected, entryId: _loadedEntryId),
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null || !mounted) return;
    setState(() {
      for (final file in result.files) {
        final path = file.path;
        if (path == null ||
            _fileAttachments.any((item) => item['uri'] == path)) {
          continue;
        }
        _fileAttachments.add({
          'uri': path,
          'name': file.name,
          'size': file.size,
          'extension': file.extension,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  void _save({bool silent = false}) {
    if (_noteController.text.trim().isEmpty) {
      if (!silent) _showMessage('Please write something before saving.');
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
      rating: _rating,
      audioAttachments: _audioAttachments,
      fileAttachments: _fileAttachments,
    );
    _loadedEntryId = controller.entriesForDate(widget.date).firstOrNull?.id;
    _creatingNew = false;
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
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
                      scheme.surface.withAlpha(isDark ? 238 : 230),
                      scheme.surface.withAlpha(isDark ? 198 : 180),
                      scheme.surface.withAlpha(isDark ? 95 : 75),
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
          leading: FrostedAppBarIconButton(
            icon: leading,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onLeadingTap,
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
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

class _DiaryEditorAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _DiaryEditorAppBar({
    required this.date,
    required this.time,
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onMenu,
  });

  final DateTime date;
  final DateTime time;
  final VoidCallback onBack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onMenu;

  @override
  Size get preferredSize => const Size.fromHeight(82);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        child: Row(
          children: [
            _GlassControlButton(
              icon: CupertinoIcons.chevron_left,
              tooltip: 'Back',
              onTap: onBack,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDetailDate(date),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _time(time),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _GlassControlGroup(
              children: [
                _GlassControlButton(
                  icon: CupertinoIcons.chevron_left,
                  tooltip: 'Previous day',
                  onTap: onPrevious,
                  bare: true,
                ),
                _GlassControlButton(
                  icon: CupertinoIcons.chevron_right,
                  tooltip: 'Next day',
                  onTap: onNext,
                  bare: true,
                ),
                _GlassControlButton(
                  icon: CupertinoIcons.ellipsis,
                  tooltip: 'Entry options',
                  onTap: onMenu,
                  bare: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassControlGroup extends StatelessWidget {
  const _GlassControlGroup({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer.withAlpha(205),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withAlpha(120),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  );
}

class _GlassControlButton extends StatelessWidget {
  const _GlassControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.bare = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool bare;
  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    );
    if (bare) return button;
    return _GlassControlGroup(children: [button]);
  }
}

class _DiaryBottomActionBar extends StatelessWidget {
  final VoidCallback onTagTap;
  final VoidCallback onImageTap;
  final VoidCallback onLocationTap;
  final VoidCallback onNewNoteTap;
  final VoidCallback onAudioTap;
  final VoidCallback onFileTap;
  final bool isRecordingAudio;
  final bool hasLocation;

  const _DiaryBottomActionBar({
    required this.onTagTap,
    required this.onImageTap,
    required this.onLocationTap,
    required this.onNewNoteTap,
    required this.onAudioTap,
    required this.onFileTap,
    required this.isRecordingAudio,
    required this.hasLocation,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            color: scheme.surface.withAlpha(220),
            border: Border(
              top: BorderSide(color: scheme.outlineVariant.withAlpha(120)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DiaryAction(
                      icon: CupertinoIcons.photo,
                      label: 'Add photo',
                      onTap: onImageTap,
                    ),
                  ),
                  Expanded(
                    child: _DiaryAction(
                      icon: CupertinoIcons.tag,
                      label: 'Add tags',
                      onTap: onTagTap,
                    ),
                  ),
                  Expanded(
                    child: _DiaryAction(
                      icon: CupertinoIcons.add_circled,
                      label: 'New note',
                      onTap: onNewNoteTap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DiaryAction(
                      icon: isRecordingAudio
                          ? CupertinoIcons.stop_circle_fill
                          : CupertinoIcons.mic,
                      label: isRecordingAudio ? 'Stop recording' : 'Add audio',
                      onTap: onAudioTap,
                    ),
                  ),
                  Expanded(
                    child: _DiaryAction(
                      icon: CupertinoIcons.doc,
                      label: 'Add file',
                      onTap: onFileTap,
                    ),
                  ),
                  Expanded(
                    child: _DiaryAction(
                      icon: hasLocation
                          ? CupertinoIcons.location_fill
                          : CupertinoIcons.location,
                      label: 'Add location',
                      onTap: onLocationTap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiaryAction extends StatelessWidget {
  const _DiaryAction({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    enabled: onTap != null,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Icon(
              icon,
              size: 27,
              color: onTap == null
                  ? Theme.of(context).disabledColor
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: onTap == null
                    ? Theme.of(context).disabledColor
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
        color: Theme.of(context).colorScheme.surfaceContainer.withAlpha(235),
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _DiaryFileStrip extends StatelessWidget {
  const _DiaryFileStrip({
    required this.audio,
    required this.files,
    required this.onRemoveAudio,
    required this.onRemoveFile,
  });
  final List<Map<String, dynamic>> audio;
  final List<Map<String, dynamic>> files;
  final ValueChanged<Map<String, dynamic>> onRemoveAudio;
  final ValueChanged<Map<String, dynamic>> onRemoveFile;

  @override
  Widget build(BuildContext context) {
    final items = <(Map<String, dynamic>, bool)>[
      for (final item in audio) (item, true),
      for (final item in files) (item, false),
    ];
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final item = items[index];
          return SizedBox(
            width: 280,
            child: item.$2
                ? _AudioAttachmentTile(
                    item: item.$1,
                    onRemove: () => onRemoveAudio(item.$1),
                  )
                : _FileAttachmentTile(
                    item: item.$1,
                    onRemove: () => onRemoveFile(item.$1),
                  ),
          );
        },
      ),
    );
  }
}

class _AudioAttachmentTile extends StatefulWidget {
  const _AudioAttachmentTile({required this.item, this.onRemove});
  final Map<String, dynamic> item;
  final VoidCallback? onRemove;
  @override
  State<_AudioAttachmentTile> createState() => _AudioAttachmentTileState();
}

class _AudioAttachmentTileState extends State<_AudioAttachmentTile> {
  final AudioPlayer player = AudioPlayer();
  bool loading = false;
  bool loaded = false;
  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (!loaded) {
        setState(() => loading = true);
        final source = widget.item['uri']?.toString() ?? '';
        if (source.startsWith('http')) {
          await player.setUrl(source);
        } else {
          await player.setFilePath(source);
        }
        loaded = true;
      }
      if (player.playing) {
        await player.pause();
      } else {
        if (player.processingState == ProcessingState.completed) {
          await player.seek(Duration.zero);
        }
        player.play();
      }
    } catch (_) {
      if (mounted) {
        TopNotification.show(
          title: 'Audio',
          message: 'This recording is unavailable on this device.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (_, snapshot) => IconButton.filled(
              tooltip: player.playing ? 'Pause recording' : 'Play recording',
              style: IconButton.styleFrom(backgroundColor: primaryColor),
              onPressed: loading ? null : _toggle,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      player.playing
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item['name']?.toString() ?? 'Audio recording',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (_, snap) {
                    final position = snap.data ?? Duration.zero;
                    final total = player.duration ?? Duration.zero;
                    final progress = total.inMilliseconds == 0
                        ? 0.0
                        : (position.inMilliseconds / total.inMilliseconds)
                              .clamp(0.0, 1.0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          color: primaryColor,
                          backgroundColor: scheme.outlineVariant,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_durationLabel(position)} / ${_durationLabel(total)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (widget.onRemove != null)
            IconButton(
              tooltip: 'Remove recording',
              onPressed: widget.onRemove,
              icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 20),
            ),
        ],
      ),
    );
  }
}

class _FileAttachmentTile extends StatelessWidget {
  const _FileAttachmentTile({required this.item, this.onRemove});
  final Map<String, dynamic> item;
  final VoidCallback? onRemove;
  Future<void> _open() async {
    await _openDiaryFile(item);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final extension = item['extension']?.toString().toUpperCase() ?? 'FILE';
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.doc_fill, color: primaryColor),
                    Text(
                      extension,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 9,
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name']?.toString() ?? 'Attachment',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _fileSize(item['size']),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tap to open',
                      style: TextStyle(fontSize: 10, color: primaryColor),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remove file',
                  onPressed: onRemove,
                  icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 20),
                )
              else
                const Icon(CupertinoIcons.arrow_up_right_square),
            ],
          ),
        ),
      ),
    );
  }
}

String _durationLabel(Duration value) =>
    '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
Future<void> _openDiaryFile(Map<String, dynamic> item) async {
  final uri = item['uri']?.toString() ?? '';
  if (uri.startsWith('http')) {
    final opened = await launchUrl(
      Uri.parse(uri),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      TopNotification.show(
        title: 'Attachment',
        message: 'The file could not be opened.',
      );
    }
  } else {
    final result = await OpenFilex.open(uri);
    if (result.type != ResultType.done) {
      TopNotification.show(title: 'Attachment', message: result.message);
    }
  }
}

String _fileSize(dynamic value) {
  final bytes = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 0;
  if (bytes <= 0) return 'File';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _DateNotesList extends StatelessWidget {
  final List<DiaryEntry> entries;
  final String? selectedId;
  final ValueChanged<DiaryEntry> onTap;

  const _DateNotesList({
    required this.entries,
    required this.selectedId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Notes on this date',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
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
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
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
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              entry.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
              color: Theme.of(context).colorScheme.surface.withAlpha(248),
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
        color: Theme.of(context).colorScheme.surfaceContainer.withAlpha(230),
        border: Border(bottom: BorderSide(color: primaryColor.withAlpha(16))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
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
                    Text(
                      'Select Photos',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              color: Theme.of(context).colorScheme.surface.withAlpha(246),
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
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
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
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withAlpha(18)
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHigh.withAlpha(240),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          color: isSelected
              ? primaryColor
              : Theme.of(context).colorScheme.surfaceContainerHigh,
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
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${date.day}',
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  final int entryCount;
  final VoidCallback onTap;

  const _CalendarDateCell({
    required this.date,
    required this.entry,
    required this.entryCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDate(date, DateTime.now());
    final diarySettings =
        StorageHelper.getValue<Map>(
          key: StorageKeys.myDiarySettings,
          defaultValue: const {},
        ) ??
        const {};
    final showPicture =
        (diarySettings['previewPictures'] as bool? ?? true) &&
        entry?.images.isNotEmpty == true;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: entry == null
              ? Theme.of(context).colorScheme.surfaceContainer
              : primaryColor.withAlpha(28),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isToday
                ? primaryColor
                : entry == null
                ? Theme.of(context).colorScheme.outlineVariant
                : primaryColor.withAlpha(80),
            width: isToday ? 1.4 : 1,
          ),
        ),
        child: Stack(
          children: [
            if (showPicture)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: entry!.images.first.startsWith('http')
                      ? NetworkImageWithLoader(
                          imageUrl: entry!.images.first,
                          title: entry!.title,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(entry!.images.first),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            if (showPicture)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black.withAlpha(22)),
                ),
              ),
            Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: showPicture
                      ? Colors.white
                      : isToday || entry != null
                      ? primaryColor
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (entryCount > 1)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$entryCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
  final IconData icon;

  const _EditableTagWrap({
    required this.tags,
    required this.onRemove,
    this.icon = CupertinoIcons.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          GestureDetector(
            onTap: () => onRemove(tag),
            child: _MetaChip(icon: icon, label: '$tag  ×'),
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
