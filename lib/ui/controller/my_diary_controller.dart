import 'package:get/get.dart';
import 'package:harismruti/api/repositories/diary_repository.dart';
import 'package:harismruti/services/analytics_service.dart';
import 'package:harismruti/utils/storage_helper.dart';

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.note,
    required this.tags,
    required this.collections,
    required this.images,
    required this.createdAt,
    required this.updatedAt,
    this.rating = 0,
    this.audioAttachments = const [],
    this.fileAttachments = const [],
    this.locationName,
    this.latitude,
    this.longitude,
  });

  final String id;
  final DateTime date;
  final String title;
  final String note;
  final List<String> tags;
  final List<String> collections;
  final List<String> images;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int rating;
  final List<Map<String, dynamic>> audioAttachments;
  final List<Map<String, dynamic>> fileAttachments;

  String get dateKey => MyDiaryController.dateKeyFor(date);
  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': MyDiaryController.dateKeyFor(date),
    'title': title,
    'note': note,
    'tags': tags,
    'collections': collections,
    'images': images,
    'location_name': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'rating': rating,
    'audio_attachments': audioAttachments,
    'file_attachments': fileAttachments,
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now();
    final date = _readDate(json) ?? createdAt;
    return DiaryEntry(
      id: json['id']?.toString() ?? MyDiaryController.dateKeyFor(date),
      date: _dateOnly(date),
      title: json['title']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      tags:
          (json['tags'] as List?)
              ?.map((tag) => tag.toString())
              .where(
                (tag) =>
                    tag.trim().isNotEmpty && tag.trim().toLowerCase() != 'null',
              )
              .toList() ??
          const [],
      collections:
          (json['collections'] as List?)
              ?.map((collection) => collection.toString())
              .where((collection) => collection.trim().isNotEmpty)
              .toList() ??
          const [],
      images:
          (json['images'] as List?)
              ?.map((image) => image.toString())
              .where((image) => image.trim().isNotEmpty)
              .toList() ??
          const [],
      locationName: json['location_name']?.toString(),
      latitude: _readDouble(json['latitude']),
      longitude: _readDouble(json['longitude']),
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? createdAt,
      rating: (json['rating'] as num?)?.toInt().clamp(0, 5) ?? 0,
      audioAttachments: _readAttachments(json['audio_attachments']),
      fileAttachments: _readAttachments(json['file_attachments']),
    );
  }

  DiaryEntry copyWith({
    DateTime? date,
    String? title,
    String? note,
    List<String>? tags,
    List<String>? collections,
    List<String>? images,
    String? locationName,
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
    int? rating,
    List<Map<String, dynamic>>? audioAttachments,
    List<Map<String, dynamic>>? fileAttachments,
    bool clearLocation = false,
  }) {
    return DiaryEntry(
      id: id,
      date: date ?? this.date,
      title: title ?? this.title,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      collections: collections ?? this.collections,
      images: images ?? this.images,
      locationName: clearLocation ? null : locationName ?? this.locationName,
      latitude: clearLocation ? null : latitude ?? this.latitude,
      longitude: clearLocation ? null : longitude ?? this.longitude,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      audioAttachments: audioAttachments ?? this.audioAttachments,
      fileAttachments: fileAttachments ?? this.fileAttachments,
    );
  }

  static DateTime? _readDate(Map<String, dynamic> json) {
    final rawDate = json['date']?.toString();
    final parsedDate = _parseLocalDate(rawDate);
    if (parsedDate != null) return parsedDate;
    return _parseLocalDate(json['created_at']?.toString()) ??
        _parseLocalDate(json['updated_at']?.toString());
  }

  // Parses a date that may come back either as a bare "YYYY-MM-DD" (unambiguous,
  // use as-is) or as a full timestamp with a UTC/offset marker (must convert to
  // local time first, otherwise the calendar date can shift by a day).
  static DateTime? _parseLocalDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (!raw.contains('T') && !raw.contains(' ')) {
      final parts = raw.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          return DateTime(year, month, day);
        }
      }
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  static double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static List<Map<String, dynamic>> _readAttachments(dynamic value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
}

class MyDiaryController extends GetxController {
  MyDiaryController({DiaryRepository? repository})
    : _repository = repository ?? const DiaryRepository();

  final DiaryRepository _repository;
  final RxList<DiaryEntry> entries = <DiaryEntry>[].obs;
  final Rx<DateTime> selectedDate = _dateOnly(DateTime.now()).obs;
  final RxBool isSyncing = false.obs;

  DiaryEntry? get latestEntry => entries.isEmpty ? null : entries.first;
  DiaryEntry? get selectedEntry => entryForDate(selectedDate.value);
  List<String> get allTags =>
      _uniqueSorted(entries.expand((entry) => entry.tags));
  List<String> get allCollections =>
      _uniqueSorted(entries.expand((entry) => entry.collections));

  @override
  void onInit() {
    super.onInit();
    loadEntries();
  }

