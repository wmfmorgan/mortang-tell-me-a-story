import 'package:flutter/material.dart';

import 'river_filter.dart';
import 'river_filter_options.dart';

/// Removable chips for the filters that are on.
class RiverFilterPills extends StatelessWidget {
  const RiverFilterPills({
    super.key,
    required this.filter,
    required this.options,
    required this.onChanged,
  });

  final RiverFilter filter;
  final RiverFilterOptions options;
  final ValueChanged<RiverFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = _chips();
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  List<Widget> _chips() {
    return [
      for (final person in options.people)
        if (filter.personIds.contains(person.id))
          _pill(person.name, () => _dropPerson(person.id)),
      for (final place in options.places)
        if (filter.placeIds.contains(place.id))
          _pill(place.label, () => _dropPlace(place.id)),
      if (options.yearRangeLabel(filter) case final label?)
        _pill(label, _dropYears),
      if (filter.query.trim().isNotEmpty)
        _pill(filter.query.trim(), () => onChanged(filter.copyWith(query: ''))),
    ];
  }

  Widget _pill(String label, VoidCallback onDeleted) {
    return InputChip(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onDeleted: onDeleted,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  void _dropPerson(String id) {
    onChanged(filter.copyWith(personIds: {...filter.personIds}..remove(id)));
  }

  void _dropPlace(String id) {
    onChanged(filter.copyWith(placeIds: {...filter.placeIds}..remove(id)));
  }

  void _dropYears() {
    onChanged(filter.copyWith(fromDecade: () => null, toDecade: () => null));
  }
}
