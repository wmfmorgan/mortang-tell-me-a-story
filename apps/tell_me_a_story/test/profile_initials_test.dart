import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/profile_initials.dart';

void main() {
  test('Sarah Morgan is SM', () {
    expect(profileInitials('Sarah Morgan'), 'SM');
  });

  test('one word is that word’s first letter', () {
    expect(profileInitials('Ada'), 'A');
  });

  test('a blank name is empty', () {
    expect(profileInitials(null), isEmpty);
    expect(profileInitials('   '), isEmpty);
  });

  test('extra spaces do not add letters', () {
    expect(profileInitials('  Mary   Ann  '), 'MA');
  });
}
