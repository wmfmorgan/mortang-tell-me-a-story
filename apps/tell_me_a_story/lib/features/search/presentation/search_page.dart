import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/domain/display_name.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_chrome.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date.dart';
import 'package:tell_me_a_story/features/people/presentation/person_profile_dialog.dart';
import 'package:tell_me_a_story/features/search/domain/search_facets.dart';
import 'package:tell_me_a_story/features/search/domain/search_repository.dart';
import 'package:tell_me_a_story/features/search/domain/search_request.dart';
import 'package:tell_me_a_story/features/search/domain/search_sort.dart';
import 'package:tell_me_a_story/features/search/presentation/search_providers.dart';
import 'package:tell_me_a_story/features/search/presentation/search_recents.dart';

const _noMatches = 'No stories match. Try another person, place, or time.';
const _searchingCopy = 'Searching the album…';

TextStyle _sectionTitleStyle() => GoogleFonts.newsreader(
  color: albumInk,
  fontSize: 20,
  fontWeight: FontWeight.w700,
);

TextStyle _dialogTitleStyle() => GoogleFonts.newsreader(
  color: albumInk,
  fontSize: 24,
  fontWeight: FontWeight.w600,
);

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _field = TextEditingController();
  final _fieldFocus = FocusNode();

  Timer? _debounce;
  List<Story> _results = const [];
  final _personIds = <String>[];
  String? _placeId;
  final _decades = <int>[];
  var _sort = SearchSort.relevant;
  var _searching = false;
  var _retrying = false;
  var _searchGen = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  bool get _active =>
      _field.text.trim().isNotEmpty ||
      _personIds.isNotEmpty ||
      _placeId != null ||
      _decades.isNotEmpty;

  SearchFacets get _facets =>
      ref.read(searchScopeProvider).value?.facets ?? const SearchFacets();

  void _onScope(
    AsyncValue<SearchScope>? previous,
    AsyncValue<SearchScope> next,
  ) {
    if (next.isLoading) return;
    if (next.hasError) _showTryAgain();
    if (_retrying) {
      _retrying = false;
      if (_active) _runSearch();
    }
  }

  void _showTryAgain() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Try again'),
        action: SnackBarAction(label: 'Try again', onPressed: _retry),
      ),
    );
  }

  void _retry() {
    _retrying = true;
    ref.invalidate(searchScopeProvider);
  }

  void _onTextChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  void _submit(String value) {
    ref.read(searchRecentsProvider.notifier).remember(value);
    _debounce?.cancel();
    _runSearch();
  }

  void _useRecent(String query) {
    _field.text = query;
    _field.selection = TextSelection.collapsed(offset: query.length);
    _submit(query);
  }

  Future<void> _runSearch() async {
    final gen = ++_searchGen;
    final familyId = ref.read(searchScopeProvider).value?.familyId;
    if (!_active || familyId == null) {
      if (mounted && gen == _searchGen) {
        setState(() {
          _results = const [];
          _searching = false;
        });
      }
      return;
    }
    final request = SearchRequest(
      familyId: familyId,
      text: _field.text,
      personIds: List<String>.from(_personIds),
      placeId: _placeId,
      decades: List<int>.from(_decades),
      sort: _sort,
    );
    setState(() => _searching = true);
    await _fetch(request, gen);
  }

  Future<void> _fetch(SearchRequest request, int gen) async {
    try {
      final rows = await ref.read(searchRepositoryProvider).search(request);
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _results = rows;
        _searching = false;
      });
    } catch (_) {
      // Any failure is shown as the Try again snackbar.
      if (!mounted || gen != _searchGen) return;
      setState(() => _searching = false);
      _showTryAgain();
    }
  }

  void _clearText() {
    _field.clear();
    _onTextChanged('');
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchGen++;
    _field.clear();
    setState(() {
      _personIds.clear();
      _placeId = null;
      _decades.clear();
      _sort = SearchSort.relevant;
      _results = const [];
      _searching = false;
    });
  }

  void _update(VoidCallback change) {
    setState(change);
    _debounce?.cancel();
    _runSearch();
  }

  void _addPerson(String id) {
    if (_personIds.contains(id)) return;
    _update(() => _personIds.add(id));
  }

  void _setPlace(String id) => _update(() => _placeId = id);

  void _addDecade(int startYear) {
    if (_decades.contains(startYear)) return;
    _update(() => _decades.add(startYear));
  }

  void _removePerson(String id) {
    setState(() => _personIds.remove(id));
    _runSearch();
  }

  void _removePlace() {
    setState(() => _placeId = null);
    _runSearch();
  }

  void _removeDecades() {
    setState(() => _decades.clear());
    _runSearch();
  }

  void _setSort(SearchSort value) {
    setState(() => _sort = value);
    _runSearch();
  }

  Future<void> _pickPerson() async {
    final available = _facets.people
        .where((p) => !_personIds.contains(p.id))
        .toList();
    final picked = await showAlbumDialog<String>(
      context: context,
      maxWidth: 420,
      builder: (context) => _PickPersonDialog(available: available),
    );
    if (picked != null) _addPerson(picked);
  }

  Future<void> _pickDecade() async {
    final decades = [
      for (final decade in _facets.decades)
        if (!_decades.contains(decade)) decade,
    ];
    final picked = await showAlbumDialog<int>(
      context: context,
      maxWidth: 420,
      builder: (context) => _PickDecadeDialog(decades: decades),
    );
    if (picked != null) _addDecade(picked);
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.timeline);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(searchScopeProvider, _onScope);
    final scope = ref.watch(searchScopeProvider);
    final facets = scope.value?.facets ?? const SearchFacets();
    return Scaffold(
      backgroundColor: albumParchment,
      body: SafeArea(
        child: Column(
          children: [
            _SearchHeader(
              field: _SearchField(
                controller: _field,
                focusNode: _fieldFocus,
                onChanged: _onTextChanged,
                onSubmitted: _submit,
                onClear: _clearText,
              ),
              filters: _filterBar(facets),
              onClose: _close,
            ),
            Expanded(
              child: _SearchBody(
                busy: scope.isLoading || _searching,
                results: _active ? _resultsView() : null,
                recents: _RecentSection(onUse: _useRecent),
                suggested: _suggested(facets),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _FilterBar _filterBar(SearchFacets facets) => _FilterBar(
    facets: facets,
    personIds: _personIds,
    placeId: _placeId,
    decades: _decades,
    actions: (
      removePerson: _removePerson,
      removePlace: _removePlace,
      removeDecades: _removeDecades,
      pickPerson: _pickPerson,
      pickDecade: _pickDecade,
      clear: _clearFilters,
    ),
  );

  _ResultsView _resultsView() => _ResultsView(
    results: _results,
    searching: _searching,
    sort: _sort,
    onSort: _setSort,
  );

  _SuggestedSection _suggested(SearchFacets facets) => _SuggestedSection(
    people: facets.people.where((p) => !_personIds.contains(p.id)).toList(),
    places: facets.places.where((p) => p.id != _placeId).toList(),
    decades: facets.decades.where((y) => !_decades.contains(y)).toList(),
    onPerson: _addPerson,
    onPlace: _setPlace,
    onDecade: _addDecade,
  );
}

typedef _FilterActions = ({
  void Function(String id) removePerson,
  VoidCallback removePlace,
  VoidCallback removeDecades,
  VoidCallback pickPerson,
  VoidCallback pickDecade,
  VoidCallback clear,
});

class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.busy,
    required this.results,
    required this.recents,
    required this.suggested,
  });

  final bool busy;
  final Widget? results;
  final Widget recents;
  final Widget suggested;

  @override
  Widget build(BuildContext context) {
    final results = this.results;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            if (busy)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _searchingCopy,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ?results,
            const SizedBox(height: 28),
            recents,
            const SizedBox(height: 24),
            suggested,
          ],
        ),
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.results,
    required this.searching,
    required this.sort,
    required this.onSort,
  });

  final List<Story> results;
  final bool searching;
  final SearchSort sort;
  final ValueChanged<SearchSort> onSort;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultsHeader(count: results.length, sort: sort, onSort: onSort),
        if (!searching && results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              _noMatches,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        if (results.isNotEmpty) _ResultsGrid(results: results),
      ],
    );
  }
}

