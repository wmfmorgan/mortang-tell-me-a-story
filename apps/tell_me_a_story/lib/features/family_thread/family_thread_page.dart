import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/album_header.dart';
import '../../core/theme/album_theme.dart';
import '../../data/current_session.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/family_thread_density.dart';
import '../../data/family_thread_open_state.dart';
import '../../data/family_thread_open_state_store.dart';
import '../../data/gateway_read.dart';
import '../../data/stories_api.dart';
import '../../data/timeline_live.dart';
import 'density_control.dart';
import 'family_thread_copy.dart';
import 'filter_button.dart';
import 'filter_drawer.dart';
import 'filter_panel.dart';
import 'filter_pills.dart';
import 'insert_published_origin.dart';
import 'thread_beat.dart';
import 'thread_filter.dart';
import 'thread_focus.dart';
import 'thread_skeleton.dart';
import 'thread_view.dart';

const _sidebarBreakpoint = 900.0;
const _sidebarWidth = 280.0;
const _drawerHeightFactor = 0.75;

class FamilyThreadPage extends StatefulWidget {
  const FamilyThreadPage({
    super.key,
    this.storiesApi,
    this.familiesApi,
    this.currentUserId,
    this.openStateStore,
    this.now,
    this.initialFilter = ThreadFilter.cleared,
    required this.live,
  });

  final StoriesGateway? storiesApi;
  final FamiliesGateway? familiesApi;

  /// Signed-in user. Widget tests pass this because [CurrentSession] is null
  /// before Supabase starts. Null means [CurrentSession.userId].
  final String? Function()? currentUserId;

  /// Last density and story for this family. Null uses the device store.
  final FamilyThreadOpenStateStore? openStateStore;

  /// Gap and cooldown clock. Null uses a stopwatch inside the thread.
  final Duration Function()? now;

  /// Filters shown on open. Defaults to cleared. Storage does not restore them.
  final ThreadFilter initialFilter;

  /// Realtime signal. This page disposes [live] from [State.dispose] after it
  /// has subscribed.
  final TimelineLive live;

  @override
  State<FamilyThreadPage> createState() => _FamilyThreadPageState();
}

class _FamilyThreadPageState extends State<FamilyThreadPage> {
  StoriesGateway? _ownedStories;
  FamiliesGateway? _ownedFamilies;
  FamilyThreadOpenStateStore? _ownedStore;
  TimelineLive? _subscribed;
  var _loading = true;
  var _failed = false;
  var _ready = false;
  var _onRoute = false;
  var _announce = false;
  var _member = false;
  var _ticket = 0;
  var _ringToken = 0;
  var _focusRequest = 0;
  var _density = FamilyThreadDensity.browse;
  var _filter = ThreadFilter.cleared;
  var _panelOpen = true;
  var _drawerOpen = false;
  String? _familyId;
  String? _originId;
  String? _focusId;
  DateTime? _focusStart;
  var _familyName = FamilyThreadCopy.fallbackFamily;
  List<MemberFamily> _families = const [];
  List<Story> _stories = const [];

  StoriesGateway get _storiesApi =>
      widget.storiesApi ?? (_ownedStories ??= StoriesApi());

  FamiliesGateway get _familiesApi =>
      widget.familiesApi ?? (_ownedFamilies ??= FamiliesApi());

