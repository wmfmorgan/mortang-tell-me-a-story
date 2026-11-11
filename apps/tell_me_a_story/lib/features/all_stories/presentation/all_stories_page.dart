import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/widgets/album/album_chrome.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/avatar/profile_avatar.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/session/family_membership.dart';
import 'package:tell_me_a_story/features/all_stories/presentation/all_stories_card.dart';
import 'package:tell_me_a_story/features/all_stories/presentation/all_stories_loader.dart';
import 'package:tell_me_a_story/features/all_stories/presentation/all_stories_logic.dart';

/// Viewport widths for the 3 / 2 / 1 card grid. Landing has no grid
/// breakpoints, so these are the spec-allowed fill.
const allStoriesDesktopWidth = 1200.0;
const allStoriesTabletWidth = 700.0;

/// Same pause M7 uses in `search_page.dart`.
const allStoriesSearchDebounce = Duration(milliseconds: 300);

int allStoriesColumns(double width) {
  if (width >= allStoriesDesktopWidth) return 3;
  if (width >= allStoriesTabletWidth) return 2;
  return 1;
}

class AllStoriesPage extends ConsumerStatefulWidget {
  const AllStoriesPage({super.key, required this.familyId});

  final String familyId;

  @override
  ConsumerState<AllStoriesPage> createState() => _AllStoriesPageState();
}

enum _Phase { loading, ready, error }

class _AllStoriesPageState extends ConsumerState<AllStoriesPage> {
  final _scroll = ScrollController();
  late final TextEditingController _search;
  Timer? _debounce;
  var _scrolledUnder = false;
  var _pinExtent = 88.0;