  static String dateKeyFor(DateTime date) {
    final value = _dateOnly(date);
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  List<DateTime> currentWeekDates() {
    final today = _dateOnly(DateTime.now());
    final start = today.subtract(Duration(days: today.weekday % 7));
    return List.generate(7, (index) => start.add(Duration(days: index)));
  }

  List<DateTime?> monthCalendarDates(DateTime month) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmptyCells = first.weekday % 7;
    final cells = <DateTime?>[
      for (var i = 0; i < leadingEmptyCells; i++) null,
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(month.year, month.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  void selectDate(DateTime date) {
    selectedDate.value = _dateOnly(date);
  }

  DiaryEntry? entryForDate(DateTime date) {
    return entriesForDate(date).firstOrNull;
  }

  List<DiaryEntry> entriesForDate(DateTime date) {
    final key = dateKeyFor(date);
    return entries.where((entry) => entry.dateKey == key).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  bool hasEntryForDate(DateTime date) => entryForDate(date) != null;

  Future<void> loadEntries() async {
    if (!StorageHelper.isLogin()) {
      entries.clear();
      return;
    }
    final localEntries = _loadLocalEntries();
    if (localEntries.isNotEmpty) {
      entries.assignAll(localEntries);
    }
    isSyncing.value = true;
    try {
      final remoteEntries = await _repository.getEntries();
      remoteEntries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      entries.assignAll(remoteEntries);
      _persist();
    } catch (_) {
      if (localEntries.isEmpty) entries.assignAll(localEntries);
    } finally {
      isSyncing.value = false;
    }
  }

  List<DiaryEntry> _loadLocalEntries() {
    final raw = StorageHelper.getValue<List>(
      key: StorageKeys.myDiaryEntries,
      defaultValue: const [],
    );
    return (raw ?? const [])
        .whereType<Map>()
        .map((item) => DiaryEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveEntry({
    required DateTime date,
    required String title,
    required String note,
    required List<String> tags,
    required List<String> collections,
    required List<String> images,
    String? id,
    String? locationName,
    double? latitude,
    double? longitude,
    int rating = 0,
    List<Map<String, dynamic>> audioAttachments = const [],
    List<Map<String, dynamic>> fileAttachments = const [],
  }) async {
    final cleanTitle = title.trim().isEmpty ? 'Untitled Diary' : title.trim();
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) return;

    final now = DateTime.now();
    final entryDate = _dateOnly(date);
    final existingIndex = id == null
        ? -1
        : entries.indexWhere((entry) => entry.id == id);
    final cleanTags = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    final cleanCollections = collections
        .map((collection) => collection.trim())
        .where((collection) => collection.isNotEmpty)
        .toSet()
        .toList();
    final cleanImages = images
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toSet()
        .toList();

    late DiaryEntry entry;
    if (existingIndex == -1) {
      entry = DiaryEntry(
        id: id ?? now.microsecondsSinceEpoch.toString(),
        date: entryDate,
        title: cleanTitle,
        note: cleanNote,
        tags: cleanTags,
        collections: cleanCollections,
        images: cleanImages,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        createdAt: now,
        updatedAt: now,
        rating: rating.clamp(0, 5),
        audioAttachments: audioAttachments,
        fileAttachments: fileAttachments,
      );
      entries.insert(0, entry);
    } else {
      entry = entries[existingIndex].copyWith(
        date: entryDate,
        title: cleanTitle,
        note: cleanNote,
        tags: cleanTags,
        collections: cleanCollections,
        images: cleanImages,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        clearLocation: latitude == null || longitude == null,
        updatedAt: now,
        rating: rating.clamp(0, 5),
        audioAttachments: audioAttachments,
        fileAttachments: fileAttachments,
      );
      entries[existingIndex] = entry;
    }
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _persist();
    AnalyticsService.instance.track(
      existingIndex == -1 ? 'Diary Entry Created' : 'Diary Entry Updated',
      properties: {
        'tag_count': cleanTags.length,
        'collection_count': cleanCollections.length,
        'image_count': cleanImages.length,
        'has_location': latitude != null && longitude != null,
        'note_length': cleanNote.length,
      },
    );
    try {
      final saved = await _repository.saveEntry(entry);
      if (saved != null) {
        final index = entries.indexWhere((item) => item.id == saved.id);
        if (index == -1) {
          entries.insert(0, saved);
        } else {
          entries[index] = saved;
        }
        entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _persist();
      }
    } catch (_) {}
  }

  Future<void> deleteEntry(String id) async {
    final entry = entries.firstWhereOrNull((entry) => entry.id == id);
    entries.removeWhere((entry) => entry.id == id);
    _persist();
    AnalyticsService.instance.track('Diary Entry Deleted');
    if (entry == null) return;
    try {
      await _repository.deleteEntry(entry.id);
    } catch (_) {}
  }

  void _persist() {
    StorageHelper.setValue(
      key: StorageKeys.myDiaryEntries,
      value: entries.map((entry) => entry.toJson()).toList(),
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

List<String> _uniqueSorted(Iterable<String> values) {
  final unique = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  unique.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return unique;
}
