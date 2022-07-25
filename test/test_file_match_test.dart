import 'package:sentinel/test_file_match.dart';
import 'package:test/test.dart';

void main() {
  group(TestFileMatch, () {
    late TestFileMatch match;

    setUp(() {
      match = TestFileMatch(exists: true, path: '/foo/bar_test.dart');
    });

    test('it has correct tostring()', () {
      expect(
        match.toString(),
        equals(
          'path: /foo/bar_test.dart\nexists: true\nintegrationTest: false',
        ),
      );
    });

    test('== operator', () {
      final match2 = TestFileMatch(exists: true, path: '/foo/bar_test.dart');
      expect(match, equals(match2));
    });

    test('hashCode', () {
      final match2 = TestFileMatch(exists: true, path: '/foo/bar_test.dart');
      expect(match.hashCode, equals(match2.hashCode));
    });
  });
}