  @override
  void initState() {
    super.initState();
    // Not during the first build: the header may watch the selection.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(familySelectionProvider.notifier).remember(widget.familyId);
    });
    _search = TextEditingController(text: _view.query);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  AllStoriesViewState get _view =>
      ref.read(allStoriesViewProvider(widget.familyId));

  AsyncValue<AllStoriesPageData> get _page =>
      ref.read(allStoriesPageProvider(widget.familyId));

  /// A retry after an error shows the skeleton again; a reload behind a
  /// loaded list keeps the list until it settles.
  _Phase get _phase {
    final page = _page;
    if (page.isLoading && (!page.hasValue || page.hasError)) {
      return _Phase.loading;
    }
    return page.hasError ? _Phase.error : _Phase.ready;
  }

  AllStoriesData? get _data => _page.value?.data;

  Map<String, Uint8List> get _thumbs =>
      _page.value?.thumbs ?? const <String, Uint8List>{};

  List<MemberFamily> get _families =>
      _page.value?.chrome.families ?? const <MemberFamily>[];

  List<StewardFamily> get _stewarded =>
      _page.value?.chrome.stewarded ?? const <StewardFamily>[];

  bool get _canWrite =>
      _page.value?.chrome.canWrite ??
      ref.read(familyMembershipProvider).canWrite(widget.familyId);

  void _onScroll() {
    final under = _scroll.hasClients && _scroll.offset > 8;
    if (under == _scrolledUnder || !mounted) return;
    setState(() => _scrolledUnder = under);
  }

  void _reload() => ref.invalidate(allStoriesPageProvider(widget.familyId));

  void _reportPinHeight(double height) {
    if (!mounted || (height - _pinExtent).abs() < 0.5) return;
    setState(() => _pinExtent = height);
  }

  void _setView(AllStoriesViewState next) {
    ref.read(allStoriesViewProvider(widget.familyId).notifier).save(next);
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(allStoriesSearchDebounce, () {
      if (!mounted) return;
      _setView(_view.copyWith(query: value));
    });
  }

  void _clearQuery() {
    _debounce?.cancel();
    _search.clear();
    _setView(_view.copyWith(query: ''));
  }

  void _setGroup(AllStoriesGroupBy by) {
    _setView(_view.copyWith(groupBy: by));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _toggleSpawn() {
    _setView(_view.copyWith(startedTimelineOnly: !_view.startedTimelineOnly));
  }

  void _toggleMembers() {
    _setView(_view.copyWith(showMemberPills: !_view.showMemberPills));
  }

  Future<void> _openStory(Story story) async {
    await context.push(AppRoutes.storyPath(story.id));
    if (!mounted) return;
    _reload();
  }

  void _onFamilySelected(String familyId) {
    ref.read(familySelectionProvider.notifier).remember(familyId);
  }

  void _openBranch(TreeFamily branch) {
    _onFamilySelected(branch.id);
    context.go(AppRoutes.timeline);
  }

  String _familyName() {
    final data = _data;
    if (data == null) return 'Family';
    final row = treeFamilyById(data.tree, widget.familyId);
    final name = row?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Family';
  }

  List<TreeFamily> get _relatedFamilies => [
    for (final row in _data?.tree ?? const <TreeFamily>[])
      if (!_families.any((family) => family.id == row.id)) row,
  ];

  Map<String, SpawnMark> _marksFor(AllStoriesData? data) {
    if (data == null) return const <String, SpawnMark>{};
    return spawnMarks(
      familyId: widget.familyId,
      tree: data.tree,
      stories: data.stories,
    );
  }

  Map<String, bool> _undimmedFor(
    AllStoriesData? data,
    Map<String, SpawnMark> marks,
  ) {
    return {
      for (final story in data?.stories ?? const <Story>[])
        story.id: isUndimmed(
          story,
          _view,
          marks[story.id] ?? const SpawnMark(),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(allStoriesViewProvider(widget.familyId));
    ref.watch(allStoriesPageProvider(widget.familyId));
    ref.watch(familyMembershipProvider);
    final data = _data;
    final empty = _phase == _Phase.ready && (data?.stories.isEmpty ?? true);
    final locked = empty || _phase == _Phase.error;
    final marks = _marksFor(data);
    final undimmed = _undimmedFor(data, marks);
    return Scaffold(
      key: const Key('all-stories-page'),
      backgroundColor: albumParchment,
      appBar: AlbumHeader(
        page: AlbumHeaderPage.allStories,
        familyName: _familyName(),
        families: _families,
        currentFamilyId: widget.familyId,
        onFamilySelected: _onFamilySelected,
        stewarded: _stewarded,
        relatedFamilies: _relatedFamilies,
        canWrite: _canWrite,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => _ScrollFrame(
          state: this,
          constraints: constraints,
          controls: _Controls(state: this, locked: locked, undimmed: undimmed),
          body: _Body(
            state: this,
            empty: empty,
            viewport: constraints.maxWidth,
            marks: marks,
            undimmed: undimmed,
          ),
        ),
      ),
    );
  }

  String? _status(Map<String, bool> undimmed) {
    final data = _data;
    if (data == null) return null;
    var n = 0;
    for (final shown in undimmed.values) {
      if (shown) n++;
    }
    return statusLine(
      n: n,
      total: data.stories.length,
      query: _view.query,
      startedTimelineOnly: _view.startedTimelineOnly,
    );
  }
}

/// Centred column with the heading, the pinned controls and the body.
class _ScrollFrame extends StatelessWidget {
  const _ScrollFrame({
    required this.state,
    required this.constraints,
    required this.controls,
    required this.body,
  });

  final _AllStoriesPageState state;
  final BoxConstraints constraints;
  final Widget controls;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final width = math.min(albumColumnWidth, constraints.maxWidth);
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        height: constraints.maxHeight,
        child: CustomScrollView(
          key: const Key('all-stories-scroll'),
          controller: state._scroll,
          slivers: [
            const SliverToBoxAdapter(child: _Heading()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinDelegate(
                height: state._pinExtent,
                showBorder: state._scrolledUnder,
                onHeight: state._reportPinHeight,
                child: controls,
              ),
            ),
            body,
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.locked,
    required this.undimmed,
  });

  final _AllStoriesPageState state;
  final bool locked;
  final Map<String, bool> undimmed;

  @override
  Widget build(BuildContext context) {
    final line = state._phase == _Phase.ready ? state._status(undimmed) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final search = _SearchField(state: state, locked: locked);
              final tail = _ControlToggles(state: state, locked: locked);
              if (constraints.maxWidth < _stackedControlsWidth) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [search, const SizedBox(height: 8), tail],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 12),
                  tail,
                ],
              );
            },
          ),
          if (line != null) ...[
            const SizedBox(height: 8),
            Semantics(
              key: const Key('all-stories-status'),
              liveRegion: true,
              child: Text(
                line,
                style: GoogleFonts.sourceSans3(color: albumInk, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlToggles extends StatelessWidget {
  const _ControlToggles({required this.state, required this.locked});

  final _AllStoriesPageState state;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final view = state._view;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PillToggle(
          semanticsKey: const Key('all-stories-members'),
          label: 'Members',
          on: view.showMemberPills,
          locked: locked,
          onToggle: state._toggleMembers,
        ),
        _PillToggle(
          semanticsKey: const Key('all-stories-toggle'),
          label: 'Started a timeline',
          on: view.startedTimelineOnly,
          locked: locked,
          onToggle: state._toggleSpawn,
        ),
        _GroupBySwitch(
          selected: view.groupBy,
          enabled: !locked,
          onChanged: state._setGroup,
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.state, required this.locked});

  final _AllStoriesPageState state;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final quiet = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: albumInk.withValues(alpha: 0.15)),
    );
    return TextField(
      key: const Key('all-stories-search'),
      controller: state._search,
      enabled: !locked,
      onChanged: locked ? null : state._onQueryChanged,
      style: GoogleFonts.sourceSans3(color: albumInk, fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Search titles, story text, and people',
        prefixIcon: const Icon(Icons.search, color: albumInk),
        suffixIcon: state._search.text.isEmpty
            ? null
            : _SearchClear(onClear: locked ? null : state._clearQuery),
        filled: true,
        fillColor: albumParchment,
        enabledBorder: quiet,
        disabledBorder: quiet,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: albumTerracotta, width: 2),
        ),
      ),
    );
  }
}

