import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/features/stories/reader_meta.dart';

void main() {
  test('minutesToRead rounds words up by 200 and stays at least 1', () {
    expect(minutesToRead(null), 1);
    expect(minutesToRead('   '), 1);
    expect(minutesToRead(List.filled(200, 'word').join(' ')), 1);
    expect(minutesToRead(List.filled(201, 'word').join(' ')), 2);
  });

  test('recordedEventLabel uses one date or an en-dash range', () {
    final start = DateTime(1974, 7, 24);
    expect(
      recordedEventLabel(start: start),
      albumDate(start),
    );
    expect(
      recordedEventLabel(start: start, end: DateTime(1974, 7, 24)),
      albumDate(start),
    );
    final end = DateTime(1989, 12, 31);
    expect(
      recordedEventLabel(start: start, end: end),
      '${albumDate(start)} – ${albumDate(end)}',
    );
  });

  test('decadeChipLabel uses the start year decade', () {
    expect(decadeChipLabel(DateTime(1974, 7, 24)), '1970s');
  });

  test('placeChipText prefers a label and falls back to the address', () {
    expect(placeChipText(label: 'Oak Street', address: '1 Oak'), 'Oak Street');
    expect(placeChipText(label: '  ', address: '1 Oak'), '1 Oak');
    expect(placeChipText(label: ' ', address: ' '), isNull);
  });
}
