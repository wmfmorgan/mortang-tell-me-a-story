import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/album_header.dart';
import '../../core/theme/album_theme.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/invite_api.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import '../../data/timeline_live.dart';
import '../invites/invite_accept.dart';
import '../invites/invite_modal.dart';
import 'timeline_zoom.dart';

/// Signed-in home. Far / mid / near rails match the Stitch timeline screens.
class TimelinePage extends StatefulWidget {
  const TimelinePage({
    super.key,
    this.api,
    this.storiesApi,
    this.familiesApi,
    this.photosApi,
    this.live,
  });

  final InviteGateway? api;
  final StoriesGateway? storiesApi;
  final FamiliesGateway? familiesApi;
  final PhotosGateway? photosApi;
  final TimelineLive? live;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  late final InviteGateway _api;
  StoriesGateway? _storiesOverride;
  PhotosGateway? _photosOverride;
  TimelineLive? _ownedLive;
  GoRouter? _router;
  String? _familyId;
  List<MemberFamily> _families = const [];
  List<Story> _published = const [];
  var _loadingFamily = true;
  var _loadingPublished = true;
  var _inviteHandled = false;
  var _zoom = TimelineZoom.far;
  int? _decadeStart;
  String? _focusedStoryId;
  var _pinchLatched = false;
  final _anchorKeys = <String, GlobalKey>{};

  StoriesGateway get _stories =>
      widget.storiesApi ?? (_storiesOverride ??= StoriesApi());

  TimelineLive? get _live {
    if (widget.live != null) return widget.live;
    if (widget.storiesApi != null) return null;
    return _ownedLive ??= SupabaseTimelineLive();
  }

  PhotosGateway? get _photos {
    if (widget.photosApi != null) return widget.photosApi;
    if (widget.storiesApi != null) return null;
    return _photosOverride ??= PhotosApi();
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? InviteApi();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (identical(router, _router)) return;
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _router = router;
    _router?.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _ownedLive?.dispose();
    super.dispose();
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final path = _router?.routerDelegate.currentConfiguration.uri.path;
    if (path != AppRoutes.timeline) return;
    _loadPublished();
  }

