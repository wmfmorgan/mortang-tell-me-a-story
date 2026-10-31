import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/album_chrome.dart';
import '../../core/theme/album_header.dart';
import '../../core/theme/album_theme.dart';
import '../../core/theme/profile_avatar.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import 'all_stories_card.dart';
import 'all_stories_loader.dart';
import 'all_stories_logic.dart';

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

class AllStoriesPage extends StatefulWidget {
  const AllStoriesPage({
    super.key,
    required this.familyId,
    this.storiesApi,
    this.familiesApi,
    this.photosApi,
  });

  final String familyId;
  final StoriesGateway? storiesApi;
  final FamiliesGateway? familiesApi;
  final PhotosGateway? photosApi;

  @override
  State<AllStoriesPage> createState() => _AllStoriesPageState();
}

enum _Phase { loading, ready, error }

class _AllStoriesPageState extends State<AllStoriesPage> {
  final _scroll = ScrollController();
  late final TextEditingController _search;
  late AllStoriesViewState _view;
  Timer? _debounce;
  _Phase _phase = _Phase.loading;
  AllStoriesData? _data;
  Map<String, Uint8List> _thumbs = const {};
  List<MemberFamily> _families = const [];
  List<StewardFamily> _stewarded = const [];
  var _canWrite = false;
  var _scrolledUnder = false;
  var _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _view = AllStoriesSession.of(widget.familyId);
    _search = TextEditingController(text: _view.query);
    _scroll.addListener(_onScroll);
    _load(showLoading: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  StoriesGateway get _stories => widget.storiesApi ?? StoriesApi();

  FamiliesGateway get _familiesApi => widget.familiesApi ?? FamiliesApi();

  void _onScroll() {
    final under = _scroll.hasClients && _scroll.offset > 8;
    if (under == _scrolledUnder || !mounted) return;
    setState(() => _scrolledUnder = under);
  }

  Future<void> _load({required bool showLoading}) async {
    final generation = ++_loadGeneration;
    if (showLoading && mounted) {
      setState(() => _phase = _Phase.loading);
    }
    try {
      final loader = AllStoriesLoader(
        stories: _stories,
        families: _familiesApi,
      );
      final dataFuture = loader.load(widget.familyId);
      final chromeFuture = _loadChrome();
      final data = await dataFuture;
      final chrome = await chromeFuture;
      final thumbs = await _loadThumbs(data.stories);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _data = data;
        _thumbs = thumbs;
        _families = chrome.families;
        _stewarded = chrome.stewarded;
        _canWrite = chrome.canWrite;
        _phase = _Phase.ready;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _phase = _Phase.error);
    }
  }

  /// Header membership is the same best-effort read Landing uses. A menu
  /// failure must not replace a loaded story list with the story error line.
  Future<
    ({
      List<MemberFamily> families,
      List<StewardFamily> stewarded,
      bool canWrite,
    })
  >
  _loadChrome() async {
    try {
      final mine = await _familiesApi.listMine();
      final stewarded = await _familiesApi.listStewarded();
      return (
        families: mine,
        stewarded: stewarded,
        canWrite: mine.any((row) => row.id == widget.familyId),
      );
    } catch (_) {
      return (
        families: const <MemberFamily>[],
        stewarded: const <StewardFamily>[],
        canWrite: false,
      );
    }
  }

  Future<Map<String, Uint8List>> _loadThumbs(List<Story> stories) async {
    final photos = widget.photosApi;
    final out = <String, Uint8List>{};
    for (final story in stories) {
      if (story.photoPaths.isEmpty) continue;
      try {
        final bytes = photos == null
            ? await PhotosApi().downloadBytes(story.photoPaths.first)
            : await photos.downloadBytes(story.photoPaths.first);
        if (bytes.isNotEmpty) out[story.id] = bytes;
      } catch (_) {
        // A missing thumb stays a parchment blank.
      }
    }
    return out;
  }

