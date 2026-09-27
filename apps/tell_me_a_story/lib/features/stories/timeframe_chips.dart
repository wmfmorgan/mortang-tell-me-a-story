import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';

class DecadeRange {
  const DecadeRange(this.startYear);
  final int startYear; // 1980
  DateTime get start => DateTime(startYear, 1, 1);
  DateTime get end => DateTime(startYear + 9, 12, 31);
  String get label => '${startYear}s';

  static DecadeRange? containing(DateTime start) {
    for (final decade in decadeChips) {
      if (start.year >= decade.startYear &&
          start.year <= decade.startYear + 9) {
        return decade;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is DecadeRange && other.startYear == startYear;

  @override
  int get hashCode => startYear.hashCode;
}

const decadeChips = [
  DecadeRange(1900),
  DecadeRange(1910),
  DecadeRange(1920),
  DecadeRange(1930),
  DecadeRange(1940),
  DecadeRange(1950),
  DecadeRange(1960),
  DecadeRange(1970),
  DecadeRange(1980),
  DecadeRange(1990),
  DecadeRange(2000),
  DecadeRange(2010),
  DecadeRange(2020),
];

class TimeframeChips extends StatelessWidget {
  const TimeframeChips({
    super.key,
    this.selectedStartYear,
    required this.onSelected,
  });

  final int? selectedStartYear;
  final ValueChanged<DecadeRange> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final decade in decadeChips)
          TextButton(
            onPressed: () => onSelected(decade),
            style: TextButton.styleFrom(
              backgroundColor: decade.startYear == selectedStartYear
                  ? albumTerracotta
                  : albumParchment,
              foregroundColor: decade.startYear == selectedStartYear
                  ? albumParchment
                  : albumInk,
              side: BorderSide(
                color: decade.startYear == selectedStartYear
                    ? albumTerracotta
                    : albumSage,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(decade.label),
          ),
      ],
    );
  }
}