  FamilyThreadOpenStateStore get _store {
    return widget.openStateStore ??
        (_ownedStore ??= FamilyThreadOpenStateStore(
          currentUserId: () => _sessionUserId,
        ));
  }

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? false;
    final returned = _ready && current && !_onRoute;
    _onRoute = current;
    if (!returned) return;
    _focusRequest += 1;
    _ringToken += 1;
    _reloadStories();
  }

  @override
  void dispose() {
    _subscribed?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    try {
      final opened = await guardRead(_opened);
      if (!mounted || ticket != _ticket) return;
      final member = _inMine(opened.mine, opened.id);
      final storiesFuture = guardRead(
        () => _storiesFor(opened.id, opened.originId),
      );
      final savedFuture = _savedOrForget(opened.id, member);
      final stories = await storiesFuture;
      final saved = await savedFuture;
      if (!mounted || ticket != _ticket) return;
      _show(opened, stories, saved, member);
      _watch(opened.id);
    } on GatewayReadException {
      if (!mounted || ticket != _ticket) return;
      _fail();
    }
  }

  Future<void> _reloadStories() async {
    final familyId = _familyId;
    if (familyId == null || !_ready) return;
    final ticket = ++_ticket;
    try {
      final stories = await guardRead(() => _storiesFor(familyId, _originId));
      if (!mounted || ticket != _ticket) return;
      setState(() => _applyStories(stories));
    } on GatewayReadException {
      if (!mounted || ticket != _ticket) return;
    }
  }

  void _show(
    _Opened opened,
    List<Story> stories,
    FamilyThreadOpenState? saved,
    bool member,
  ) {
    final focus = _focusOf(stories, saved?.storyId, null);
    setState(() {
      _familyId = opened.id;
      _originId = opened.originId;
      _familyName = opened.name;
      _families = opened.mine;
      _loading = false;
      _failed = false;
      _ready = true;
      _member = member;
      _density = saved?.density ?? FamilyThreadDensity.browse;
      _stories = stories;
      _focusId = focus.id;
      _focusStart = focus.start;
      _announce = false;
    });
  }

  void _applyStories(List<Story> stories) {
    _stories = stories;
    final focus = _focusOf(stories, _focusId, _focusStart);
    _focusId = focus.id;
    _focusStart = focus.start;
  }

  void _watch(String? familyId) {
    if (familyId == null) return;
    final live = _subscribed ??= widget.live;
    live.watch(familyId: familyId, onChange: _onLive);
  }

  void _onLive() {
    if (!mounted) return;
    _reloadStories();
  }

  void _fail() {
    setState(() {
      _loading = false;
      _failed = true;
    });
  }

  void _setDensity(FamilyThreadDensity density) {
    if (density == _density) return;
    setState(() {
      _density = density;
      _announce = true;
    });
    _persist();
  }

  void _nudgeDensity(int delta) {
    final next = _density.index + delta;
    if (next < 0 || next >= FamilyThreadDensity.values.length) return;
    _setDensity(FamilyThreadDensity.values[next]);
  }

  String? get _sessionUserId {
    final currentUserId = widget.currentUserId;
    if (currentUserId != null) return currentUserId();
    return CurrentSession.userId;
  }

  Future<_Opened> _opened() async {
    final mine = await _familiesApi.listMine();
    FamilyMembership.remember([for (final row in mine) row.id]);
    final id = await resolveShownFamilyId(
      families: _familiesApi,
      userId: _sessionUserId,
      remembered: FamilySelection.id,
      memberships: mine,
    );
    final tree = id == null
        ? const <TreeFamily>[]
        : await _familiesApi.listFamilyTree(id);
    return (
      id: id,
      name: _nameFor(id, mine, tree),
      mine: mine,
      originId: _originOf(tree, id),
    );
  }

  Future<List<Story>> _storiesFor(String? familyId, String? originId) async {
    if (familyId == null) return const [];
    final rows = await _storiesApi.listPublished(familyId);
    final merged = _published(rows);
    if (originId != null && !merged.any((story) => story.id == originId)) {
      final origin = await _storiesApi.getPublished(originId);
      if (origin != null && origin.status == StoryStatus.published) {
        return insertPublishedOrigin(merged, origin);
      }
    }
    return merged;
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Title(
      title: FamilyThreadCopy.screenTitle,
      color: albumInk,
      child: Scaffold(
        backgroundColor: albumParchment,
        appBar: _ThreadBar(
          familyName: _familyName,
          families: _families,
          familyId: _familyId,
          onFamilySelected: _selectFamily,
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_failed) return _LoadError(onRetry: _retry);
    if (!_loading && _stories.isEmpty) return const _EmptyFamily();
    return LayoutBuilder(
      builder: (context, constraints) => _frame(constraints),
    );
  }

  Widget _frame(BoxConstraints constraints) {
    final sidebar = constraints.maxWidth >= _sidebarBreakpoint;
    final drawer = !sidebar && _drawerOpen;
    // Only the LayoutBuilder knows the width, so the reset is scheduled from build.
    _scheduleDrawerReset(sidebar);
    return Stack(
      children: [
        ExcludeFocus(
          excluding: drawer,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sidebar && _panelOpen) _sidebar(),
              Expanded(child: _loadedColumn(sidebar)),
            ],
          ),
        ),
        if (drawer) _drawer(constraints.maxWidth),
      ],
    );
  }

  void _scheduleDrawerReset(bool sidebar) {
    if (!sidebar || !_drawerOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_drawerOpen) return;
      setState(() => _drawerOpen = false);
    });
  }

  Widget _loadedColumn(bool sidebar) {
    return Column(
      children: [
        _toolbar(sidebar),
        if (_filter.isActive) _pills(),
        if (_announce) _DensityAnnouncement(density: _density),
        Expanded(child: _thread()),
        if (!_loading && _density == FamilyThreadDensity.overview)
          _OverviewCaption(familyName: _familyName),
      ],
    );
  }

  Widget _toolbar(bool sidebar) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= threadPhoneBreakpoint;
        return _ThreadToolbar(
          wide: wide,
          density: _density,
          enabled: !_loading,
          onDensity: _setDensity,
          activeCount: _filter.activeCount,
          countLabel: _countLabel(wide),
          onFilters: () => _toggleFilters(sidebar),
        );
      },
    );
  }

  void _toggleFilters(bool sidebar) {
    setState(() {
      if (sidebar) {
        _panelOpen = !_panelOpen;
        return;
      }
      _drawerOpen = true;
    });
  }

  Widget _sidebar() {
    return SizedBox(
      key: const Key('filter-panel'),
      width: _sidebarWidth,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: albumParchment,
          border: Border(right: BorderSide(color: albumPillBorder)),
        ),
        child: _panel(),
      ),
    );
  }

  Widget _drawer(double width) {
    final count = _filter.countStories(_stories);
    return FilterDrawer(
      key: const Key('filter-drawer'),
      matched: count.n,
      heightFactor: _drawerHeightFactor,
      onClose: _closeDrawer,
      child: _panel(
        countLabel: width < threadPhoneBreakpoint ? _matchCount(count) : null,
        onClose: _closeDrawer,
      ),
    );
  }

  void _closeDrawer() => setState(() => _drawerOpen = false);

  FilterPanel _panel({String? countLabel, VoidCallback? onClose}) {
    return FilterPanel(
      filter: _filter,
      stories: _stories,
      personLabels: _personLabels(_stories),
      placeLabels: _placeLabels(_stories),
      countLabel: countLabel,
      onClose: onClose,
      onChanged: _setFilter,
    );
  }

  Widget _pills() {
    return FilterPills(
      filter: _filter,
      personLabels: _personLabels(_stories),
      placeLabels: _placeLabels(_stories),
      onChanged: _setFilter,
    );
  }

  void _setFilter(ThreadFilter next) {
    setState(() => _filter = next);
  }

  String? _countLabel(bool wide) => wide ? _matchCount() : null;

  String? _matchCount([({int n, int total})? count]) {
    if (_loading || _stories.isEmpty) return null;
    final matched = count ?? _filter.countStories(_stories);
    return FamilyThreadCopy.filterCount(matched.n, matched.total);
  }

  Widget _thread() {
    if (_loading) return const ThreadSkeleton();
    return ThreadView(
      key: const Key('family-thread-loaded'),
      stories: _stories,
      density: _density,
      focusStoryId: _focusId,
      onFocusChanged: _focusStory,
      onDensityDelta: _nudgeDensity,
      now: widget.now,
      ringToken: _ringToken,
      focusRequest: _focusRequest,
      onBeat: _onBeat,
      onCard: _onCard,
      onOpen: () => _openReader(_focusId),
      onMore: _onMore,
    );
  }

  void _selectFamily(String id) {
    FamilySelection.remember(id);
    if (id == _familyId) return;
    setState(() {
      _loading = true;
      _failed = false;
      _ready = false;
      _filter = ThreadFilter.cleared;
    });
    _load();
  }

  void _onBeat(ThreadBeat beat, {required bool focused}) {
    if (!focused) {
      _focusStory(
        ThreadFocus.representative(beat, previousFocusId: _focusId).id,
      );
      return;
    }
    switch (_density) {
      case FamilyThreadDensity.overview:
        _setDensity(FamilyThreadDensity.browse);
      case FamilyThreadDensity.browse:
        _setDensity(FamilyThreadDensity.read);
      case FamilyThreadDensity.read:
        _openReader(_focusId);
    }
  }

  void _onCard(ThreadBeat beat) => _openReader(_cardStory(beat, _focusId).id);

  void _onMore(ThreadBeat beat) {
    switch (beat) {
      case final YearBeat year:
        final card = ThreadFocus.browseCardStory(year, focusId: _focusId);
        final next = ThreadFocus.moreTarget(year, card);
        if (next == null) return;
        _focusStory(next.id);
        _setDensity(FamilyThreadDensity.read);
      case DecadeBeat() || StoryBeat():
        return;
    }
  }

  void _focusStory(String? storyId) {
    final focus = _focusOf(_stories, storyId, null);
    if (focus.id == null || focus.id == _focusId) return;
    setState(() {
      _focusId = focus.id;
      _focusStart = focus.start;
    });
    _persist();
  }

  void _openReader(String? storyId) {
    if (storyId == null) return;
    unawaited(context.push(AppRoutes.storyPath(storyId)));
  }

  void _persist() {
    final familyId = _familyId;
    final storyId = _focusId;
    if (!_member || familyId == null || storyId == null) return;
    unawaited(
      _store.write(
        familyId: familyId,
        state: FamilyThreadOpenState(density: _density, storyId: storyId),
      ),
    );
  }

  Future<FamilyThreadOpenState?> _savedOrForget(String? id, bool member) async {
    if (id == null || !member) {
      if (id != null) await _store.remove(familyId: id);
      return null;
    }
    return _store.read(familyId: id);
  }
}

