import 'package:flutter/material.dart';

/// The in-renderer view switch (swimlanes, tree graph, treemap): one
/// placement, one label style, singular segment names. Scrolls sideways on
/// narrow screens instead of overflowing.
class ViewSwitch<T> extends StatelessWidget {
  const ViewSwitch({
    super.key,
    required this.switchKey,
    required this.label,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.trailing = const [],
  });

  /// Goes on the `SegmentedButton` itself, so tests can read `.selected`.
  final Key switchKey;
  final String label;
  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 12),
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
