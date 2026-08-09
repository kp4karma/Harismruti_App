import 'package:flutter_test/flutter_test.dart';
import 'package:harismruti/ui/controller/my_diary_controller.dart';

void main() {
  group('MyDiaryController calendar', () {
    test('creates a Sunday-first grid with complete weeks', () {
      final dates = MyDiaryController().monthCalendarDates(DateTime(2026, 8));

      expect(dates.length % 7, 0);
      expect(dates.whereType<DateTime>().first, DateTime(2026, 8, 1));
      expect(dates.whereType<DateTime>().last, DateTime(2026, 8, 31));
      expect(dates[0], isNull); // August 2026 starts on Saturday.
      expect(dates[6], DateTime(2026, 8, 1));
    });
  });

  group('DiaryEntry migration', () {
    test('keeps legacy entries and defaults new metadata safely', () {
      final entry = DiaryEntry.fromJson({
        'id': 'legacy',
        'date': '2026-08-09',
        'title': 'Existing memory',
        'note': 'Preserve me',
      });

      expect(entry.id, 'legacy');
      expect(entry.rating, 0);
      expect(entry.audioAttachments, isEmpty);
      expect(entry.fileAttachments, isEmpty);
    });

    test('round trips rating and attachment metadata', () {
      final entry = DiaryEntry.fromJson({
        'id': 'new',
        'date': '2026-08-09',
        'title': 'A day',
        'note': 'Notes',
        'rating': 5,
        'audio_attachments': [
          {'uri': 'audio.m4a', 'duration_ms': 1200},
        ],
        'file_attachments': [
          {'uri': 'letter.pdf', 'name': 'Letter'},
        ],
      });

      expect(entry.toJson()['rating'], 5);
      expect(entry.audioAttachments.single['duration_ms'], 1200);
      expect(entry.fileAttachments.single['name'], 'Letter');
    });
  });
}