typedef _Opened = ({
  String? id,
  String name,
  List<MemberFamily> mine,
  String? originId,
});

({String? id, DateTime? start}) _focusOf(
  List<Story> stories,
  String? focusId,
  DateTime? focusStart,
) {
  if (stories.isEmpty) return (id: null, start: null);
  final kept = focusId == null
      ? null
      : stories.where((story) => story.id == focusId).firstOrNull;
  final story =
      kept ??
      (focusStart == null
          ? null
          : ThreadFocus.nearestInTime(stories, focusStart)) ??
      stories.last;
  return (id: story.id, start: story.publishedStart);
}

String _nameFor(String? id, List<MemberFamily> mine, List<TreeFamily> tree) {
  if (id == null) return FamilyThreadCopy.fallbackFamily;
  for (final row in mine) {
    if (row.id == id) return row.name;
  }
  for (final row in tree) {
    if (row.id == id) return row.name;
  }
  return FamilyThreadCopy.fallbackFamily;
}

String? _originOf(List<TreeFamily> tree, String? id) {
  if (id == null) return null;
  for (final row in tree) {
    if (row.id == id) return row.originStoryId;
  }
  return null;
}

bool _inMine(List<MemberFamily> mine, String? id) {
  if (id == null) return false;
  for (final row in mine) {
    if (row.id == id) return true;
  }
  return false;
}

