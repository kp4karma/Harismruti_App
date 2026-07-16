import 'package:harismruti/api/api_endpoints.dart';

String? _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }
  return null;
}

int? _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
  }
  return null;
}

double? _readDouble(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
  }
  return null;
}

List<String> _readTags(Map<String, dynamic> json) {
  final tags = <String>[];

  void add(dynamic value) {
    if (value == null) return;
    if (value is Map) {
      add(value['name'] ?? value['tag'] ?? value['label'] ?? value['value']);
      return;
    }
    final text = value.toString().trim();
    if (text.isNotEmpty && text != 'null') tags.add(text);
  }

  for (final key in const ['tags', 'tag', 'labels', 'keywords']) {
    final value = json[key];
    if (value is List) {
      for (final item in value) {
        add(item);
      }
    } else if (value is String) {
      for (final item in value.split(',')) {
        add(item);
      }
    } else {
      add(value);
    }
  }

  final unique = <String, String>{};
  for (final tag in tags) {
    unique.putIfAbsent(tag.toLowerCase(), () => tag);
  }
  return unique.values.toList();
}

int _photoSortValue(GalleryPhoto photo) {
  return photo.takenAt?.millisecondsSinceEpoch ?? photo.id;
}

List<GalleryPhoto> _newestPhotosFirst(Iterable<GalleryPhoto> photos) {
  final sorted = photos.toList();
  sorted.sort((a, b) {
    final valueCompare = _photoSortValue(b).compareTo(_photoSortValue(a));
    if (valueCompare != 0) return valueCompare;
    return b.id.compareTo(a.id);
  });
  return sorted;
}

List<dynamic> _readList(dynamic source, List<String> keys) {
  if (source is List) return source;
  if (source is Map) {
    for (final key in keys) {
      final value = source[key];
      if (value is List) return value;
      if (value is Map && value['items'] is List) return value['items'];
    }
  }
  return const [];
}

Map<String, dynamic> asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

class GalleryPhoto {
  final int id;
  final String thumbnailUrl;
  final String fullUrl;
  final String? title;
  final String? subtitle;
  final DateTime? takenAt;
  final int? width;
  final int? height;
  final int? fileSizeBytes;
  final String? fileSizeLabel;
  final double? latitude;
  final double? longitude;
  final List<String> tags;

  const GalleryPhoto({
    required this.id,
    required this.thumbnailUrl,
    required this.fullUrl,
    this.title,
    this.subtitle,
    this.takenAt,
    this.width,
    this.height,
    this.fileSizeBytes,
    this.fileSizeLabel,
    this.latitude,
    this.longitude,
    this.tags = const [],
  });

  factory GalleryPhoto.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    final id = _readInt(json, const ['id', 'photo_id', 'photoId']) ?? 0;
    final thumb = _readString(json, const [
      'thumbnail_url',
      'thumbnailUrl',
      'thumbnail',
      'thumb_url',
      'thumbUrl',
      'url',
      'image',
    ]);
    final full = _readString(json, const [
      'full_url',
      'fullUrl',
      'full',
      'image_url',
      'imageUrl',
      'url',
      'image',
    ]);

    return GalleryPhoto(
      id: id,
      thumbnailUrl: _absoluteUrl(thumb, id, fullSize: false),
      fullUrl: _absoluteUrl(full, id, fullSize: true),
      title: _readString(json, const ['title', 'name', 'caption']),
      subtitle: _readString(json, const ['subtitle', 'taken_at', 'date']),
      takenAt: DateTime.tryParse(
        _readString(json, const [
              'taken_at',
              'inferred_date',
              'event_date',
              'created_at',
              'date',
            ]) ??
            '',
      ),
      width: _readInt(json, const ['width', 'image_width', 'imageWidth', 'w']),
      height: _readInt(json, const [
        'height',
        'image_height',
        'imageHeight',
        'h',
      ]),
      fileSizeBytes: _readInt(json, const [
        'file_size',
        'fileSize',
        'file_size_bytes',
        'fileSizeBytes',
        'size_bytes',
        'sizeBytes',
        'bytes',
      ]),
      fileSizeLabel: _readString(json, const [
        'file_size_label',
        'fileSizeLabel',
        'size_label',
        'sizeLabel',
      ]),
      latitude: _readDouble(json, const [
        'latitude',
        'lat',
        'gps_latitude',
        'gpsLatitude',
      ]),
      longitude: _readDouble(json, const [
        'longitude',
        'lng',
        'lon',
        'long',
        'gps_longitude',
        'gpsLongitude',
      ]),
      tags: _readTags(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'thumbnail_url': thumbnailUrl,
      'full_url': fullUrl,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (takenAt != null) 'taken_at': takenAt!.toIso8601String(),
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (fileSizeLabel != null) 'file_size_label': fileSizeLabel,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (tags.isNotEmpty) 'tags': tags,
    };
  }

