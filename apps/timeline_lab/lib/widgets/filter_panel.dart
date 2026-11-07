import 'package:flutter/material.dart';

import '../filter/timeline_filter.dart';
import '../lab_controller.dart';
import '../theme/lab_theme.dart';

/// Every control writes through `controller.setFilter(filter.copyWith(...))`.
class FilterPanel extends StatefulWidget {
  const FilterPanel({
    super.key,
    required this.controller,
    this.searchFocusNode,
  });

  final LabController controller;
  final FocusNode? searchFocusNode;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late final _search = TextEditingController(
    text: widget.controller.filter.query,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncSearch);
  }

  /// Runs on controller notifications, never during build.
  void _syncSearch() {
    final q = widget.controller.filter.query;
    if (_search.text != q) _search.text = q;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncSearch);
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
      padding: const EdgeInsets.all(LabSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('filter-search'),
            controller: _search,
            focusNode: widget.searchFocusNode,
            decoration: const InputDecoration(
              labelText: 'Search',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (q) => controller.setFilter(filter.copyWith(query: q)),
          ),
          const SizedBox(height: LabSpace.l),
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
          const SizedBox(height: LabSpace.s),
          Text('People', style: labelStyle),
          const SizedBox(height: LabSpace.xs),
          Wrap(
            spacing: LabSpace.s,
            runSpacing: LabSpace.s,
            children: [
              for (final p in d.people.values)
                FilterChip(
                  key: Key('filter-person-${p.id}'),
                  label: _ChipLabel(p.name),
                  selected: filter.personIds.contains(p.id),
                  onSelected: (on) => controller.setFilter(
                    filter.copyWith(
                      personIds: toggled(filter.personIds, p.id, on),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: LabSpace.l),
          Text('Places', style: labelStyle),
          const SizedBox(height: LabSpace.xs),
          Wrap(
            spacing: LabSpace.s,
            runSpacing: LabSpace.s,
            children: [
              for (final p in d.places.values)
                FilterChip(
                  key: Key('filter-place-${p.id}'),
                  label: _ChipLabel(p.label),
                  selected: filter.placeIds.contains(p.id),
                  onSelected: (on) => controller.setFilter(
                    filter.copyWith(
                      placeIds: toggled(filter.placeIds, p.id, on),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: LabSpace.l),
          Text('Families', style: labelStyle),
          const SizedBox(height: LabSpace.xs),
          Wrap(
            spacing: LabSpace.s,
            runSpacing: LabSpace.s,
            children: [
              for (final f in d.families.values)
                FilterChip(
                  key: Key('filter-family-${f.id}'),
                  label: _ChipLabel(
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
          const SizedBox(height: LabSpace.l),
          TextButton(
            key: const Key('filter-clear'),
            onPressed: () =>
                controller.setFilter(TimelineFilter(mode: filter.mode)),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

/// A chip label that never fades.
///
/// `RawChip` lays its label out at the height its dry layout reported and
/// wraps it in `TextOverflow.fade`. With the web text engine the real layout
/// can come out a fraction of a pixel taller, which counts as a vertical
/// overflow, so the whole line gets a top-to-bottom fade. An explicit
/// single-line ellipsis replaces that fade: a sub-pixel overflow is clipped
/// invisibly, and a genuinely long label still ends in "…".
class _ChipLabel extends StatelessWidget {
  const _ChipLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
}
