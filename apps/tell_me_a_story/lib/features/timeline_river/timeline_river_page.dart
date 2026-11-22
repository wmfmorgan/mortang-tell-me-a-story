import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/invite_api.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import '../timeline/timeline_zoom.dart' hide decadeStartYear;
import 'river_beat.dart';
import 'river_density.dart';
import 'river_filter.dart';
import 'river_open_state.dart';
import 'river_open_state_store.dart';
import 'river_scaffold.dart';

/// Story River prototype. Existing timeline routes are untouched.
class TimelineRiverPage extends StatefulWidget {
  const TimelineRiverPage({
    super.key,
    this.inviteApi,
    this.storiesApi,
    this.familiesApi,
    this.photosApi,
    this.openStateStore,
  });

  final InviteGateway? inviteApi;
  final StoriesGateway? storiesApi;
  final FamiliesGateway? familiesApi;
  final PhotosGateway? photosApi;
  final RiverOpenStateStore? openStateStore;

  @override
  State<TimelineRiverPage> createState() => _TimelineRiverPageState();
}

class _TimelineRiverPageState extends State<TimelineRiverPage> {
  late final StoriesGateway _stories = widget.storiesApi ?? StoriesApi();
  late final FamiliesGateway _families = widget.familiesApi ?? FamiliesApi();
  late final RiverOpenStateStore _store =
      widget.openStateStore ?? RiverOpenStateStore();
  PhotosGateway? _photosOwned;
  InviteGateway? _inviteOwned;
  List<MemberFamily> _familiesList = const [];
  List<Story> _rows = const [];
  String? _familyId;
  String _familyName = '';
  RiverFilter _filter = const RiverFilter();
  RiverDensity _density = RiverDensity.browse;
  String _storyId = '';
  String _announcement = '';
  var _loading = true;
  String? _loadError;

