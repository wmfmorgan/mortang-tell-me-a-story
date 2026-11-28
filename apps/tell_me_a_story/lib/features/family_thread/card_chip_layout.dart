import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

const cardChipHeight = 28.0;
const cardChipSpacing = 8.0;
const cardChipIcon = 16.0;
const cardChipIconGap = 4.0;
const cardChipPad = 8.0;

class CardChipLayout {
  CardChipLayout({
    required List<String> people,
    required String? place,
    required this.maxWidth,
    required this.textScaler,
    this.maxRows = 2,
  }) : labels = _labels(people, place);

  final List<String> labels;
  final double maxWidth;
  final TextScaler textScaler;
  final int maxRows;

  int get rows {
    if (labels.isEmpty || maxWidth <= 0 || maxRows <= 0) return 0;
    final all = _fits(labels, null);
    if (all <= maxRows) return all;
    for (var keep = labels.length - 1; keep >= 0; keep--) {
      final extra = labels.length - keep;
      final used = _fits(labels.sublist(0, keep), '+$extra');
      if (used <= maxRows) return used;
    }
    return maxRows;
  }

  int _fits(List<String> names, String? extra) {
    final items = [for (final name in names) name, if (extra != null) extra];
    if (items.isEmpty) return 0;
    var rowCount = 1;
    var used = 0.0;
    for (final label in items) {
      final width = _width(label);
      final next = used == 0 ? width : used + cardChipSpacing + width;
      if (next <= maxWidth) {
        used = next;
        continue;
      }
      rowCount += 1;
      used = width;
    }
    return rowCount;
  }

  double _width(String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _chipStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final raw =
        cardChipPad * 2 + cardChipIcon + cardChipIconGap + painter.width;
    return raw > maxWidth ? maxWidth : raw;
  }
}

List<String> _labels(List<String> people, String? place) {
  final placeLabel = place?.trim() ?? '';
  return [
    for (final name in people)
      if (name.trim().isNotEmpty) name.trim(),
    if (placeLabel.isNotEmpty) placeLabel,
  ];
}

final _chipStyle = GoogleFonts.sourceSans3(fontSize: 13);