  Future<void> _bootstrap() async {
    try {
      final id = await _api.currentFamilyId();
      if (!mounted) return;
      setState(() {
        _familyId = id;
        _loadingFamily = false;
      });
      await _loadFamilies();
      _watchLive();
      await _loadPublished();
      await _maybeAcceptInvite();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingFamily = false;
        _loadingPublished = false;
      });
    }
  }

  Future<void> _loadFamilies() async {
    final familyId = _familyId;
    List<MemberFamily> rows = const [];
    try {
      if (widget.familiesApi != null) {
        rows = await widget.familiesApi!.listMine();
      } else if (widget.storiesApi != null) {
        rows = familyId == null
            ? const []
            : [
                MemberFamily(
                  id: familyId,
                  name: 'Family',
                  createdAt: DateTime.utc(2020),
                ),
              ];
      } else {
        rows = await FamiliesApi().listMine();
      }
    } catch (_) {
      rows = const [];
    }
    if (!mounted) return;
    if (rows.isEmpty && familyId != null) {
      rows = [
        MemberFamily(
          id: familyId,
          name: 'Family',
          createdAt: DateTime.utc(2020),
        ),
      ];
    }
    setState(() => _families = rows);
  }

  void _watchLive() {
    final familyId = _familyId;
    final live = _live;
    if (familyId == null || live == null) return;
    live.watch(
      familyId: familyId,
      onChange: () {
        if (mounted) _loadPublished();
      },
    );
  }

  Future<void> _loadPublished() async {
    final familyId = _familyId;
    if (familyId == null) {
      if (!mounted) return;
      setState(() {
        _published = const [];
        _loadingPublished = false;
      });
      return;
    }
    try {
      final rows = await _stories.listPublished(familyId);
      if (!mounted) return;
      setState(() {
        _published = publishedStories(rows);
        _loadingPublished = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPublished = false);
    }
  }

  Future<void> _maybeAcceptInvite() async {
    if (_inviteHandled || !mounted) return;
    _inviteHandled = true;
    final uri = GoRouterState.of(context).uri;
    if (!uri.queryParameters.containsKey('invite')) return;
    await acceptInviteFromUriIfPresent(context: context, uri: uri, api: _api);
  }

  Future<void> _selectFamily(String id) async {
    FamilySelection.remember(id);
    if (id == _familyId) return;
    final previousFocus = _focusedStoryId;
    setState(() {
      _familyId = id;
      _loadingPublished = true;
    });
    _watchLive();
    await _loadPublished();
    if (!mounted) return;
    final still =
        previousFocus != null &&
        _published.any((story) => story.id == previousFocus);
    if (!still && previousFocus != null) {
      setState(() {
        _focusedStoryId = null;
        _decadeStart = null;
        _zoom = TimelineZoom.far;
      });
    }
  }

  Future<void> _openInvite() async {
    var familyId = _familyId;
    if (familyId == null) {
      familyId = await _api.currentFamilyId();
    }
    if (familyId == null) {
      familyId = await _api.createFamily('Family');
      if (!mounted) return;
      setState(() => _familyId = familyId);
    }
    if (!mounted) return;
    await InviteModal.show(context, familyId: familyId, api: _api);
  }

  MemberFamily? get _currentFamily {
    for (final family in _families) {
      if (family.id == _familyId) return family;
    }
    return _families.isEmpty ? null : _families.first;
  }

  int _activeDecade(List<DecadeBand> bands) {
    if (bands.isEmpty) return 1900;
    if (_decadeStart != null &&
        bands.any((band) => band.startYear == _decadeStart)) {
      return _decadeStart!;
    }
    return bands.first.startYear;
  }

  Story? _storyById(String? id) {
    if (id == null) return null;
    for (final story in _published) {
      if (story.id == id) return story;
    }
    return null;
  }

  void _onDialFocus(String id) {
    final story = _storyById(id);
    if (story == null || id == _focusedStoryId) return;
    setState(() {
      _focusedStoryId = id;
      _decadeStart = decadeStartYear(story.timeframeStart);
    });
  }

  void _reveal(String storyId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _anchorKeys[storyId]?.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(target, alignment: 0.3);
    });
  }

  GlobalKey _anchor(String id) => _anchorKeys.putIfAbsent(id, GlobalKey.new);

  void _openMid(Story story) {
    setState(() {
      _zoom = TimelineZoom.mid;
      _decadeStart = decadeStartYear(story.timeframeStart);
      _focusedStoryId = story.id;
    });
  }

  void _openNear(Story story) {
    setState(() {
      _zoom = TimelineZoom.near;
      _decadeStart = decadeStartYear(story.timeframeStart);
      _focusedStoryId = story.id;
    });
    _reveal(story.id);
  }

  void _zoomIn() {
    final rows = dialStories(_published);
    if (rows.isEmpty) return;
    final focus = _storyById(_focusedStoryId) ?? rows.first;
    final next = zoomIn(_zoom);
    setState(() {
      _focusedStoryId = focus.id;
      _decadeStart = decadeStartYear(focus.timeframeStart);
      _zoom = next;
    });
    if (next == TimelineZoom.near) _reveal(focus.id);
  }

  void _openFullCards() {
    final rows = dialStories(_published);
    if (rows.isEmpty) return;
    final focus = _storyById(_focusedStoryId) ?? rows.first;
    setState(() {
      _focusedStoryId = focus.id;
      _decadeStart = decadeStartYear(focus.timeframeStart);
      _zoom = TimelineZoom.near;
    });
    _reveal(focus.id);
  }

  void _zoomOut() {
    setState(() => _zoom = zoomOut(_zoom));
  }

  void _fitAll() {
    setState(() {
      _zoom = TimelineZoom.far;
      _decadeStart = null;
      _focusedStoryId = null;
    });
  }

  void _onPinch(ScaleUpdateDetails details) {
    if (_pinchLatched) return;
    if (details.scale > 1.08) {
      _pinchLatched = true;
      _zoomIn();
    } else if (details.scale < 0.92) {
      _pinchLatched = true;
      _zoomOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = _currentFamily;
    final bands = decadeBands(_published);
    final decade = _activeDecade(bands);
    final showRail = !_loadingFamily && !_loadingPublished && bands.isNotEmpty;
    return Scaffold(
      backgroundColor: albumParchment,
      appBar: AlbumHeader(
        page: AlbumHeaderPage.timeline,
        familyName: family?.name ?? 'Family',
        families: _families,
        currentFamilyId: _familyId,
        onFamilySelected: _selectFamily,
        onInvite: _openInvite,
      ),
      body: GestureDetector(
        onScaleStart: (_) => _pinchLatched = false,
        onScaleUpdate: _onPinch,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(child: _body(bands, decade)),
                if (showRail && _zoom == TimelineZoom.far)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Text(
                      farFooter(familyName: family?.name ?? 'Family'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: albumInk.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
              ],
            ),
            if (showRail)
              Positioned(
                left: 0,
                right: 0,
                bottom: _zoom == TimelineZoom.far ? 48 : 16,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ZoomCluster(
                      zoom: _zoom,
                      onIn: _zoomIn,
                      onOut: _zoomOut,
                      onFit: _fitAll,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(List<DecadeBand> bands, int decade) {
    if (_loadingFamily || _loadingPublished) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bands.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No stories yet. Capture the first one for this family.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final child = _familyId == null ? null : childFamily(_families, _familyId!);
    return switch (_zoom) {
      TimelineZoom.far => _FarRail(
        bands: bands,
        focusedId: _focusedStoryId,
        child: child,
        onDot: _openMid,
        onFocus: _onDialFocus,
        onMid: _zoomIn,
        onFullCards: _openFullCards,
      ),
      TimelineZoom.mid => _MidRail(
        stories: dialStories(_published),
        focusedId: _focusedStoryId,
        child: child,
        anchorFor: _anchor,
        onStub: _openNear,
        onFocus: _onDialFocus,
        onMacro: _fitAll,
        onFullCards: _zoomIn,
      ),
      TimelineZoom.near => _NearRail(
        stories: decadeNewestFirst(_published, decade),
        focusedId: _focusedStoryId,
        child: child,
        photos: _photos,
        anchorFor: _anchor,
        onOpen: (story) => context.push('/stories/${story.id}'),
      ),
    };
  }
}

class _ZoomCluster extends StatelessWidget {
  const _ZoomCluster({
    required this.zoom,
    required this.onIn,
    required this.onOut,
    required this.onFit,
  });

  final TimelineZoom zoom;
  final VoidCallback onIn;
  final VoidCallback onOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final hint = switch (zoom) {
      TimelineZoom.far => 'Pinch · tap decade dot to zoom in · − to pull back',
      TimelineZoom.mid => 'Pinch · tap stub to zoom in · − to pull back',
      TimelineZoom.near => 'Pinch out · tap − · or Fit all to pull back',
    };
    const fitLabel = 'Fit all';
    final controls = Material(
      color: albumParchment,
      elevation: zoom == TimelineZoom.mid ? 6 : 2,
      borderRadius: BorderRadius.circular(zoom == TimelineZoom.mid ? 12 : 24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('timeline-zoom-out'),
              tooltip: 'Zoom out',
              onPressed: onOut,
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              key: const Key('timeline-zoom-in'),
              tooltip: 'Zoom in',
              onPressed: onIn,
              icon: const Icon(Icons.add),
            ),
            if (zoom != TimelineZoom.near)
              Container(
                width: 1,
                height: 24,
                color: albumInk.withValues(alpha: 0.15),
              ),
            TextButton(
              key: const Key('timeline-fit'),
              onPressed: onFit,
              child: const Text(fitLabel),
            ),
          ],
        ),
      ),
    );
    final hintText = Text(hint, style: Theme.of(context).textTheme.labelMedium);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (zoom == TimelineZoom.near)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Near · full cards',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        if (zoom != TimelineZoom.near) ...[
          controls,
          const SizedBox(height: 8),
          hintText,
        ] else ...[
          hintText,
          const SizedBox(height: 8),
          controls,
        ],
      ],
    );
  }
}

