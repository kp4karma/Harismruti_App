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

List<dynamic> _readList(dynamic source, List<String> keys) {
  if (source is List) return source;
  if (source is Map) {
    for (final key in keys) {
      final value = source[key];
      if (value is List) return value;
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

  const GalleryPhoto({
    required this.id,
    required this.thumbnailUrl,
    required this.fullUrl,
    this.title,
    this.subtitle,
    this.takenAt,
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
        _readString(json, const ['taken_at', 'created_at', 'date']) ?? '',
      ),
    );
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
  final int? faceId;
  final List<GalleryPhoto> photos;

  const GalleryCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.value,
    this.count,
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
      faceId: _readInt(json, const [
        'face_id',
        'representative_face_id',
        'cover_face_id',
      ]),
      photos: samplePhotos,
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

class GalleryHomeBundle {
  final List<GalleryPhoto> recent;
  final List<GalleryCard> collections;
  final List<GalleryCard> smrutiOf;
  final List<GalleryCard> locations;
  final List<GalleryCard> albums;
  final List<GalleryCard> people;
  final List<GalleryCard> wallpapers;

  const GalleryHomeBundle({
    this.recent = const [],
    this.collections = const [],
    this.smrutiOf = const [],
    this.locations = const [],
    this.albums = const [],
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
      return _readList(
        payload,
        keys,
      ).map((item) => GalleryCard.fromJson(item, fallbackType: type)).toList();
    }

    return GalleryHomeBundle(
      recent: photosFor(const ['recent', 'recent_photos', 'photos']),
      collections: cardsFor(const ['collections', 'years'], 'collection'),
      smrutiOf: cardsFor(const [
        'smruti_of',
        'smrutiOf',
        'attributes',
        'persons',
      ], 'person'),
      locations: cardsFor(const ['locations', 'location'], 'location'),
      albums: cardsFor(const ['albums', 'album'], 'album'),
      people: cardsFor(const ['people', 'persons'], 'person'),
      wallpapers: cardsFor(const ['wallpapers', 'wallpaper'], 'wallpaper'),
    );
  }

  GalleryHomeBundle mergeFallback({
    List<GalleryPhoto>? recent,
    List<GalleryCard>? collections,
    List<GalleryCard>? smrutiOf,
    List<GalleryCard>? locations,
    List<GalleryCard>? albums,
    List<GalleryCard>? people,
    List<GalleryCard>? wallpapers,
  }) {
    return GalleryHomeBundle(
      recent: this.recent.isNotEmpty ? this.recent : recent ?? const [],
      collections: this.collections.isNotEmpty
          ? this.collections
          : collections ?? const [],
      smrutiOf: this.smrutiOf.isNotEmpty ? this.smrutiOf : smrutiOf ?? const [],
      locations: this.locations.isNotEmpty
          ? this.locations
          : locations ?? const [],
      albums: this.albums.isNotEmpty ? this.albums : albums ?? const [],
      people: this.people.isNotEmpty ? this.people : people ?? const [],
      wallpapers: this.wallpapers.isNotEmpty
          ? this.wallpapers
          : wallpapers ?? const [],
    );
  }
}
