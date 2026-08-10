import 'package:flutter_test/flutter_test.dart';
import 'package:harismruti/api/models/gallery_models.dart';

void main() {
  group('GalleryCard.fromJson', () {
    test(
      'preserves an explicitly empty attribute value for detail loading',
      () {
        final card = GalleryCard.fromJson({
          'type': 'with',
          'value': '',
          'photo_count': 200,
          'sample_photos': [
            {
              'id': 176992,
              'thumbnail_url': '/api/v1/mobile/photos/176992/thumbnail',
            },
          ],
        });

        expect(card.title, 'Smruti');
        expect(card.value, isEmpty);
        expect(card.count, 200);
      },
    );

    test('still falls back when the value field is absent', () {
      final card = GalleryCard.fromJson({
        'type': 'album',
        'name': 'Mahotsav',
        'photo_count': 12,
      });

      expect(card.title, 'Mahotsav');
      expect(card.value, 'Mahotsav');
    });

    test('reads managed coordinates for a location card', () {
      final card = GalleryCard.fromJson({
        'type': 'location',
        'value': 'Padra',
        'photo_count': 136,
        'latitude': 22.2394,
        'longitude': 73.0849,
      });

      expect(card.latitude, 22.2394);
      expect(card.longitude, 73.0849);
    });
  });

  group('GalleryPhoto.fromJson', () {
    test('uses only event_date as the photo date', () {
      final photo = GalleryPhoto.fromJson({
        'id': 42,
        'taken_at': '2005-05-29T20:00:00Z',
        'event_date': '2005-05-30T00:00:00Z',
        'inferred_date': '2005-05-28T00:00:00Z',
        'created_at': '2026-07-25T00:00:00Z',
      });

      expect(photo.takenAt, DateTime.parse('2005-05-30T00:00:00Z'));
      expect(photo.eventDate, DateTime.parse('2005-05-30T00:00:00Z'));
    });

    test('prefers the On This Day calendar date over its UTC timestamp', () {
      final photo = GalleryPhoto.fromJson({
        'id': 46,
        'on_this_day_date': '2024-08-10',
        'event_date': '2024-08-09T18:30:00Z',
      });

      expect(photo.eventDate, DateTime(2024, 8, 10));
      expect(photo.takenAt, DateTime(2024, 8, 10));
    });

    test('does not substitute My Smruti photo_date for event_date', () {
      final photo = GalleryPhoto.fromJson({
        'id': 43,
        'photo_date': '2005-05-29T20:00:00Z',
        'taken_at': '2005-05-29T20:00:00Z',
        'inferred_date': '2005-05-28T00:00:00Z',
        'created_at': '2026-07-25T00:00:00Z',
      });

      expect(photo.takenAt, isNull);
      expect(photo.eventDate, isNull);
    });

    test('does not use unrelated timestamps when display date is absent', () {
      final photo = GalleryPhoto.fromJson({
        'id': 44,
        'taken_at': '2005-05-29T20:00:00Z',
        'inferred_date': '2005-05-28T00:00:00Z',
        'created_at': '2026-07-25T00:00:00Z',
      });

      expect(photo.takenAt, isNull);
      expect(photo.eventDate, isNull);
    });

    test('reads category attributes returned by My Smruti', () {
      final photo = GalleryPhoto.fromJson({
        'photo_id': 45,
        'country': 'India',
        'location': 'Ahmedabad',
        'sub_location': 'Shahibaug',
        'album': 'Yatra',
        'smruti_with': 'Sant Mandal',
        'darshan_of': 'Hariprasad Swamiji',
        'smruti_of': 'Sabha',
      });

      expect(photo.country, 'India');
      expect(
        photo.tags,
        containsAll([
          'India',
          'Ahmedabad',
          'Shahibaug',
          'Yatra',
          'Sant Mandal',
          'Hariprasad Swamiji',
          'Sabha',
        ]),
      );
      expect(photo.location, 'Ahmedabad');
      expect(photo.subLocation, 'Shahibaug');
      expect(photo.album, 'Yatra');
      expect(photo.smrutiWith, 'Sant Mandal');
      expect(photo.darshanOf, 'Hariprasad Swamiji');
      expect(photo.smrutiOf, 'Sabha');
    });
  });
}