  void _setView(AllStoriesViewState next) {
    AllStoriesSession.save(widget.familyId, next);
    setState(() => _view = next);
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

  Future<void> _openStory(Story story) async {
    await context.push(AppRoutes.storyPath(story.id));
    if (!mounted) return;
    await _load(showLoading: false);
  }

  void _openBranch(TreeFamily branch) {
    // M12 switches family inside private timeline state. From this route the
    // same outcome is the remembered family plus the timeline route.
    FamilySelection.remember(branch.id);
    context.go(AppRoutes.timeline);
  }

  String _familyName() {
    final data = _data;
    if (data == null) return 'Family';
    for (final row in data.tree) {
      if (row.id == widget.familyId && row.name.trim().isNotEmpty) {
        return row.name;
      }
    }
    return 'Family';
  }

  @override
  Widget build(BuildContext context) {
    final name = _familyName();
    final empty = _phase == _Phase.ready && (_data?.stories.isEmpty ?? true);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      key: const Key('all-stories-page'),
      backgroundColor: albumParchment,
      appBar: AlbumHeader(
        page: AlbumHeaderPage.allStories,
        familyName: name,
        families: _families,
        currentFamilyId: widget.familyId,
        onFamilySelected: FamilySelection.remember,
        stewarded: _stewarded,
        relatedFamilies: [
          for (final row in _data?.tree ?? const <TreeFamily>[])
            if (!_families.any((family) => family.id == row.id)) row,
        ],
        canWrite: _canWrite,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(albumColumnWidth, constraints.maxWidth);
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: CustomScrollView(
                key: const Key('all-stories-scroll'),
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(child: _heading(name)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _PinDelegate(
                      height: _pinHeight(width),
                      showBorder: _scrolledUnder,
                      child: _controls(empty: empty, reduced: reduced),
                    ),
                  ),
                  ..._body(empty: empty, viewport: constraints.maxWidth),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _heading(String name) {
    final label = 'View a Timeline of Stories for $name';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              headingLevel: 1,
              child: Text(
                'All Stories',
                style: GoogleFonts.newsreader(
                  color: albumInk,
                  fontSize: 40,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: OutlinedButton(
              key: const Key('all-stories-timeline'),
              onPressed: () => context.go(AppRoutes.timeline),
              style: OutlinedButton.styleFrom(
                foregroundColor: albumTerracotta,
                backgroundColor: albumParchment,
                side: const BorderSide(color: albumTerracotta),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

  double _pinHeight(double width) {
    final stacked = width < 760;
    final status = _view.query.trim().isNotEmpty || _view.startedTimelineOnly;
    if (stacked) return status ? 400 : 320;
    return status ? 120 : 88;
  }

  Widget _controls({required bool empty, required bool reduced}) {
    final line = _phase == _Phase.ready ? _status() : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final search = _searchField(empty);
              final tail = Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _spawnToggle(empty: empty, reduced: reduced),
                  _groupSwitch(empty: empty, reduced: reduced),
                ],
              );
              if (constraints.maxWidth < 760) {
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

  Widget _searchField(bool empty) {
    return TextField(
      key: const Key('all-stories-search'),
      controller: _search,
      enabled: !empty,
      onChanged: empty ? null : _onQueryChanged,
      onSubmitted: (_) {},
      style: GoogleFonts.sourceSans3(color: albumInk, fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Search titles, story text, and people',
        prefixIcon: const Icon(Icons.search, color: albumInk),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                key: const Key('all-stories-search-clear'),
                onPressed: empty ? null : _clearQuery,
                icon: const Icon(Icons.close, color: albumInk),
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
              ),
        filled: true,
        fillColor: albumParchment,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: albumInk.withValues(alpha: 0.15)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: albumInk.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: albumTerracotta, width: 2),
        ),
      ),
    );
  }

  Widget _spawnToggle({required bool empty, required bool reduced}) {
    final on = _view.startedTimelineOnly;
    final labelColor = on ? albumParchment : albumInk;
    return Semantics(
      key: const Key('all-stories-toggle'),
      button: true,
      toggled: on,
      label: 'Started a timeline',
      onTap: empty ? null : _toggleSpawn,
      child: ExcludeSemantics(
        child: Material(
          color: on ? albumTerracotta : albumParchment,
          shape: StadiumBorder(
            side: BorderSide(
              color: on ? albumTerracotta : albumInk.withValues(alpha: 0.15),
            ),
          ),
          child: InkWell(
            onTap: empty ? null : _toggleSpawn,
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (on)
                      Icon(Icons.check, size: 16, color: labelColor)
                    else
                      _MiniRing(color: albumSage),
                    const SizedBox(width: 8),
                    Text(
                      'Started a timeline',
                      style: GoogleFonts.sourceSans3(
                        color: labelColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupSwitch({required bool empty, required bool reduced}) {
    const labels = {
      AllStoriesGroupBy.date: 'Date',
      AllStoriesGroupBy.member: 'Member',
      AllStoriesGroupBy.place: 'Place',
    };
    return Semantics(
      label: 'Group by',
      explicitChildNodes: true,
      container: true,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Group by',
            style: GoogleFonts.sourceSans3(color: albumInk, fontSize: 14),
          ),
          for (final mode in AllStoriesGroupBy.values)
            Semantics(
              key: Key('all-stories-group-${mode.name}'),
              button: true,
              inMutuallyExclusiveGroup: true,
              selected: _view.groupBy == mode,
              label: labels[mode],
              onTap: empty ? null : () => _setGroup(mode),
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Material(
                    color: _view.groupBy == mode
                        ? albumTerracotta
                        : albumPillFill,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: empty ? null : () => _setGroup(mode),
                      borderRadius: BorderRadius.circular(999),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: reduced
                                  ? Duration.zero
                                  : const Duration(milliseconds: 240),
                              style: GoogleFonts.sourceSans3(
                                color: _view.groupBy == mode
                                    ? albumParchment
                                    : albumInk,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              child: Text(labels[mode]!),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _status() {
    final data = _data;
    if (data == null) return null;
    final marks = spawnMarks(
      familyId: widget.familyId,
      tree: data.tree,
      stories: data.stories,
    );
    final total = data.stories.length;
    var n = 0;
    for (final story in data.stories) {
      final mark = marks[story.id] ?? const SpawnMark();
      if (isUndimmed(story, _view, mark)) n++;
    }
    return statusLine(
      n: n,
      total: total,
      query: _view.query,
      startedTimelineOnly: _view.startedTimelineOnly,
    );
  }

  List<Widget> _body({required bool empty, required double viewport}) {
    if (_phase == _Phase.loading) {
      return [SliverToBoxAdapter(child: _skeleton())];
    }
    if (_phase == _Phase.error) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Row(
              children: [
                Text(
                  "Couldn't load stories.",
                  style: GoogleFonts.sourceSans3(color: albumInk, fontSize: 16),
                ),
                const SizedBox(width: 12),
                TextButton(
                  key: const Key('all-stories-retry'),
                  onPressed: () => _load(showLoading: true),
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
              ],
            ),
          ),
        ),
      ];
    }
    if (empty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text('No stories yet.', style: TextStyle(fontSize: 16)),
          ),
        ),
      ];
    }
    final data = _data!;
    final marks = spawnMarks(
      familyId: widget.familyId,
      tree: data.tree,
      stories: data.stories,
    );
    final groups = groupStories(data.stories, _view.groupBy);
    final columns = allStoriesColumns(viewport);
    final filterActive =
        _view.query.trim().isNotEmpty || _view.startedTimelineOnly;
    final name = _familyName();
    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final group in groups)
              _GroupSection(
                group: group,
                columns: columns,
                marks: marks,
                familyName: name,
                query: _view.query,
                filterActive: filterActive,
                view: _view,
                thumbs: _thumbs,
                onOpen: _openStory,
                onOpenBranch: _openBranch,
              ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    ];
  }

  Widget _skeleton() {
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

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.columns,
    required this.marks,
    required this.familyName,
    required this.query,
    required this.filterActive,
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
  final AllStoriesViewState view;
  final Map<String, Uint8List> thumbs;
  final ValueChanged<Story> onOpen;
  final ValueChanged<TreeFamily> onOpenBranch;

  @override
  Widget build(BuildContext context) {
    final undimmedFlags = [
      for (final story in group.stories)
        isUndimmed(story, view, marks[story.id] ?? const SpawnMark()),
    ];
    final headingDimmed = filterActive && undimmedFlags.every((flag) => !flag);
    final headingColor = headingDimmed ? allStoriesDimInk() : albumInk;
    final count = groupCountLabel(group.stories.length);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            headingLevel: 2,
            child: Row(
              children: [
                if (view.groupBy == AllStoriesGroupBy.member)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ProfileAvatar(size: 32, displayName: group.heading),
                  ),
                if (view.groupBy == AllStoriesGroupBy.place &&
                    group.key != '__none__')
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.location_on,
                      size: 18,
                      color: headingDimmed ? allStoriesDimInk() : albumSage,
                    ),
                  ),
                Flexible(
                  child: Text(
                    group.heading,
                    style: GoogleFonts.newsreader(
                      color: headingColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (group.address != null && group.address!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      group.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sourceSans3(
                        color: headingColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  count,
                  style: GoogleFonts.sourceSans3(
                    color: headingColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
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
                        ? _card(group.stories[i + column])
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

  Widget _card(Story story) {
    final mark = marks[story.id] ?? const SpawnMark();
    return AllStoriesCard(
      story: story,
      mark: mark,
      familyName: familyName,
      query: query,
      filterActive: filterActive,
      undimmed: isUndimmed(story, view, mark),
      thumb: thumbs[story.id],
      onOpen: () => onOpen(story),
      onOpenBranch: onOpenBranch,
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

class _MiniRing extends StatelessWidget {
  const _MiniRing({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }
}

class _PinDelegate extends SliverPersistentHeaderDelegate {
  _PinDelegate({
    required this.child,
    required this.height,
    required this.showBorder,
  });

  final Widget child;
  final double height;
  final bool showBorder;

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
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.showBorder != showBorder ||
        oldDelegate.child != child;
  }
}
