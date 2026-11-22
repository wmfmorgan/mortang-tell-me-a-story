import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/uuid.dart';

void main() {
  test('isUuid accepts a canonical id and rejects other strings', () {
    expect(isUuid('11111111-1111-4111-8111-111111111111'), isTrue);
    expect(isUuid('NULL'), isFalse);
    expect(isUuid('abc'), isFalse);
  });
}
