import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/features/timeline/presentation/filter/timeline_filter.dart';
import 'package:tell_me_a_story/core/widgets/controls/album_chip.dart';

/// The timeline filters (Q4, copy C11–C17): a search field, People, Places
/// and a decade range. Every control reports a new [TimelineFilter] through
/// [onChanged]; the page owns the state, so the sidebar and the drawer show
/// the same filter.
class FilterPanel extends StatefulWidget {
  const FilterPanel({
    super.key,
    required this.filter,
    required this.options,
    required this.matched,
    required this.total,
    required this.onChanged,
  });

  final TimelineFilter filter;
  final FilterOptions options;
  final int matched;
  final int total;
  final ValueChanged<TimelineFilter> onChanged;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

Set<String> _toggled(Set<String> ids, String id) =>
    ids.contains(id) ? ({...ids}..remove(id)) : {...ids, id};

class _FilterPanelState extends State<FilterPanel> {
  late final _search = TextEditingController(text: widget.filter.query);

  @override
  void didUpdateWidget(covariant FilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A clear from outside the field (Clear filters, a family switch).
    final query = widget.filter.query;
    if (_search.text != query) _search.text = query;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = widget.filter;
    final options = widget.options;
    final onChanged = widget.onChanged;
    return Padding(
      padding: const EdgeInsets.all(AlbumSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            active: filter.isActive,
            matched: widget.matched,
            total: widget.total,
          ),
          const SizedBox(height: AlbumSpace.m),
          TextField(
            key: const Key('filter-search'),
            controller: _search,
            decoration: _searchDecoration,
            onChanged: (query) => onChanged(filter.copyWith(query: query)),
          ),
          _OptionSections(
            filter: filter,
            options: options,
            onChanged: onChanged,
          ),
          if (filter.isActive) ...[
            const SizedBox(height: AlbumSpace.l),
            _ClearButton(onChanged: onChanged),
          ],
        ],
      ),
    );
  }
}

/// People, Places and Years: each only when there is something to pick.
class _OptionSections extends StatelessWidget {
  const _OptionSections({
    required this.filter,
    required this.options,
    required this.onChanged,
  });

  final TimelineFilter filter;
  final FilterOptions options;
  final ValueChanged<TimelineFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (options.people.isNotEmpty)
          _PeopleSection(
            filter: filter,
            options: options,
            onChanged: onChanged,
          ),
        if (options.places.isNotEmpty)
          _PlacesSection(
            filter: filter,
            options: options,
            onChanged: onChanged,
          ),
        if (options.decades.length > 1)
          _Section(
            title: 'Years',
            child: _DecadeRange(
              filter: filter,
              decades: options.decades,
              onChanged: onChanged,
            ),
          ),
      ],
    );
  }
}

const _searchDecoration = InputDecoration(
  hintText: 'Search titles, stories and people',
  prefixIcon: Icon(Icons.search),
);

/// The panel title and, while a filter is on, the match count.
class _Header extends StatelessWidget {
  const _Header({
    required this.active,
    required this.matched,
    required this.total,
  });

  final bool active;
  final int matched;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Filters', style: text.titleLarge),
        if (active) ...[
          const SizedBox(height: AlbumSpace.xs),
          Text(
            filterStatusLine(matched, total),
            key: const Key('filter-status'),
            style: AlbumText.count(text),
          ),
        ],
      ],
    );
  }
}

class _PeopleSection extends StatelessWidget {
  const _PeopleSection({
    required this.filter,
    required this.options,
    required this.onChanged,
  });

  final TimelineFilter filter;
  final FilterOptions options;
  final ValueChanged<TimelineFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'People',
      child: _Chips(
        children: [
          for (final person in options.people)
            AlbumChip(
              key: Key('filter-person-${person.id}'),
              label: person.name,
              selected: filter.personIds.contains(person.id),
              onTap: () => onChanged(
                filter.copyWith(
                  personIds: _toggled(filter.personIds, person.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlacesSection extends StatelessWidget {
  const _PlacesSection({
    required this.filter,
    required this.options,
    required this.onChanged,
  });

  final TimelineFilter filter;
  final FilterOptions options;
  final ValueChanged<TimelineFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Places',
      child: _Chips(
        children: [
          for (final place in options.places)
            AlbumChip(
              key: Key('filter-place-${place.id}'),
              label: place.label,
              selected: filter.placeIds.contains(place.id),
              onTap: () => onChanged(
                filter.copyWith(placeIds: _toggled(filter.placeIds, place.id)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onChanged});

  final ValueChanged<TimelineFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FButton(
        key: const Key('filter-clear'),
        variant: FButtonVariant.ghost,
        mainAxisSize: MainAxisSize.min,
        onPress: () => onChanged(const TimelineFilter()),
        child: const Text('Clear filters'),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AlbumSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AlbumText.group(Theme.of(context).textTheme)),
          const SizedBox(height: AlbumSpace.s),
          child,
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AlbumSpace.s,
      runSpacing: AlbumSpace.s,
      children: children,
    );
  }
}

/// A range over the loaded decades. A thumb at either end is an open
/// bound, so a story added later in an outer decade still matches.
class _DecadeRange extends StatelessWidget {
  const _DecadeRange({
    required this.filter,
    required this.decades,
    required this.onChanged,
  });

  final TimelineFilter filter;
  final List<int> decades;
  final ValueChanged<TimelineFilter> onChanged;

  int _indexOf(int? decade, int fallback) {
    if (decade == null) return fallback;
    final at = decades.indexWhere((d) => d >= decade);
    return at < 0 ? decades.length - 1 : at;
  }

  @override
  Widget build(BuildContext context) {
    final last = decades.length - 1;
    final from = _indexOf(filter.fromDecade, 0);
    final toDecade = filter.toDecade;
    final to = toDecade == null
        ? last
        : decades.lastIndexWhere((d) => d <= toDecade).clamp(from, last);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${decades[from]}s – ${decades[to]}s',
          key: const Key('filter-decades-label'),
          style: AlbumText.axis(Theme.of(context).textTheme),
        ),
        RangeSlider(
          key: const Key('filter-decades'),
          min: 0,
          max: last.toDouble(),
          divisions: last,
          values: RangeValues(from.toDouble(), to.toDouble()),
          labels: RangeLabels('${decades[from]}s', '${decades[to]}s'),
          onChanged: (range) {
            final start = range.start.round();
            final end = range.end.round();
            onChanged(
              filter.copyWith(
                fromDecade: () => start == 0 ? null : decades[start],
                toDecade: () => end == last ? null : decades[end],
              ),
            );
          },
        ),
      ],
    );
  }
}