class _PickPersonDialog extends StatelessWidget {
  const _PickPersonDialog({required this.available});

  final List<({String id, String name})> available;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add Person', style: _dialogTitleStyle()),
          const SizedBox(height: 12),
          available.isEmpty
              ? const Text('No more people in this family.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final person in available)
                      ListTile(
                        title: Text(person.name),
                        onTap: () => Navigator.pop(context, person.id),
                      ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _PickDecadeDialog extends StatelessWidget {
  const _PickDecadeDialog({required this.decades});

  final List<int> decades;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Decade', style: _dialogTitleStyle()),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final decade in decades)
                TextButton(
                  onPressed: () => Navigator.pop(context, decade),
                  child: Text('${decade}s'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.field,
    required this.filters,
    required this.onClose,
  });

  final Widget field;
  final Widget filters;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: albumParchment,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Tell Me a Story',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.newsreader(
                    color: albumInk,
                    fontSize: 24,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: field),
                const SizedBox(width: 8),
                TextButton(
                  key: const Key('search-close'),
                  onPressed: onClose,
                  child: const Text('Close'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            filters,
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('search-field'),
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: GoogleFonts.literata(color: albumInk),
      decoration: InputDecoration(
        hintText: 'Search stories by person, place, or time…',
        prefixIcon: const Icon(Icons.search, color: albumTerracotta),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                key: const Key('search-clear-text'),
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.facets,
    required this.personIds,
    required this.placeId,
    required this.decades,
    required this.actions,
  });

  final SearchFacets facets;
  final List<String> personIds;
  final String? placeId;
  final List<int> decades;
  final _FilterActions actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const _FiltersLabel(),
              for (final filter in _activeFilters())
                _FilterChip(
                  key: filter.key,
                  label: filter.label,
                  onRemove: filter.onRemove,
                ),
              _AddPill(
                key: const Key('search-add-person'),
                label: 'Add Person',
                onTap: actions.pickPerson,
              ),
              if (facets.decades.any((year) => !decades.contains(year)))
                _AddPill(
                  key: const Key('search-add-decade'),
                  label: 'Decade',
                  onTap: actions.pickDecade,
                ),
            ],
          ),
        ),
        TextButton(
          key: const Key('search-clear'),
          onPressed: actions.clear,
          child: const Text('Clear filters'),
        ),
      ],
    );
  }

  /// Person chips, then place, then decades.
  List<({Key key, String label, VoidCallback onRemove})> _activeFilters() {
    final placeId = this.placeId;
    return [
      for (final id in personIds)
        (
          key: Key('search-filter-person-$id'),
          label: _personName(id),
          onRemove: () => actions.removePerson(id),
        ),
      if (placeId != null)
        (
          key: const Key('search-filter-place'),
          label: _placeLabel(placeId),
          onRemove: actions.removePlace,
        ),
      if (decades.isNotEmpty)
        (
          key: const Key('search-filter-decade'),
          label: decadeChipLabel(decades),
          onRemove: actions.removeDecades,
        ),
    ];
  }

  String _personName(String id) {
    for (final person in facets.people) {
      if (person.id == id) return person.name;
    }
    return 'Person';
  }

  String _placeLabel(String id) {
    for (final place in facets.places) {
      if (place.id == id) return place.label;
    }
    return 'Place';
  }
}

