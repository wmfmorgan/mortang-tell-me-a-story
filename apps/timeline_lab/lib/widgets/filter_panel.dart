import 'package:flutter/material.dart';

import '../filter/timeline_filter.dart';
import '../lab_controller.dart';

/// Every control writes through `controller.setFilter(filter.copyWith(...))`.
class FilterPanel extends StatefulWidget {
  const FilterPanel({super.key, required this.controller});

  final LabController controller;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late final _search = TextEditingController(
    text: widget.controller.filter.query,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final filter = controller.filter;
    final d = controller.dataset;
    final labelStyle = Theme.of(context).textTheme.titleSmall;

    Set<String> toggled(Set<String> s, String id, bool on) =>
        on ? {...s, id} : ({...s}..remove(id));

    final minYear = d.minYear.toDouble();
    final maxYear = d.maxYear.toDouble();
    final values = RangeValues(
      (filter.fromYear ?? d.minYear).clamp(d.minYear, d.maxYear).toDouble(),
      (filter.toYear ?? d.maxYear).clamp(d.minYear, d.maxYear).toDouble(),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('filter-search'),
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Search',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (q) => controller.setFilter(filter.copyWith(query: q)),
          ),
          const SizedBox(height: 16),
          Text(
            'Era ${values.start.round()}–${values.end.round()}',
            style: labelStyle,
          ),
          RangeSlider(
            key: const Key('filter-era'),
            min: minYear,
            max: maxYear,
            divisions: d.maxYear - d.minYear,
            values: values,
            labels: RangeLabels(
              '${values.start.round()}',
              '${values.end.round()}',
            ),
            onChanged: (v) {
              // A thumb at its extreme is an open bound.
              final from = v.start.round();
              final to = v.end.round();
              controller.setFilter(
                filter.copyWith(
                  fromYear: () => from == d.minYear ? null : from,
                  toYear: () => to == d.maxYear ? null : to,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text('People', style: labelStyle),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final p in d.people.values)
                FilterChip(
                  key: Key('filter-person-${p.id}'),
                  label: Text(p.name),
                  selected: filter.personIds.contains(p.id),
                  onSelected: (on) => controller.setFilter(
                    filter.copyWith(
                      personIds: toggled(filter.personIds, p.id, on),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Places', style: labelStyle),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final p in d.places.values)
                FilterChip(
                  key: Key('filter-place-${p.id}'),
                  label: Text(p.label),
                  selected: filter.placeIds.contains(p.id),
                  onSelected: (on) => controller.setFilter(
                    filter.copyWith(
                      placeIds: toggled(filter.placeIds, p.id, on),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Families', style: labelStyle),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final f in d.families.values)
                FilterChip(
                  key: Key('filter-family-${f.id}'),
                  label: Text(
                    f.isBranch ? '${f.name} (${f.branchYear})' : f.name,
                  ),
                  selected: filter.familyIds.contains(f.id),
                  onSelected: (on) => controller.setFilter(
                    filter.copyWith(
                      familyIds: toggled(filter.familyIds, f.id, on),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            key: const Key('filter-clear'),
            onPressed: () {
              _search.clear();
              controller.setFilter(TimelineFilter(mode: filter.mode));
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