Story _cardStory(ThreadBeat beat, String? focusId) {
  return switch (beat) {
    StoryBeat(:final story) => story,
    YearBeat() => ThreadFocus.browseCardStory(beat, focusId: focusId),
    DecadeBeat() => ThreadFocus.representative(beat, previousFocusId: focusId),
  };
}

Map<String, String> _personLabels(List<Story> stories) {
  final labels = <String, String>{};
  for (final story in stories) {
    for (final person in story.people) {
      final name = person.name.trim();
      if (name.isEmpty) continue;
      labels.putIfAbsent(person.id, () => name);
    }
  }
  return labels;
}

Map<String, String> _placeLabels(List<Story> stories) {
  final labels = <String, String>{};
  for (final story in stories) {
    final id = story.placeId;
    final label = story.placeLabel?.trim();
    if (id == null || label == null || label.isEmpty) continue;
    labels.putIfAbsent(id, () => label);
  }
  return labels;
}

List<Story> _published(Iterable<Story> stories) {
  return [
    for (final story in stories)
      if (story.status == StoryStatus.published) story,
  ];
}

class _ThreadToolbar extends StatelessWidget {
  const _ThreadToolbar({
    required this.wide,
    required this.density,
    required this.enabled,
    required this.onDensity,
    required this.activeCount,
    required this.countLabel,
    required this.onFilters,
  });

  final bool wide;
  final FamilyThreadDensity density;
  final bool enabled;
  final ValueChanged<FamilyThreadDensity> onDensity;
  final int activeCount;
  final String? countLabel;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    final densityControl = DensityControl(
      density: density,
      enabled: enabled,
      onChanged: onDensity,
    );
    if (!wide) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterButton(activeCount: activeCount, onPressed: onFilters),
            const SizedBox(width: 8),
            densityControl,
          ],
        ),
      );
    }
    return Row(
      children: [
        FilterButton(activeCount: activeCount, onPressed: onFilters),
        Expanded(
          child: Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: densityControl),
          ),
        ),
        if (countLabel != null)
          Text(countLabel!, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

class _DensityAnnouncement extends StatelessWidget {
  const _DensityAnnouncement({required this.density});

  final FamilyThreadDensity density;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: FamilyThreadCopy.showingDensity(density),
      child: const SizedBox.shrink(),
    );
  }
}

class _OverviewCaption extends StatelessWidget {
  const _OverviewCaption({required this.familyName});

  final String familyName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Text(
        FamilyThreadCopy.overviewCaption(familyName),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(fontStyle: FontStyle.italic, color: albumInkDim),
      ),
    );
  }
}

class _ThreadBar extends StatelessWidget implements PreferredSizeWidget {
  const _ThreadBar({
    required this.familyName,
    required this.families,
    required this.familyId,
    required this.onFamilySelected,
  });

  final String familyName;
  final List<MemberFamily> families;
  final String? familyId;
  final ValueChanged<String> onFamilySelected;

  @override
  Size get preferredSize => const Size.fromHeight(AlbumHeader.height);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      header: true,
      label: FamilyThreadCopy.screenTitle,
      child: AlbumHeader(
        page: AlbumHeaderPage.timeline,
        familyName: familyName,
        families: families,
        currentFamilyId: familyId,
        onFamilySelected: onFamilySelected,
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(FamilyThreadCopy.loadError, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: albumTerracotta),
              child: const Text(FamilyThreadCopy.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFamily extends StatelessWidget {
  const _EmptyFamily();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(FamilyThreadCopy.emptyFamily, textAlign: TextAlign.center),
      ),
    );
  }
}