  PhotosGateway? get _photos {
    if (widget.photosApi != null) return widget.photosApi;
    if (widget.storiesApi != null) return null;
    return _photosOwned ??= PhotosApi();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _filter = const RiverFilter();
    });
    final slice = await riverGuarded(
      _fetch,
      (error) => _FamilySlice.failure(riverLoadMessage(error)),
    );
    if (!mounted) return;
    await _apply(slice);
  }

  Future<void> _apply(_FamilySlice slice) async {
    if (slice.error != null) {
      setState(() {
        _loading = false;
        _loadError = slice.error;
      });
      return;
    }
    final familyId = slice.familyId;
    final saved = familyId == null ? null : await _store.read(familyId);
    if (!mounted) return;
    final open = resolveRiverOpen(stories: slice.stories, saved: saved);
    setState(() {
      _familiesList = slice.families;
      _familyId = familyId;
      _familyName = slice.familyName;
      _rows = slice.stories;
      _density = open.density;
      _storyId = open.storyId;
      _loading = false;
      _announcement = _semantics(open.storyId, open.density, slice.stories);
    });
    if (familyId != null) FamilySelection.remember(familyId);
  }

  Future<_FamilySlice> _fetch() async {
    final mine = await _families.listMine();
    final id = await _familyIdFor(mine);
    if (id == null) {
      return _FamilySlice(families: mine, familyId: null, familyName: '');
    }
    final name = _name(mine, id);
    final stories = publishedStories(await _stories.listPublished(id));
    return _FamilySlice(
      families: mine,
      familyId: id,
      familyName: name,
      stories: stories,
    );
  }

  Future<String?> _familyIdFor(List<MemberFamily> mine) async {
    final remembered = FamilySelection.id;
    if (remembered != null && mine.any((family) => family.id == remembered)) {
      return remembered;
    }
    if (mine.isNotEmpty) return mine.first.id;
    if (widget.storiesApi != null && widget.inviteApi == null) return null;
    return _invite.currentFamilyId();
  }

  InviteGateway get _invite =>
      widget.inviteApi ?? (_inviteOwned ??= InviteApi());

  String _name(List<MemberFamily> mine, String id) {
    for (final family in mine) {
      if (family.id == id) return family.name;
    }
    return 'Family';
  }

  List<Story> get _ordered =>
      [...publishedStories(_rows)]..sort(compareStories);

  void _setFilter(RiverFilter filter) {
    setState(() {
      _filter = filter;
      _announcement = _semantics(_storyId, _density, _rows);
    });
  }

  void _setDensity(RiverDensity density) {
    if (density == _density) return;
    setState(() {
      _density = density;
      _announcement = _semantics(_storyId, density, _rows);
    });
    _persist();
  }

  void _setStory(String id) {
    if (id.isEmpty || id == _storyId) return;
    setState(() {
      _storyId = id;
      _announcement = _semantics(id, _density, _rows);
    });
    _persist();
  }

  void _focusBeat(RiverBeat beat) {
    _setStory(storyIdForBeat(beat, _storyId, _ordered));
  }

  void _move(int delta) {
    final beats = _beats();
    if (beats.isEmpty) return;
    final index = beatIndexFor(beats, _storyId);
    final next = (index + delta).clamp(0, beats.length - 1);
    _focusBeat(beats[next]);
  }

  void _edge(bool oldest) {
    final beats = _beats();
    if (beats.isEmpty) return;
    _focusBeat(oldest ? beats.first : beats.last);
  }

  void _jumpYear(int year) {
    final ordered = _ordered;
    if (ordered.isEmpty) return;
    _setStory(nearestStoryByYear(ordered, year).id);
  }

  void _jumpDecade(int startYear) {
    final rows = [
      for (final story in _ordered)
        if (decadeStartYear(story.publishedStart) == startYear) story,
    ];
    if (rows.isEmpty) return;
    final current = _story(_storyId);
    final year = current?.publishedStart.year ?? startYear;
    _setStory(nearestStoryByYear(rows, year).id);
  }

  void _open() {
    if (_storyId.isEmpty) return;
    context.push(AppRoutes.storyPath(_storyId));
  }

  Future<void> _selectFamily(String id) async {
    FamilySelection.remember(id);
    if (id == _familyId) return;
    setState(() => _familyId = id);
    await _load();
  }

  void _persist() {
    final familyId = _familyId;
    if (familyId == null || _storyId.isEmpty) return;
    final year = _story(_storyId)?.publishedStart.year ?? 0;
    unawaited(
      _store.write(
        familyId,
        RiverOpenState(density: _density, storyId: _storyId, year: year),
      ),
    );
  }

  Story? _story(String id) {
    for (final story in _rows) {
      if (story.id == id) return story;
    }
    return null;
  }

  List<RiverBeat> _beats() {
    return buildRiverBeats(stories: _rows, density: _density, filter: _filter);
  }

  String _semantics(String storyId, RiverDensity density, List<Story> stories) {
    final beats = buildRiverBeats(
      stories: stories,
      density: density,
      filter: _filter,
    );
    if (beats.isEmpty || storyId.isEmpty) return '';
    return riverBeatSemantics(
      beat: beats[beatIndexFor(beats, storyId)],
      density: density,
      focusId: storyId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RiverScaffold(
          loading: _loading,
          error: _loadError,
          onRetry: () => unawaited(_load()),
          familyName: _familyName,
          families: _familiesList,
          familyId: _familyId,
          stories: _rows,
          filter: _filter,
          density: _density,
          storyId: _storyId,
          announcement: _announcement,
          photos: _photos,
          onFamilySelected: (id) => unawaited(_selectFamily(id)),
          onFilter: _setFilter,
          onDensity: _setDensity,
          onDensityStep: (delta) =>
              _setDensity(riverDensityStep(_density, delta)),
          onFocusBeat: _focusBeat,
          onOpen: _open,
          onMove: _move,
          onEdge: _edge,
          onJumpYear: _jumpYear,
          onJumpDecade: _jumpDecade,
        ),
      ),
    );
  }
}

class _FamilySlice {
  const _FamilySlice({
    required this.families,
    required this.familyId,
    required this.familyName,
    this.stories = const [],
    this.error,
  });

  factory _FamilySlice.failure(String error) {
    return _FamilySlice(
      families: const [],
      familyId: null,
      familyName: '',
      error: error,
    );
  }

  final List<MemberFamily> families;
  final String? familyId;
  final String familyName;
  final List<Story> stories;
  final String? error;
}
