import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import 'family_thread_copy.dart';
import 'thread_filter.dart';

class FilterPills extends StatelessWidget {
  const FilterPills({
    super.key,
    required this.filter,
    required this.personLabels,
    required this.placeLabels,
    required this.onChanged,
  });

  final ThreadFilter filter;
  final Map<String, String> personLabels;
  final Map<String, String> placeLabels;
  final ValueChanged<ThreadFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final pills = _pillsOf(filter, personLabels, placeLabels);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final pill in pills) _PillView(pill: pill, onChanged: onChanged),
          TextButton(
            onPressed: () => onChanged(ThreadFilter.cleared),
            style: TextButton.styleFrom(
              foregroundColor: albumTerracotta,
              minimumSize: const Size(44, 44),
            ),
            child: const Text(FamilyThreadCopy.clearFilters),
          ),
        ],
      ),
    );
  }
}

class _PillView extends StatelessWidget {
  const _PillView({required this.pill, required this.onChanged});

  final _Pill pill;
  final ValueChanged<ThreadFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: sageTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: albumPillBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              pill.label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Semantics(
            button: true,
            label: FamilyThreadCopy.removeFilter(pill.label),
            child: SizedBox(
              width: 44,
              height: 44,
              child: InkWell(
                onTap: () => onChanged(pill.next),
                child: const ExcludeSemantics(
                  child: Icon(Icons.close, size: 18, color: albumInk),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _Pill = ({String label, ThreadFilter next});

List<_Pill> _pillsOf(
  ThreadFilter filter,
  Map<String, String> personLabels,
  Map<String, String> placeLabels,
) {
  return [
    ..._searchPills(filter),
    ..._idPills(filter, filter.personIds, personLabels, _withoutPeople),
    ..._idPills(filter, filter.placeIds, placeLabels, _withoutPlaces),
    ..._decadePills(filter),
  ];
}

List<_Pill> _searchPills(ThreadFilter filter) {
  final query = filter.search.trim();
  if (query.isEmpty) return const [];
  return [(label: query, next: _replace(filter, clearSearch: true))];
}

List<_Pill> _decadePills(ThreadFilter filter) {
  final from = filter.decadeFrom;
  final to = filter.decadeTo;
  if (from == null && to == null) return const [];
  final start = from ?? to!;
  final end = to ?? from!;
  return [
    (
      label: FamilyThreadCopy.decadeRange(start, end),
      next: _replace(filter, clearDecade: true),
    ),
  ];
}

List<_Pill> _idPills(
  ThreadFilter filter,
  Set<String> ids,
  Map<String, String> labels,
  ThreadFilter Function(ThreadFilter filter, Set<String> remaining) next,
) {
  final ordered = [...ids]
    ..sort((a, b) {
      final byLabel = _label(labels, a).compareTo(_label(labels, b));
      if (byLabel != 0) return byLabel;
      return a.compareTo(b);
    });
  return [
    for (final id in ordered)
      (label: _label(labels, id), next: next(filter, {...ids}..remove(id))),
  ];
}

String _label(Map<String, String> labels, String id) {
  final label = labels[id]?.trim();
  if (label == null || label.isEmpty) return id;
  return label;
}

ThreadFilter _withoutPeople(ThreadFilter filter, Set<String> ids) {
  return _replace(filter, personIds: ids);
}

ThreadFilter _withoutPlaces(ThreadFilter filter, Set<String> ids) {
  return _replace(filter, placeIds: ids);
}

ThreadFilter _replace(
  ThreadFilter filter, {
  Set<String>? personIds,
  Set<String>? placeIds,
  bool clearSearch = false,
  bool clearDecade = false,
}) {
  return ThreadFilter(
    search: clearSearch ? '' : filter.search,
    personIds: personIds ?? filter.personIds,
    placeIds: placeIds ?? filter.placeIds,
    decadeFrom: clearDecade ? null : filter.decadeFrom,
    decadeTo: clearDecade ? null : filter.decadeTo,
  );
}