class _FarRail extends StatefulWidget {
  const _FarRail({
    required this.bands,
    required this.focusedId,
    required this.child,
    required this.onDot,
    required this.onFocus,
    required this.onMid,
    required this.onFullCards,
  });

  final List<DecadeBand> bands;
  final String? focusedId;
  final MemberFamily? child;
  final ValueChanged<Story> onDot;
  final ValueChanged<String> onFocus;
  final VoidCallback onMid;
  final VoidCallback onFullCards;

  @override
  State<_FarRail> createState() => _FarRailState();
}

class _FarRailState extends State<_FarRail> {
  final _viewportKey = GlobalKey();
  final _rowKeys = <int, GlobalKey>{};
  int? _centerYear;
  Map<int, double> _opacities = const {};
  var _centered = false;

  GlobalKey _rowKey(int year) => _rowKeys.putIfAbsent(year, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _centerYear = _yearOf(widget.focusedId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerInitial());
  }

  @override
  void didUpdateWidget(covariant _FarRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final year = _yearOf(widget.focusedId);
    if (year != null &&
        year != _yearOf(oldWidget.focusedId) &&
        year != _centerYear) {
      _centerYear = year;
      _centerOn(year);
    }
  }

  int? _yearOf(String? id) {
    if (id == null) return null;
    for (final band in widget.bands) {
      for (final story in band.stories) {
        if (story.id == id) return band.startYear;
      }
    }
    return null;
  }