  static String _absoluteUrl(String? value, int id, {required bool fullSize}) {
    if (value != null && value.startsWith('http')) return value;
    if (value != null && value.startsWith('/')) {
      final base = Uri.parse(ApiEndpoints.mainDomain);
      final origin =
          '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
      return value.startsWith('/api/')
          ? '$origin$value'
          : '${ApiEndpoints.mainDomain}$value';
    }
    if (id > 0) {
      return fullSize
          ? ApiEndpoints.photoFull(id)
          : ApiEndpoints.photoThumbnail(id);
    }
    return value ?? '';
  }
}

class GalleryCard {
  final int id;
  final String title;
  final String subtitle;
  final String type;
  final String value;
  final int? count;
  final int? locationCount;
  final int? tagCount;
  final int? faceId;
  final List<GalleryPhoto> photos;

  const GalleryCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.value,
    this.count,
    this.locationCount,
    this.tagCount,
    this.faceId,
    this.photos = const [],
  });

  factory GalleryCard.fromJson(dynamic raw, {String fallbackType = 'card'}) {
    final json = asJsonMap(raw);
    final id =
        _readInt(json, const ['id', 'group_id', 'person_group_id', 'year']) ??
        0;
    final title =
        _readString(json, const [
          'title',
          'name',
          'value',
          'label',
          'year',
          'location',
          'album',
          'person',
        ]) ??
        'Smruti';
    final count = _readInt(json, const [
      'count',
      'photo_count',
      'photos_count',
      'total',
    ]);
    final samplePhotos =
        _readList(json, const [
              'photos',
              'items',
              'sample_photos',
              'samples',
              'images',
              'thumbnails',
            ])
            .map(GalleryPhoto.fromJson)
            .where((photo) => photo.thumbnailUrl.isNotEmpty)
            .toList();

    return GalleryCard(
      id: id,
      title: title,
      subtitle:
          _readString(json, const ['subtitle', 'description']) ??
          (count == null ? '' : '$count Photos'),
      type:
          _readString(json, const ['type', 'slug', 'category']) ?? fallbackType,
      value:
          _readString(json, const ['value', 'name', 'title', 'year']) ?? title,
      count: count,
      locationCount: _readInt(json, const [
        'location_count',
        'locations_count',
        'locationCount',
        'locationsCount',
        'city_count',
        'cities_count',
      ]),
      tagCount: _readInt(json, const [
        'tag_count',
        'tags_count',
        'tagCount',
        'tagsCount',
        'attribute_count',
        'attributes_count',
      ]),
      faceId: _readInt(json, const [
        'face_id',
        'representative_face_id',
        'cover_face_id',
      ]),
      photos: _newestPhotosFirst(samplePhotos),
    );
  }

  String get coverUrl {
    if (faceId != null && faceId! > 0 && photos.isEmpty) {
      return ApiEndpoints.faceThumbnail(faceId!);
    }
    if (photos.isEmpty) return '';
    return photos.first.thumbnailUrl;
  }

  List<String> get imageUrls => photos
      .map((photo) => photo.thumbnailUrl)
      .where((url) => url.isNotEmpty)
      .toList();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'type': type,
      'value': value,
      if (count != null) 'count': count,
      if (locationCount != null) 'location_count': locationCount,
      if (tagCount != null) 'tag_count': tagCount,
      if (faceId != null) 'face_id': faceId,
      'photos': photos.map((photo) => photo.toJson()).toList(),
    };
  }
}

class GalleryPage<T> {
  final List<T> items;
  final int page;
  final int perPage;
  final int total;
  final bool hasMore;

  const GalleryPage({
    required this.items,
    this.page = 1,
    this.perPage = 0,
    this.total = 0,
    this.hasMore = false,
  });

  factory GalleryPage.fromJson(dynamic raw, T Function(dynamic raw) parser) {
    final json = asJsonMap(raw);
    final list = _readList(raw, const [
      'items',
      'data',
      'results',
      'photos',
      'people',
      'collections',
    ]);
    final items = list.map(parser).toList();

    return GalleryPage<T>(
      items: items,
      page: _readInt(json, const ['page']) ?? 1,
      perPage:
          _readInt(json, const ['per_page', 'perPage', 'limit']) ??
          items.length,
      total: _readInt(json, const ['total', 'count']) ?? items.length,
      hasMore: json['has_more'] == true || json['hasMore'] == true,
    );
  }
}

