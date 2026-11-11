import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/domain/place.dart';

void main() {
  group('ensureValidPlaceCreate', () {
    test('accepts non-empty label and address', () {
      expect(
        () => ensureValidPlaceCreate(label: 'Park', address: '1 Park Ave'),
        returnsNormally,
      );
    });

    test('rejects empty label', () {
      expect(
        () => ensureValidPlaceCreate(label: '', address: 'Addr'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects whitespace-only address', () {
      expect(
        () => ensureValidPlaceCreate(label: 'Park', address: '  '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