  Story? _highlight(DecadeBand band) {
    for (final story in band.stories) {
      if (story.id == widget.focusedId) return story;
    }
    if (band.stories.isEmpty) return null;
    return band.stories[band.stories.length ~/ 2];
  }

  void _centerInitial() {
    if (!mounted || _centered || widget.bands.isEmpty) return;
    _centered = true;
    final year =
        _centerYear ?? widget.bands[widget.bands.length ~/ 2].startYear;
    _centerYear = year;
    _centerOn(year);
  }

  void _centerOn(int year) {
    final target = _rowKey(year).currentContext;
    if (target == null || !target.mounted) return;
    Scrollable.ensureVisible(target, alignment: 0.5, duration: Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
  }

  void _measure() {
    if (!mounted) return;
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final centerY = viewportTop + viewport.size.height / 2;
    int? bestYear;
    var best = double.infinity;
    final opacities = <int, double>{};
    for (final band in widget.bands) {
      final row =
          _rowKey(band.startYear).currentContext?.findRenderObject()
              as RenderBox?;
      if (row == null || !row.hasSize) continue;
      final rowTop = row.localToGlobal(Offset.zero).dy;
      final mid = rowTop + row.size.height / 2;
      final distance = (mid - centerY).abs();
      opacities[band.startYear] = farEdgeOpacity(
        rowTop: rowTop,
        rowHeight: row.size.height,
        viewportTop: viewportTop,
        viewportHeight: viewport.size.height,
      );
      if (distance < best) {
        best = distance;
        bestYear = band.startYear;
      }
    }
    final yearChanged = bestYear != null && bestYear != _centerYear;
    if (!yearChanged && _sameOpacity(opacities)) return;
    setState(() {
      if (bestYear != null) _centerYear = bestYear;
      _opacities = opacities;
    });
    DecadeBand? band;
    for (final candidate in widget.bands) {
      if (candidate.startYear == bestYear) band = candidate;
    }
    final story = band == null ? null : _highlight(band);
    final id = story?.id;
    if (!yearChanged) return;
    if (id != null && id != widget.focusedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && id != widget.focusedId) widget.onFocus(id);
      });
    }
  }

  bool _sameOpacity(Map<int, double> next) {
    if (next.length != _opacities.length) return false;
    for (final entry in next.entries) {
      final previous = _opacities[entry.key];
      if (previous == null || (previous - entry.value).abs() > 0.01) {
        return false;
      }
    }
    return true;
  }

  int? _joinYear() {
    final child = widget.child;
    if (child == null || widget.bands.isEmpty) return null;
    var best = widget.bands.first.startYear;
    var bestDelta = 1 << 30;
    for (final band in widget.bands) {
      final delta = (band.startYear - child.createdAt.year).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = band.startYear;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    var focusBand = widget.bands[widget.bands.length ~/ 2];
    for (final band in widget.bands) {
      if (band.startYear == _centerYear) focusBand = band;
    }
    final focusLabel = '${focusBand.label} · IN FOCUS';
    final joinYear = _joinYear();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: _FarContext(
            focusLabel: focusLabel,
            onMid: widget.onMid,
            onFullCards: widget.onFullCards,
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification ||
                  notification is ScrollEndNotification) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _measure();
                });
              }
              return false;
            },
            child: Stack(
              key: _viewportKey,
              children: [
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: 2,
                        child: ColoredBox(color: Color(0x332C2416)),
                      ),
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final pad = constraints.maxHeight / 2;
                    return ListView(
                      padding: EdgeInsets.fromLTRB(24, pad, 24, pad),
                      children: [
                        for (var i = 0; i < widget.bands.length; i++)
                          _FarDecadeRow(
                            key: _rowKey(widget.bands[i].startYear),
                            band: widget.bands[i],
                            focused: widget.bands[i].startYear == _centerYear,
                            opacity: _opacities[widget.bands[i].startYear] ?? 1,
                            highlight: _highlight(widget.bands[i]),
                            showBranch:
                                joinYear != null &&
                                widget.bands[i].startYear == joinYear,
                            continueRail:
                                joinYear != null &&
                                widget.bands[i].startYear >= joinYear,
                            railAbove:
                                joinYear != null &&
                                widget.bands.any(
                                  (other) =>
                                      other.startYear >
                                      widget.bands[i].startYear,
                                ),
                            railBelow:
                                joinYear != null &&
                                widget.bands.any(
                                  (other) =>
                                      other.startYear >= joinYear &&
                                      other.startYear <
                                          widget.bands[i].startYear,
                                ),
                            branchName: widget.child?.name,
                            onDot: widget.onDot,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FarContext extends StatelessWidget {
  const _FarContext({
    required this.focusLabel,
    required this.onMid,
    required this.onFullCards,
  });

  final String focusLabel;
  final VoidCallback onMid;
  final VoidCallback onFullCards;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: albumInk.withValues(alpha: 0.12)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          spacing: 16,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: albumTerracotta,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  'CONTINUOUS FAMILY DIAL',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Text('·', style: Theme.of(context).textTheme.labelMedium),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: albumTerracotta.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: albumTerracotta.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    focusLabel,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text(
                  'Zoom Level: Far (Decade dots)',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: albumInk.withValues(alpha: 0.7)),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: albumInk.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: albumInk.withValues(alpha: 0.12)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: albumTerracotta,
                            foregroundColor: albumParchment,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Macro'),
                        ),
                        TextButton(
                          onPressed: onMid,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: albumInk.withValues(alpha: 0.7),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Mid'),
                        ),
                        TextButton(
                          onPressed: onFullCards,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: albumInk.withValues(alpha: 0.7),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Full Cards'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FarDecadeRow extends StatelessWidget {
  const _FarDecadeRow({
    super.key,
    required this.band,
    required this.focused,
    required this.opacity,
    required this.highlight,
    required this.showBranch,
    required this.continueRail,
    required this.railAbove,
    required this.railBelow,
    required this.branchName,
    required this.onDot,
  });

  final DecadeBand band;
  final bool focused;
  final double opacity;
  final Story? highlight;
  final bool showBranch;
  final bool continueRail;
  final bool railAbove;
  final bool railBelow;
  final String? branchName;
  final ValueChanged<Story> onDot;

  @override
  Widget build(BuildContext context) {
    final stories = band.stories;
    final count = countWord(band.stories.length, 'story', 'stories');
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          band.label,
          style: focused
              ? Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)
              : Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (focused)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(
                  color: albumTerracotta,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              focused ? '$count preserved' : count,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: focused
                    ? albumTerracotta
                    : albumInk.withValues(alpha: 0.6),
                fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
    final dots = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final story in stories)
          _FarDot(
            story: story,
            highlighted: focused && story.id == highlight?.id,
            onTap: () => onDot(story),
          ),
      ],
    );
    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: label),
            ),
            SizedBox(
              width: 48,
              child: Center(
                child: Container(
                  width: focused ? 28 : 14,
                  height: focused ? 28 : 14,
                  decoration: BoxDecoration(
                    color: focused
                        ? albumTerracotta.withValues(alpha: 0.2)
                        : const Color(0xFFFFF8F6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: focused
                          ? albumTerracotta
                          : albumInk.withValues(alpha: 0.35),
                      width: focused ? 1.5 : 2,
                    ),
                  ),
                  child: focused
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: albumTerracotta,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final railLeft = (constraints.maxWidth - 8).clamp(
                    72.0,
                    200.0,
                  );
                  final reserve = continueRail
                      ? (constraints.maxWidth - railLeft + 12).clamp(
                          0.0,
                          constraints.maxWidth,
                        )
                      : 0.0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 16, right: reserve),
                        child: dots,
                      ),
                      if (continueRail)
                        Positioned(
                          left: railLeft,
                          top: railAbove ? -22 : 0,
                          bottom: railBelow ? -22 : 0,
                          width: 2,
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _DashPainter(
                                color: albumSage.withValues(alpha: 0.85),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      if (showBranch && branchName != null)
                        Positioned(
                          left: railLeft + 12,
                          top: -4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: albumParchment,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: albumSage.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  '${branchName!.toUpperCase()} BRANCH',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: albumSage,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '← $branchName union joined archive',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: albumSage,
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FarDot extends StatelessWidget {
  const _FarDot({
    required this.story,
    required this.highlighted,
    required this.onTap,
  });

  final Story story;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dot = GestureDetector(
      key: Key('timeline-dot-${story.id}'),
      onTap: onTap,
      child: Container(
        width: highlighted ? 14 : 12,
        height: highlighted ? 14 : 12,
        decoration: BoxDecoration(
          color: albumTerracotta,
          shape: BoxShape.circle,
          border: highlighted
              ? Border.all(color: albumTerracotta, width: 2)
              : null,
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: albumTerracotta.withValues(alpha: 0.35),
                    blurRadius: 0,
                    spreadRadius: 3,
                  ),
                ]
              : null,
        ),
      ),
    );
    return Tooltip(message: dotTooltip(story), child: dot);
  }
}

class _MidRail extends StatefulWidget {
  const _MidRail({
    required this.stories,
    required this.focusedId,
    required this.child,
    required this.anchorFor,
    required this.onStub,
    required this.onFocus,
    required this.onMacro,
    required this.onFullCards,
  });

  final List<Story> stories;
  final String? focusedId;
  final MemberFamily? child;
  final GlobalKey Function(String id) anchorFor;
  final ValueChanged<Story> onStub;
  final ValueChanged<String> onFocus;
  final VoidCallback onMacro;
  final VoidCallback onFullCards;

  @override
  State<_MidRail> createState() => _MidRailState();
}

class _MidRailState extends State<_MidRail> {
  final _viewportKey = GlobalKey();
  String? _centerId;
  Map<String, double> _opacities = const {};
  var _centered = false;

  @override
  void initState() {
    super.initState();
    _centerId = widget.focusedId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerInitial());
  }

  @override
  void didUpdateWidget(covariant _MidRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.focusedId;
    if (next != null && next != oldWidget.focusedId && next != _centerId) {
      _centerId = next;
      _centerOn(next);
    }
  }

  void _centerInitial() {
    if (!mounted || _centered) return;
    _centered = true;
    final id =
        _centerId ?? (widget.stories.isEmpty ? null : widget.stories.first.id);
    if (id == null) return;
    _centerId = id;
    _centerOn(id);
  }

  void _centerOn(String id) {
    final target = widget.anchorFor(id).currentContext;
    if (target == null || !target.mounted) return;
    Scrollable.ensureVisible(target, alignment: 0.5, duration: Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
  }

  bool _sameOpacity(Map<String, double> next) {
    if (next.length != _opacities.length) return false;
    for (final entry in next.entries) {
      final previous = _opacities[entry.key];
      if (previous == null || (previous - entry.value).abs() > 0.02) {
        return false;
      }
    }
    return true;
  }

  void _measure() {
    if (!mounted) return;
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final centerY = viewport
        .localToGlobal(Offset(0, viewport.size.height / 2))
        .dy;
    final half = viewport.size.height / 2;
    String? bestId;
    var best = double.infinity;
    final opacities = <String, double>{};
    for (final story in widget.stories) {
      final row =
          widget.anchorFor(story.id).currentContext?.findRenderObject()
              as RenderBox?;
      if (row == null || !row.hasSize) continue;
      final mid = row.localToGlobal(Offset(0, row.size.height / 2)).dy;
      final distance = (mid - centerY).abs();
      opacities[story.id] = dialOpacity(distance: distance, halfExtent: half);
      if (distance < best) {
        best = distance;
        bestId = story.id;
      }
    }
    final idChanged = bestId != null && bestId != _centerId;
    if (!idChanged && _sameOpacity(opacities)) return;
    setState(() {
      if (bestId != null) _centerId = bestId;
      _opacities = opacities;
    });
    final id = bestId;
    if (idChanged && id != null && id != widget.focusedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && id != widget.focusedId) widget.onFocus(id);
      });
    }
  }

  int _focusYear() {
    final id = _centerId ?? widget.focusedId;
    for (final story in widget.stories) {
      if (story.id == id) return story.timeframeStart.year;
    }
    if (widget.stories.isEmpty) return 0;
    return widget.stories.first.timeframeStart.year;
  }

  @override
  Widget build(BuildContext context) {
    final joinAt = widget.child == null
        ? -1
        : closestStoryIndex(widget.stories, widget.child!.createdAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: _MidContext(
            year: _focusYear(),
            onMacro: widget.onMacro,
            onFullCards: widget.onFullCards,
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification ||
                  notification is ScrollEndNotification) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _measure();
                });
              }
              return false;
            },
            child: Stack(
              key: _viewportKey,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final pad = constraints.maxHeight / 2;
                    return ListView(
                      padding: EdgeInsets.fromLTRB(24, pad, 24, pad),
                      children: [
                        for (var i = 0; i < widget.stories.length; i++)
                          _DialRow(
                            key: widget.anchorFor(widget.stories[i].id),
                            story: widget.stories[i],
                            cardOnLeft: i.isEven,
                            focused: widget.stories[i].id == _centerId,
                            opacity:
                                _opacities[widget.stories[i].id] ??
                                (widget.stories[i].id == _centerId ? 1 : 0.35),
                            showBranchRail: widget.child != null && i <= joinAt,
                            railEndsAtJoin: widget.child != null && i == joinAt,
                            joinNote: widget.child != null && i == joinAt
                                ? '← ${widget.child!.name} union joined archive'
                                : null,
                            branchLabel: widget.child != null && i == joinAt
                                ? '${widget.child!.name} Branch'
                                : null,
                            onTap: () => widget.onStub(widget.stories[i]),
                          ),
                      ],
                    );
                  },
                ),
                const _DialFade(top: true),
                const _DialFade(top: false),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DialFade extends StatelessWidget {
  const _DialFade({required this.top});

  final bool top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      height: 120,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                albumParchment,
                albumParchment.withValues(alpha: 0.85),
                albumParchment.withValues(alpha: 0),
              ],
              stops: const [0.15, 0.45, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _MidContext extends StatelessWidget {
  const _MidContext({
    required this.year,
    required this.onMacro,
    required this.onFullCards,
  });

  final int year;
  final VoidCallback onMacro;
  final VoidCallback onFullCards;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: albumInk.withValues(alpha: 0.12)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          spacing: 16,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Icon(
                  Icons.auto_stories,
                  size: 16,
                  color: albumTerracotta,
                ),
                Text(
                  'Continuous Family Dial',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: albumTerracotta,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '·',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: albumInk.withValues(alpha: 0.35)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: albumInk.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: albumInk.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: albumTerracotta,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dialFocusLabel(year),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: albumTerracotta.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Zoom Level: 45% (Stubs & Eras)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: albumTerracotta,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: albumInk.withValues(alpha: 0.15)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: onMacro,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: albumInk.withValues(alpha: 0.7),
                          ),
                          child: const Text('Macro'),
                        ),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: albumTerracotta,
                            foregroundColor: albumParchment,
                          ),
                          child: const Text('Mid'),
                        ),
                        TextButton(
                          onPressed: onFullCards,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: albumInk.withValues(alpha: 0.7),
                          ),
                          child: const Text('Full Cards'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialRow extends StatelessWidget {
  const _DialRow({
    super.key,
    required this.story,
    required this.cardOnLeft,
    required this.focused,
    required this.opacity,
    required this.showBranchRail,
    required this.railEndsAtJoin,
    required this.onTap,
    this.joinNote,
    this.branchLabel,
  });

  final Story story;
  final bool cardOnLeft;
  final bool focused;
  final double opacity;
  final bool showBranchRail;
  final bool railEndsAtJoin;
  final String? joinNote;
  final String? branchLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final year = '${story.timeframeStart.year}';
    final place = (story.placeLabel ?? '').trim();
    final photos = story.photoCount > 0
        ? countWord(story.photoCount, 'photo', 'photos')
        : null;
    final card = InkWell(
      key: Key('timeline-stub-${story.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(focused ? 12 : 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: focused
              ? BoxDecoration(
                  color: const Color(0xFFFFF8F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: albumTerracotta, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: albumInk.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                )
              : const BoxDecoration(),
          child: Padding(
            padding: EdgeInsets.all(focused ? 16 : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: cardOnLeft
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: cardOnLeft
                      ? WrapAlignment.end
                      : WrapAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: focused
                            ? albumTerracotta
                            : albumInk.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        year,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: focused ? albumParchment : albumInk,
                        ),
                      ),
                    ),
                    if (place.isNotEmpty)
                      Text(
                        place,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: focused
                              ? albumTerracotta
                              : albumInk.withValues(alpha: 0.55),
                          fontWeight: focused ? FontWeight.w700 : null,
                        ),
                      ),
                    if (photos != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_library,
                            size: 14,
                            color: focused
                                ? albumTerracotta
                                : albumInk.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            photos,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  storyTitle(story),
                  textAlign: cardOnLeft ? TextAlign.end : TextAlign.start,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final note = joinNote == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
            child: Text(
              joinNote!,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontStyle: FontStyle.italic, color: albumSage),
            ),
          );
    final label = branchLabel == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: albumSage.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  branchLabel!,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: albumSage, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          );
    final node = Container(
      width: focused ? 22 : 16,
      height: focused ? 22 : 16,
      decoration: BoxDecoration(
        color: focused
            ? albumTerracotta.withValues(alpha: 0.22)
            : const Color(0xFFFFF8F6),
        shape: BoxShape.circle,
        border: Border.all(color: albumTerracotta, width: focused ? 2 : 1.5),
      ),
      child: Center(
        child: Container(
          width: focused ? 8 : 6,
          height: focused ? 8 : 6,
          decoration: const BoxDecoration(
            color: albumTerracotta,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Row(
                children: [
                  const Expanded(child: SizedBox.shrink()),
                  SizedBox(
                    width: 56,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: 27,
                          width: 2,
                          child: ColoredBox(
                            color: albumInk.withValues(alpha: 0.16),
                          ),
                        ),
                        if (showBranchRail)
                          Positioned(
                            key: Key('timeline-branch-${story.id}'),
                            top: 0,
                            bottom: 0,
                            right: 0,
                            width: 2,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: FractionallySizedBox(
                                heightFactor: railEndsAtJoin ? 0.5 : 1,
                                child: CustomPaint(
                                  painter: _DashPainter(
                                    color: albumSage.withValues(alpha: 0.7),
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: cardOnLeft ? card : note,
                  ),
                ),
                const SizedBox(width: 56),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [label, cardOnLeft ? note : card],
                    ),
                  ),
                ),
              ],
            ),
            node,
          ],
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(1, y), Offset(1, y + 4), paint);
      y += 8;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _NearRail extends StatelessWidget {
  const _NearRail({
    required this.stories,
    required this.focusedId,
    required this.child,
    required this.photos,
    required this.anchorFor,
    required this.onOpen,
  });

  final List<Story> stories;
  final String? focusedId;
  final MemberFamily? child;
  final PhotosGateway? photos;
  final GlobalKey Function(String id) anchorFor;
  final ValueChanged<Story> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 140),
      children: [
        Row(
          children: [
            const Icon(Icons.auto_stories, color: albumTerracotta, size: 18),
            const SizedBox(width: 8),
            Text(
              'Family Archive · Near Zoom View',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: albumTerracotta),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          nearHeading(stories),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Exploring detailed memories, photographs, and milestones from our family archives with full card layout.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < stories.length; i++) ...[
          _NearCard(
            key: anchorFor(stories[i].id),
            story: stories[i],
            cardOnLeft: i.isEven,
            focused:
                stories[i].id == focusedId || (focusedId == null && i == 0),
            photos: photos,
            onOpen: () => onOpen(stories[i]),
          ),
          if (i == 0 && child != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.groups, size: 16, color: albumTerracotta),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${child!.name} branch fork & merge indicator active',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _NearCard extends StatelessWidget {
  const _NearCard({
    super.key,
    required this.story,
    required this.cardOnLeft,
    required this.focused,
    required this.photos,
    required this.onOpen,
  });

  final Story story;
  final bool cardOnLeft;
  final bool focused;
  final PhotosGateway? photos;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final notes = story.commentCount + story.perspectiveCount;
    final author = (story.authorDisplayName ?? '').trim().isEmpty
        ? 'Member'
        : story.authorDisplayName!.trim();
    final card = Card(
      key: Key('timeline-card-${story.id}'),
      elevation: focused ? 3 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(albumCardRadius),
        side: BorderSide(
          color: focused ? albumTerracotta : albumInk.withValues(alpha: 0.12),
        ),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (focused)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Currently Focused',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: albumTerracotta),
                  ),
                ),
              Text(
                '${story.timeframeStart.year}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (story.personNames.isNotEmpty)
                    _Chip(icon: Icons.person, label: story.personNames.first),
                  if ((story.placeLabel ?? '').isNotEmpty)
                    _Chip(icon: Icons.location_on, label: story.placeLabel!),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                storyTitle(story),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (story.photoPaths.isNotEmpty && photos != null)
                _PhotoRow(
                  paths: story.photoPaths.take(2).toList(),
                  photos: photos!,
                ),
              if (focused) ...[
                const SizedBox(height: 8),
                Text(
                  'Added by $author',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  '${story.photoCount} photos · $notes notes',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: cardOnLeft ? card : const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: focused ? albumTerracotta : albumSage,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: cardOnLeft ? const SizedBox.shrink() : card),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: albumInk.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _PhotoRow extends StatefulWidget {
  const _PhotoRow({required this.paths, required this.photos});

  final List<String> paths;
  final PhotosGateway photos;

  @override
  State<_PhotoRow> createState() => _PhotoRowState();
}

class _PhotoRowState extends State<_PhotoRow> {
  final Map<String, Uint8List> _bytes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final path in widget.paths) {
      try {
        final bytes = await widget.photos.downloadBytes(path);
        if (!mounted) return;
        setState(() => _bytes[path] = bytes);
      } catch (_) {
        // Skip a thumb that cannot be read.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          for (final path in widget.paths)
            if (_bytes[path] != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _bytes[path]!,
                    width: 96,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
