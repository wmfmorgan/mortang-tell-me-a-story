import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/family_thread_density.dart';
import 'package:tell_me_a_story/data/family_thread_open_state.dart';

const _story = '55555555-5555-4555-8555-555555555555';

void main() {
  test('encode has exactly two fields', () {
    const state = FamilyThreadOpenState(
      density: FamilyThreadDensity.browse,
      storyId: _story,
    );
    final raw = state.encode();
    expect(raw, '{"density":"browse","storyId":"$_story"}');
    expect(jsonDecode(raw), {'density': 'browse', 'storyId': _story});
  });

  test('tryDecode rejects malformed fixtures', () {
    const valid = '{"density":"browse","storyId":"$_story"}';
    final over = valid.padRight(257);
    expect(utf8.encode(over).length, 257);
    const fixtures = <String>[
      'not json',
      '[]',
      '{"density":"browse"}',
      '{"density":"browse","storyId":"$_story","extra":1}',
      '{"density":"zoom","storyId":"$_story"}',
      '{"density":"browse","storyId":"abc"}',
    ];
    for (final raw in fixtures) {
      expect(FamilyThreadOpenState.tryDecode(raw), isNull, reason: raw);
    }
    expect(FamilyThreadOpenState.tryDecode(over), isNull);
    final exact = valid.padRight(256);
    expect(utf8.encode(exact).length, 256);
    expect(FamilyThreadOpenState.tryDecode(exact)?.storyId, _story);
  });

  test('tryDecode catches FormatException and returns null', () {
    expect(FamilyThreadOpenState.tryDecode('{'), isNull);
  });

  test('round trip returns the same state', () {
    for (final density in FamilyThreadDensity.values) {
      final state = FamilyThreadOpenState(density: density, storyId: _story);
      final decoded = FamilyThreadOpenState.tryDecode(state.encode());
      expect(decoded?.density, density);
      expect(decoded?.storyId, _story);
    }
  });
}
