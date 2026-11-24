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
import 'insert_published_origin.dart';
import 'thread_beat.dart';
import 'thread_focus.dart';
import 'thread_skeleton.dart';
import 'thread_view.dart';

class FamilyThreadPage extends StatefulWidget {
  const FamilyThreadPage({
    super.key,
    this.storiesApi,
    this.familiesApi,
    this.currentUserId,
    this.openStateStore,
    required this.live,
  });

  final StoriesGateway? storiesApi;
  final FamiliesGateway? familiesApi;

  /// Signed-in user. Widget tests pass this because [CurrentSession] is null
  /// before Supabase starts. Null means [CurrentSession.userId].
  final String? Function()? currentUserId;

  /// Last density and story for this family. Null uses the device store.
  final FamilyThreadOpenStateStore? openStateStore;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
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
      final storiesFuture = guardRead(
        () => _storiesFor(opened.id, opened.originId),
      );
      final savedFuture = _saved(opened);
      final stories = await storiesFuture;
      final saved = await savedFuture;
      if (!mounted || ticket != _ticket) return;
      _show(opened, stories, saved);
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
  ) {
    final restored = _restored(saved, stories);
    setState(() {
      _familyId = opened.id;
      _originId = opened.originId;
      _familyName = opened.name;
      _families = opened.mine;
      _loading = false;
      _failed = false;
      _ready = true;
      _member = _inMine(opened.mine, opened.id);
      _density = restored.density;
      _stories = stories;
      _focusId = restored.storyId;
      _focusStart = _startOf(stories, restored.storyId);
      _announce = false;
    });
  }

  void _applyStories(List<Story> stories) {
    _stories = stories;
    final focus = _focusOf(stories, _focusId, _focusStart);
    _focusId = focus.id;
    _focusStart = focus.start;
  }

  void _onScrollFocus(String storyId) {
    final focus = _focusOf(_stories, storyId, null);
    if (focus.id == null || focus.id == _focusId) return;
    setState(() {
      _focusId = focus.id;
      _focusStart = focus.start;
    });
    _persist();
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
    return Column(
      children: [
        _toolbar(),
        if (_announce) _DensityAnnouncement(density: _density),
        Expanded(child: _thread()),
        if (!_loading && _density == FamilyThreadDensity.overview)
          _OverviewCaption(familyName: _familyName),
      ],
    );
  }

  Widget _toolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = constraints.maxWidth < threadPhoneBreakpoint;
        return Align(
          alignment: phone ? Alignment.centerRight : Alignment.center,
          child: DensityControl(
            density: _density,
            enabled: !_loading,
            onChanged: _setDensity,
          ),
        );
      },
    );
  }

  Widget _thread() {
    if (_loading) return const ThreadSkeleton();
    return ThreadView(
      key: const Key('family-thread-loaded'),
      stories: _stories,
      density: _density,
      focusStoryId: _focusId,
      onFocusChanged: _onScrollFocus,
      onDensityDelta: _nudgeDensity,
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

  Future<FamilyThreadOpenState?> _saved(_Opened opened) async {
    final id = opened.id;
    if (id == null || !_inMine(opened.mine, id)) {
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

({FamilyThreadDensity density, String? storyId}) _restored(
  FamilyThreadOpenState? saved,
  List<Story> stories,
) {
  final newest = stories.isEmpty ? null : stories.last.id;
  if (saved == null || newest == null) {
    return (density: FamilyThreadDensity.browse, storyId: newest);
  }
  for (final story in stories) {
    if (story.id == saved.storyId) {
      return (density: saved.density, storyId: saved.storyId);
    }
  }
  return (density: saved.density, storyId: newest);
}

bool _inMine(List<MemberFamily> mine, String? id) {
  if (id == null) return false;
  for (final row in mine) {
    if (row.id == id) return true;
  }
  return false;
}

DateTime? _startOf(List<Story> stories, String? id) {
  for (final story in stories) {
    if (story.id == id) return story.publishedStart;
  }
  return null;
}

Story _cardStory(ThreadBeat beat, String? focusId) {
  return switch (beat) {
    StoryBeat(:final story) => story,
    YearBeat() => ThreadFocus.browseCardStory(beat, focusId: focusId),
    DecadeBeat() => ThreadFocus.representative(beat, previousFocusId: focusId),
  };
}

List<Story> _published(Iterable<Story> stories) {
  return [
    for (final story in stories)
      if (story.status == StoryStatus.published) story,
  ];
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