class GalleryPhotoAttributes {
  final int photoId;
  final String? country;
  final String? location;
  final String? subLocation;
  final String? album;
  final String? subject;
  final String? withPeople;
  final String? person;
  final double? latitude;
  final double? longitude;

  const GalleryPhotoAttributes({
    required this.photoId,
    this.country,
    this.location,
    this.subLocation,
    this.album,
    this.subject,
    this.withPeople,
    this.person,
    this.latitude,
    this.longitude,
  });

  factory GalleryPhotoAttributes.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    return GalleryPhotoAttributes(
      photoId: _readInt(json, const ['photo_id', 'photoId', 'id']) ?? 0,
      country: _readString(json, const ['country']),
      location: _readString(json, const ['location', 'city']),
      subLocation: _readString(json, const ['sub_location', 'subLocation']),
      album: _readString(json, const ['album']),
      subject: _readString(json, const ['subject']),
      withPeople: _readString(json, const ['with', 'with_attr', 'withPeople']),
      person: _readString(json, const ['person']),
      latitude: _readDouble(json, const ['latitude', 'lat']),
      longitude: _readDouble(json, const ['longitude', 'lng', 'lon', 'long']),
    );
  }

  List<MapEntry<String, String>> get entries {
    final values = <MapEntry<String, String>>[
      if (country != null) MapEntry('Country', country!),
      if (location != null) MapEntry('City', location!),
      if (subLocation != null) MapEntry('Location', subLocation!),
      if (album != null) MapEntry('Album', album!),
      if (subject != null) MapEntry('Subject', subject!),
      if (withPeople != null) MapEntry('With', withPeople!),
      if (person != null) MapEntry('Person', person!),
      if (latitude != null && longitude != null)
        MapEntry('Coordinates', '$latitude, $longitude'),
    ];
    return values;
  }

  String get placeLabel {
    return [
      subLocation,
      location,
      country,
    ].where((value) => value != null && value.isNotEmpty).join(', ');
  }
}

class GalleryTimeBucket {
  final int year;
  final int? month;
  final int? day;
  final int count;
  final int? locationCount;
  final int? tagCount;
  final List<GalleryPhoto> photos;

  const GalleryTimeBucket({
    required this.year,
    this.month,
    this.day,
    required this.count,
    this.locationCount,
    this.tagCount,
    this.photos = const [],
  });

  factory GalleryTimeBucket.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    return GalleryTimeBucket(
      year: _readInt(json, const ['year']) ?? 0,
      month: _readInt(json, const ['month']),
      day: _readInt(json, const ['day']),
      count:
          _readInt(json, const ['photo_count', 'count', 'total', 'photos']) ??
          0,
      locationCount: _readInt(json, const [
        'location_count',
        'locations_count',
        'locationCount',
        'locationsCount',
        'city_count',
        'cities_count',
      ]),
      tagCount: _readInt(json, const [
        'tag_count',
        'tags_count',
        'tagCount',
        'tagsCount',
        'attribute_count',
        'attributes_count',
      ]),
      photos: _newestPhotosFirst(
        _readList(json, const [
          'sample_photos',
          'photos',
          'items',
        ]).map(GalleryPhoto.fromJson),
      ),
    );
  }

  String get title {
    if (day != null) return day.toString().padLeft(2, '0');
    if (month != null) return _monthName(month!);
    return year.toString();
  }

  static String _monthName(int month) {
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
    if (month < 1 || month > 12) return month.toString();
    return months[month - 1];
  }
}

class GalleryFilterOption {
  final String value;
  final String label;
  final int count;

  const GalleryFilterOption({
    required this.value,
    required this.label,
    required this.count,
  });

  factory GalleryFilterOption.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    final value = _readString(json, const ['value', 'id']) ?? '';
    return GalleryFilterOption(
      value: value,
      label: _readString(json, const ['label', 'name', 'value']) ?? value,
      count:
          _readInt(json, const ['photo_count', 'count', 'total', 'photos']) ??
          0,
    );
  }
}

class GalleryFilterGroup {
  final String slug;
  final String title;
  final List<GalleryFilterOption> options;

  const GalleryFilterGroup({
    required this.slug,
    required this.title,
    required this.options,
  });

  factory GalleryFilterGroup.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    final slug = _readString(json, const ['slug', 'type']) ?? '';
    return GalleryFilterGroup(
      slug: slug,
      title: _readString(json, const ['title', 'name', 'label']) ?? slug,
      options: _readList(json, const ['items', 'values', 'options'])
          .map(GalleryFilterOption.fromJson)
          .where((option) => option.value.isNotEmpty)
          .toList(),
    );
  }
}

