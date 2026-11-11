import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/features/search/domain/search_facets.dart';

void main() {
  test('decade chip label uses an en dash for a span', () {
    expect(decadeChipLabel(const [1980]), '1980s');
    expect(decadeChipLabel(const [1990, 1980]), '1980s–1990s');
  });
}