class _FiltersLabel extends StatelessWidget {
  const _FiltersLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Filters:',
      style: GoogleFonts.sourceSans3(
        color: albumInk.withValues(alpha: 0.6),
        fontSize: 12,
        letterSpacing: 1,
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.count,
    required this.sort,
    required this.onSort,
  });

  final int count;
  final SearchSort sort;
  final ValueChanged<SearchSort> onSort;

  @override
  Widget build(BuildContext context) {
    final noun = count == 1 ? 'result' : 'results';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Matching Archive Stories ($count $noun)',
              style: GoogleFonts.newsreader(
                color: albumInk,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text('Sort by:', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 8),
          _SortMenu(sort: sort, onSort: onSort),
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, required this.onSort});

  final SearchSort sort;
  final ValueChanged<SearchSort> onSort;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<SearchSort>(
      key: const Key('search-sort'),
      value: sort,
      items: const [
        DropdownMenuItem(
          value: SearchSort.relevant,
          child: Text('Most Relevant'),
        ),
        DropdownMenuItem(
          value: SearchSort.chronological,
          child: Text('Chronological'),
        ),
        DropdownMenuItem(
          value: SearchSort.recentlyAdded,
          child: Text('Recently Added'),
        ),
      ],
      onChanged: (value) {
        if (value != null) onSort(value);
      },
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  const _ResultsGrid({required this.results});

  final List<Story> results;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 700
            ? 2
            : 1;
        const gap = 16.0;
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final story in results)
              SizedBox(
                width: width,
                child: _ResultCard(
                  story: story,
                  onOpen: () => context.push(AppRoutes.storyPath(story.id)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecentSection extends ConsumerWidget {
  const _RecentSection({required this.onUse});

  final ValueChanged<String> onUse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queries = ref.watch(searchRecentsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Searches', style: _sectionTitleStyle()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final query in queries)
              ActionChip(label: Text(query), onPressed: () => onUse(query)),
          ],
        ),
      ],
    );
  }
}

