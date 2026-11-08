import 'package:flutter/material.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';

/// A labelled view switch: one placement, one label style, singular segment
/// names, styled by `albumTheme().segmentedButtonTheme` (terracotta
/// selected). Scrolls sideways on narrow screens instead of overflowing.
class ViewSwitch<T> extends StatelessWidget {
  const ViewSwitch({
    super.key,
    required this.switchKey,
    this.label,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.trailing = const [],
  });

  /// Goes on the `SegmentedButton` itself, so tests can read `.selected`.
  final Key switchKey;

  /// Shown before the segments. Null when the segment names say it all.
  final String? label;
  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AlbumSpace.l,
        vertical: AlbumSpace.s,
      ),
      child: Row(
        children: [
          if (label != null) ...[
            Text(label, style: AlbumText.lane(Theme.of(context).textTheme)),
            const SizedBox(width: AlbumSpace.m),
          ],
          SegmentedButton<T>(
            key: switchKey,
            showSelectedIcon: false,
            segments: [
              for (final v in values)
                ButtonSegment(value: v, label: Text(labelOf(v))),
            ],
            selected: {selected},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
          ...trailing,
        ],
      ),
    );
  }
}
