import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/domain/display_name.dart';
import 'package:tell_me_a_story/core/domain/perspective.dart';

void main() {
  group('displayNameOrMember', () {
    test('returns trimmed name', () {
      expect(displayNameOrMember('Aunt Clara'), 'Aunt Clara');
      expect(displayNameOrMember('  Ada  '), 'Ada');
    });

    test('falls back to Member when missing blank or null', () {
      expect(displayNameOrMember(null), 'Member');
      expect(displayNameOrMember(''), 'Member');
      expect(displayNameOrMember('   '), 'Member');
    });
  });

  group('ensureValidPerspectiveBody', () {
    test('accepts non-empty body', () {
      expect(() => ensureValidPerspectiveBody('hi'), returnsNormally);
      expect(() => ensureValidPerspectiveBody('  hi  '), returnsNormally);
    });

    test('rejects empty body', () {
      expect(
        () => ensureValidPerspectiveBody(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects whitespace-only body', () {
      expect(
        () => ensureValidPerspectiveBody('   '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