class _SearchClear extends StatelessWidget {
  const _SearchClear({required this.onClear});

  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return AllStoriesFocusTarget(
      radius: 22,
      childBuilder: (node) => IconButton(
        key: const Key('all-stories-search-clear'),
        focusNode: node,
        onPressed: onClear,
        icon: const Icon(Icons.close, color: albumInk),
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      ),
    );
  }
}

/// The one sliver under the pinned controls for the current phase.
class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.empty,
    required this.viewport,
    required this.marks,
    required this.undimmed,
  });

  final _AllStoriesPageState state;
  final bool empty;
  final double viewport;
  final Map<String, SpawnMark> marks;
  final Map<String, bool> undimmed;

  @override
  Widget build(BuildContext context) {
    if (state._phase == _Phase.loading) {
      return const SliverToBoxAdapter(child: _Skeleton());
    }
    if (state._phase == _Phase.error) {
      return SliverToBoxAdapter(child: _LoadError(onRetry: state._reload));
    }
    if (empty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'No stories yet.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    if (state._data case final data?) {
      return SliverToBoxAdapter(
        child: _Groups(
          state: state,
          data: data,
          viewport: viewport,
          marks: marks,
          undimmed: undimmed,
        ),
      );
    }
    // Ready with no data never happens; an empty adapter takes no space.
    return const SliverToBoxAdapter();
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        children: [
          Text(
            "Couldn't load stories.",
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(width: 12),
          AllStoriesFocusTarget(
            radius: 20,
            childBuilder: (node) => TextButton(
              key: const Key('all-stories-retry'),
              focusNode: node,
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: albumTerracotta),
              child: Text(
                'Retry',
                style: GoogleFonts.sourceSans3(
                  color: albumTerracotta,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Groups extends StatelessWidget {
  const _Groups({
    required this.state,
    required this.data,
    required this.viewport,
    required this.marks,
    required this.undimmed,
  });

  final _AllStoriesPageState state;
  final AllStoriesData data;
  final double viewport;
  final Map<String, SpawnMark> marks;
  final Map<String, bool> undimmed;

  @override
  Widget build(BuildContext context) {
    final view = state._view;
    final columns = allStoriesColumns(viewport);
    final name = state._familyName();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groupStories(data.stories, view.groupBy))
          _GroupSection(
            group: group,
            columns: columns,
            marks: marks,
            familyName: name,
            query: view.query,
            filterActive: view.filterActive,
            undimmed: undimmed,
            view: view,
            thumbs: state._thumbs,
            onOpen: state._openStory,
            onOpenBranch: state._openBranch,
          ),
        const SizedBox(height: 48),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 16),
      child: Semantics(
        header: true,
        headingLevel: 1,
        child: Text(
          key: const Key('all-stories-heading'),
          'Stories',
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 40,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      key: Key('all-stories-skeleton'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8),
        _Bar(width: 120, height: 18),
        SizedBox(height: 16),
        _Bar(width: double.infinity, height: 140),
        SizedBox(height: 8),
        _Bar(width: 180, height: 14),
        SizedBox(height: 8),
        _Bar(width: 120, height: 14),
      ],
    );
  }
}

/// Members / Started a timeline filter pill.
class _PillToggle extends StatelessWidget {
  const _PillToggle({
    required this.semanticsKey,
    required this.label,
    required this.on,
    required this.locked,
    required this.onToggle,
  });

  final Key semanticsKey;
  final String label;
  final bool on;
  final bool locked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final labelColor = locked
        ? albumInk.withValues(alpha: 0.38)
        : on
        ? albumParchment
        : albumInk;
    return Semantics(
      key: semanticsKey,
      button: true,
      enabled: !locked,
      toggled: on,
      label: label,
      onTap: locked ? null : onToggle,
      child: AllStoriesFocusTarget(
        radius: 999,
        childBuilder: (node) => ExcludeSemantics(
          child: Material(
            color: on ? albumTerracotta : albumParchment,
            shape: StadiumBorder(
              side: BorderSide(
                color: on ? albumTerracotta : albumInk.withValues(alpha: 0.15),
              ),
            ),
            child: InkWell(
              focusNode: node,
              onTap: locked ? null : onToggle,
              customBorder: const StadiumBorder(),
              child: _PillLabel(label: label, color: labelColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.sourceSans3(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.columns,
    required this.marks,
    required this.familyName,
    required this.query,
    required this.filterActive,
    required this.undimmed,
    required this.view,
    required this.thumbs,
    required this.onOpen,
    required this.onOpenBranch,
  });

  final StoryGroup group;
  final int columns;
  final Map<String, SpawnMark> marks;
  final String familyName;
  final String query;
  final bool filterActive;
  final Map<String, bool> undimmed;
  final AllStoriesViewState view;
  final Map<String, Uint8List> thumbs;
  final ValueChanged<Story> onOpen;
  final ValueChanged<TreeFamily> onOpenBranch;

  @override
  Widget build(BuildContext context) {
    final headingDimmed =
        filterActive &&
        group.stories.every((story) => undimmed[story.id] != true);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupHeading(
            group: group,
            groupBy: view.groupBy,
            dimmed: headingDimmed,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < group.stories.length; i += columns) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: 24),
                  Expanded(
                    child: i + column < group.stories.length
                        ? _GroupCell(
                            section: this,
                            story: group.stories[i + column],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

class _GroupCell extends StatelessWidget {
  const _GroupCell({required this.section, required this.story});

  final _GroupSection section;
  final Story story;

  @override
  Widget build(BuildContext context) {
    return AllStoriesCard(
      story: story,
      mark: section.marks[story.id] ?? const SpawnMark(),
      familyName: section.familyName,
      query: section.query,
      filterActive: section.filterActive,
      undimmed: section.undimmed[story.id] ?? true,
      showMembers: section.view.showMemberPills,
      thumb: section.thumbs[story.id],
      onOpen: () => section.onOpen(story),
      onOpenBranch: section.onOpenBranch,
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading({
    required this.group,
    required this.groupBy,
    required this.dimmed,
  });

  final StoryGroup group;
  final AllStoriesGroupBy groupBy;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final headingColor = dimmed ? allStoriesDimInk() : albumInk;
    final address = group.address?.trim();
    final showAddress =
        address != null && address.isNotEmpty && address != group.heading;
    final small = GoogleFonts.sourceSans3(color: headingColor, fontSize: 14);
    return Semantics(
      header: true,
      headingLevel: 2,
      child: Row(
        children: [
          if (groupBy == AllStoriesGroupBy.member && !group.isNone)
            _MemberAvatar(name: group.heading),
          if (groupBy == AllStoriesGroupBy.place && !group.isNone)
            _PlacePin(dimmed: dimmed),
          _GroupTitle(text: group.heading, color: headingColor),
          if (showAddress) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: small,
              ),
            ),
          ],
          const SizedBox(width: 8),
          Text(groupCountLabel(group.stories.length), style: small),
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ProfileAvatar(size: 32, displayName: name),
    );
  }
}

class _PlacePin extends StatelessWidget {
  const _PlacePin({required this.dimmed});

  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(
        Icons.location_on,
        size: 18,
        color: dimmed ? allStoriesDimInk() : albumSage,
      ),
    );
  }
}

/// Flexible group heading text; must sit directly in the heading [Row].
class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.newsreader(
          color: color,
          fontSize: 28,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: albumPillFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: albumPillBorder),
      ),
    );
  }
}

class _PinDelegate extends SliverPersistentHeaderDelegate {
  _PinDelegate({
    required this.child,
    required this.height,
    required this.showBorder,
    required this.onHeight,
  });

  final Widget child;
  final double height;
  final bool showBorder;
  final ValueChanged<double> onHeight;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumParchment,
        border: showBorder
            ? Border(bottom: BorderSide(color: albumInk.withValues(alpha: 0.1)))
            : null,
      ),
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 0,
        maxHeight: double.infinity,
        child: _PinMeasure(onHeight: onHeight, child: child),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.showBorder != showBorder ||
        oldDelegate.child != child;
  }
}

class _PinMeasure extends SingleChildRenderObjectWidget {
  const _PinMeasure({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPinMeasure(onHeight);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPinMeasure renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderPinMeasure extends RenderProxyBox {
  _RenderPinMeasure(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final next = size.height;
    if (_reported == next) return;
    _reported = next;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(next));
  }
}

const _stackedControlsWidth = 900.0;

class _GroupBySwitch extends StatefulWidget {
  const _GroupBySwitch({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final AllStoriesGroupBy selected;
  final bool enabled;
  final ValueChanged<AllStoriesGroupBy> onChanged;

  @override
  State<_GroupBySwitch> createState() => _GroupBySwitchState();
}

class _GroupBySwitchState extends State<_GroupBySwitch> {
  final _keys = [for (final _ in AllStoriesGroupBy.values) GlobalKey()];
  var _left = 0.0;
  var _width = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readWidths());
  }

  @override
  void didUpdateWidget(covariant _GroupBySwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _readWidths());
  }

  void _readWidths() {
    if (!mounted) return;
    final index = AllStoriesGroupBy.values.indexOf(widget.selected);
    var cursor = 0.0;
    var left = 0.0;
    var width = 0.0;
    for (var i = 0; i < _keys.length; i++) {
      final size = _keys[i].currentContext?.size;
      if (size == null) return;
      if (i == index) {
        left = cursor;
        width = size.width;
      }
      cursor += size.width;
    }
    if ((left - _left).abs() < 0.5 && (width - _width).abs() < 0.5) return;
    setState(() {
      _left = left;
      _width = width;
    });
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = widget.enabled
        ? albumInk
        : albumInk.withValues(alpha: 0.38);
    return Semantics(
      label: 'Group by',
      explicitChildNodes: true,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Group by',
            style: GoogleFonts.sourceSans3(color: labelColor, fontSize: 14),
          ),
          const SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: albumPillFill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Stack(
              children: [
                if (_width > 0) _GroupByIndicator(left: _left, width: _width),
                _GroupByOptions(
                  keys: _keys,
                  selected: widget.selected,
                  enabled: widget.enabled,
                  labelColor: labelColor,
                  onChanged: widget.onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupByOptions extends StatelessWidget {
  const _GroupByOptions({
    required this.keys,
    required this.selected,
    required this.enabled,
    required this.labelColor,
    required this.onChanged,
  });

  final List<GlobalKey> keys;
  final AllStoriesGroupBy selected;
  final bool enabled;
  final Color labelColor;
  final ValueChanged<AllStoriesGroupBy> onChanged;

  @override
  Widget build(BuildContext context) {
    const modes = AllStoriesGroupBy.values;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < modes.length; i++)
          KeyedSubtree(
            key: keys[i],
            child: _GroupByOption(
              mode: modes[i],
              selected: selected == modes[i],
              enabled: enabled,
              labelColor: labelColor,
              onChanged: onChanged,
            ),
          ),
      ],
    );
  }
}

String _groupByLabel(AllStoriesGroupBy mode) {
  return switch (mode) {
    AllStoriesGroupBy.date => 'Date',
    AllStoriesGroupBy.member => 'Member',
    AllStoriesGroupBy.place => 'Place',
  };
}

/// Sliding terracotta stadium under the selected option.
class _GroupByIndicator extends StatelessWidget {
  const _GroupByIndicator({required this.left, required this.width});

  final double left;
  final double width;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: allStoriesMotionOf(context),
      curve: Curves.easeOutCubic,
      left: left,
      width: width,
      top: 0,
      bottom: 0,
      child: const DecoratedBox(
        decoration: ShapeDecoration(
          color: albumTerracotta,
          shape: StadiumBorder(),
        ),
      ),
    );
  }
}

class _GroupByOption extends StatelessWidget {
  const _GroupByOption({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.labelColor,
    required this.onChanged,
  });

  final AllStoriesGroupBy mode;
  final bool selected;
  final bool enabled;
  final Color labelColor;
  final ValueChanged<AllStoriesGroupBy> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: Key('all-stories-group-${mode.name}'),
      button: true,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: _groupByLabel(mode),
      child: AllStoriesFocusTarget(
        radius: 999,
        childBuilder: (node) => InkWell(
          focusNode: node,
          onTap: enabled ? () => onChanged(mode) : null,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  _groupByLabel(mode),
                  style: GoogleFonts.sourceSans3(
                    color: selected ? albumParchment : labelColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