class GalleryHomeBundle {
  final List<GalleryPhoto> recent;
  final List<GalleryCard> collections;
  final List<GalleryCard> smrutiWith;
  final List<GalleryCard> smrutiOf;
  final List<GalleryCard> locations;
  final List<GalleryCard> albums;
  final List<GalleryCard> subjects;
  final List<GalleryCard> people;
  final List<GalleryCard> wallpapers;

  const GalleryHomeBundle({
    this.recent = const [],
    this.collections = const [],
    this.smrutiWith = const [],
    this.smrutiOf = const [],
    this.locations = const [],
    this.albums = const [],
    this.subjects = const [],
    this.people = const [],
    this.wallpapers = const [],
  });

  factory GalleryHomeBundle.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    final payload = asJsonMap(json['data']).isNotEmpty
        ? asJsonMap(json['data'])
        : json;

    List<GalleryPhoto> photosFor(List<String> keys) {
      return _readList(payload, keys)
          .map(GalleryPhoto.fromJson)
          .where((photo) => photo.thumbnailUrl.isNotEmpty)
          .toList();
    }

    List<GalleryCard> cardsFor(List<String> keys, String type) {
      dynamic source;
      for (final key in keys) {
        if (payload.containsKey(key)) {
          source = payload[key];
          break;
        }
      }
      source ??= asJsonMap(payload['smruti_of'])[type];
      if (source is Map && source[type] != null) {
        source = source[type];
      }
      return _readList(source, const [
        'items',
      ]).map((item) => GalleryCard.fromJson(item, fallbackType: type)).toList();
    }

    return GalleryHomeBundle(
      recent: photosFor(const ['recent', 'recent_photos', 'photos']),
      collections: cardsFor(const ['collections', 'years'], 'collection'),
      smrutiWith: cardsFor(const ['with', 'smruti_with', 'smrutiWith'], 'with'),
      smrutiOf: cardsFor(const [
        'smruti_of',
        'smrutiOf',
        'attributes',
        'persons',
      ], 'person'),
      locations: cardsFor(const ['locations', 'location'], 'location'),
      albums: cardsFor(const ['albums', 'album'], 'album'),
      subjects: cardsFor(const ['subjects', 'subject'], 'subject'),
      people: cardsFor(const ['people', 'persons'], 'person'),
      wallpapers: cardsFor(const ['wallpapers', 'wallpaper'], 'wallpaper'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recent': recent.map((photo) => photo.toJson()).toList(),
      'collections': collections.map((card) => card.toJson()).toList(),
      'smruti_with': smrutiWith.map((card) => card.toJson()).toList(),
      'smruti_of': smrutiOf.map((card) => card.toJson()).toList(),
      'locations': locations.map((card) => card.toJson()).toList(),
      'albums': albums.map((card) => card.toJson()).toList(),
      'subjects': subjects.map((card) => card.toJson()).toList(),
      'people': people.map((card) => card.toJson()).toList(),
      'wallpapers': wallpapers.map((card) => card.toJson()).toList(),
    };
  }

  GalleryHomeBundle mergeFallback({
    List<GalleryPhoto>? recent,
    List<GalleryCard>? collections,
    List<GalleryCard>? smrutiWith,
    List<GalleryCard>? smrutiOf,
    List<GalleryCard>? locations,
    List<GalleryCard>? albums,
    List<GalleryCard>? subjects,
    List<GalleryCard>? people,
    List<GalleryCard>? wallpapers,
  }) {
    return GalleryHomeBundle(
      recent: this.recent.isNotEmpty ? this.recent : recent ?? const [],
      collections: this.collections.isNotEmpty
          ? this.collections
          : collections ?? const [],
      smrutiWith: this.smrutiWith.isNotEmpty
          ? this.smrutiWith
          : smrutiWith ?? const [],
      smrutiOf: this.smrutiOf.isNotEmpty ? this.smrutiOf : smrutiOf ?? const [],
      locations: this.locations.isNotEmpty
          ? this.locations
          : locations ?? const [],
      albums: this.albums.isNotEmpty ? this.albums : albums ?? const [],
      subjects: this.subjects.isNotEmpty ? this.subjects : subjects ?? const [],
      people: this.people.isNotEmpty ? this.people : people ?? const [],
      wallpapers: this.wallpapers.isNotEmpty
          ? this.wallpapers
          : wallpapers ?? const [],
    );
  }
}
