import 'package:flutter_test/flutter_test.dart';
import 'package:harismruti/api/api_visibility.dart';

void main() {
  group('filterIgnoredApiItems', () {
    test('removes ignored records from nested API lists', () {
      final result =
          filterIgnoredApiItems({
                'data': [
                  {'id': 1, 'ignore': false},
                  {'id': 2, 'ignore': true},
                  {
                    'id': 3,
                    'children': [
                      {'id': 31, 'ignore': 1},
                      {'id': 32, 'ignore': 0},
                    ],
                  },
                ],
              })
              as Map;

      final data = result['data'] as List;
      expect(data.map((item) => item['id']), [1, 3]);
      expect((data.last['children'] as List).single['id'], 32);
    });

    test('accepts common API boolean representations', () {
      for (final flag in [true, 1, '1', 'true', 'YES', 'y']) {
        expect(isIgnoredApiItem({'ignore': flag}), isTrue);
      }
      for (final flag in [false, 0, '0', 'false', null]) {
        expect(isIgnoredApiItem({'ignore': flag}), isFalse);
      }
    });

    test('supports common ignore field aliases', () {
      expect(isIgnoredApiItem({'ignored': true}), isTrue);
      expect(isIgnoredApiItem({'is_ignore': true}), isTrue);
      expect(isIgnoredApiItem({'is_ignored': true}), isTrue);
      expect(isIgnoredApiItem({'isIgnore': true}), isTrue);
      expect(isIgnoredApiItem({'isIgnored': true}), isTrue);
    });
  });
}