class _SuggestedSection extends StatelessWidget {
  const _SuggestedSection({
    required this.people,
    required this.places,
    required this.decades,
    required this.onPerson,
    required this.onPlace,
    required this.onDecade,
  });

  final List<({String id, String name})> people;
  final List<({String id, String label})> places;
  final List<int> decades;
  final ValueChanged<String> onPerson;
  final ValueChanged<String> onPlace;
  final ValueChanged<int> onDecade;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SuggestGroup(
          title: 'Family Members',
          children: [
            for (final person in people)
              ActionChip(
                key: Key('search-suggest-person-${person.id}'),
                avatar: const Icon(Icons.person, size: 18),
                label: Text(person.name),
                onPressed: () => onPerson(person.id),
              ),
          ],
        ),
        _SuggestGroup(
          title: 'Places',
          children: [
            for (final place in places)
              ActionChip(
                key: Key('search-suggest-place-${place.id}'),
                avatar: const Icon(Icons.place, size: 18),
                label: Text(place.label),
                onPressed: () => onPlace(place.id),
              ),
          ],
        ),
        _SuggestGroup(
          title: 'Decades',
          children: [
            for (final year in decades)
              ActionChip(
                key: Key('search-suggest-decade-$year'),
                label: Text('${year}s'),
                onPressed: () => onDecade(year),
              ),
          ],
        ),
      ],
    );
  }
}

class _SuggestGroup extends StatelessWidget {
  const _SuggestGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _sectionTitleStyle()),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({super.key, required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumTerracotta,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: GoogleFonts.sourceSans3(color: albumParchment)),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16, color: albumParchment),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPill extends StatelessWidget {
  const _AddPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 16),
      label: Text(label),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.story, required this.onOpen});

  final Story story;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final year = storyDateLabelFor(story);
    final photoPath = story.photoPaths.isEmpty ? null : story.photoPaths.first;
    return Material(
      key: Key('search-result-${story.id}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photoPath != null)
              _PhotoWell(path: photoPath, year: year, storyId: story.id)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _YearBadge(year: year, storyId: story.id),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _ResultText(story: story, onOpen: onOpen),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultText extends StatelessWidget {
  const _ResultText({required this.story, required this.onOpen});

  final Story story;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final title = storedStoryTitle(story.title);
    final body = (story.body ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResultTags(story: story),
        if (title != null) ...[
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.newsreader(
              color: albumInk,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (body.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.literata(
              color: albumInk.withValues(alpha: 0.75),
              fontSize: 14,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Added by ${displayNameOrMember(story.authorDisplayName)}',
          style: GoogleFonts.sourceSans3(color: albumInk),
        ),
        TextButton(onPressed: onOpen, child: const Text('Read Story →')),
      ],
    );
  }
}

class _ResultTags extends StatelessWidget {
  const _ResultTags({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final people = story.people.isNotEmpty
        ? story.people
        : [for (final name in story.personNames) (id: '', name: name)];
    final placeLabel = story.placeLabel ?? '';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final person in people)
          PersonNamePill(
            personId: person.id,
            name: person.name,
            child: _QuietOrFilledChip(
              key: Key('search-card-person-${person.name}'),
              label: person.name,
              filled: true,
            ),
          ),
        if (placeLabel.isNotEmpty)
          _QuietOrFilledChip(
            key: Key('search-card-place-$placeLabel'),
            label: placeLabel,
            filled: false,
          ),
      ],
    );
  }
}

class _PhotoWell extends ConsumerWidget {
  const _PhotoWell({
    required this.path,
    required this.year,
    required this.storyId,
  });

  final String path;
  final String year;
  final String storyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A failed or pending download shows the year badge alone.
    final bytes = ref.watch(searchPhotoBytesProvider(path)).value;
    if (bytes == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: _YearBadge(year: year, storyId: storyId),
      );
    }
    return SizedBox(
      key: Key('search-photo-$storyId'),
      height: 180,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: _YearBadge(year: year, storyId: storyId),
          ),
        ],
      ),
    );
  }
}

class _YearBadge extends StatelessWidget {
  const _YearBadge({required this.year, required this.storyId});

  final String year;
  final String storyId;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: Key('search-year-$storyId'),
      decoration: BoxDecoration(
        color: albumParchment.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(year, style: GoogleFonts.sourceSans3(color: albumInk)),
      ),
    );
  }
}

class _QuietOrFilledChip extends StatelessWidget {
  const _QuietOrFilledChip({
    super.key,
    required this.label,
    required this.filled,
  });

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? albumTerracotta : albumInk.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: GoogleFonts.sourceSans3(
            color: filled ? albumParchment : albumInk,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
