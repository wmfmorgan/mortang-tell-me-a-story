import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/album_theme.dart';
import '../../data/families_api.dart';
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

  Future<void> _openInvite() async {
    var familyId = _familyId;
    if (familyId == null) {
      familyId = await _api.createFamily('Family');
      if (!mounted) return;
      setState(() => _familyId = familyId);
    }
    if (!mounted) return;
    await InviteModal.show(context, familyId: familyId, api: _api);
  }

  void _openNewStory() => context.push(AppRoutes.newStory);

  void _openDrafts() => context.push(AppRoutes.drafts);

  Future<void> _selectFamily(String id) async {
    if (id == _familyId) return;
    setState(() {
      _familyId = id;
      _zoom = TimelineZoom.far;
      _decadeStart = null;
      _focusedStoryId = null;
      _loadingPublished = true;
    });
    _watchLive();
    await _loadPublished();
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

  int _midAnchor(int fallbackDecade) {
    final focusId = _focusedStoryId;
    if (focusId != null) {
      for (final story in _published) {
        if (story.id == focusId) return midAnchorDecade(story.timeframeStart);
      }
    }
    final inDecade = decadeOldestFirst(_published, fallbackDecade);
    if (inDecade.isNotEmpty) {
      return midAnchorDecade(inDecade.last.timeframeStart);
    }
    return fallbackDecade;
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
    _reveal(story.id);
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
    final bands = decadeBands(_published);
    if (bands.isEmpty) return;
    final decade = _activeDecade(bands);
    final newest = decadeNewestFirst(_published, decade);
    setState(() {
      _decadeStart = decade;
      if (_focusedStoryId == null && newest.isNotEmpty) {
        _focusedStoryId = newest.first.id;
      }
      _zoom = zoomIn(_zoom);
    });
    final focus = _focusedStoryId;
    if (focus != null) _reveal(focus);
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
      appBar: _TimelineHeader(
        zoom: _zoom,
        familyName: family?.name ?? 'Family',
        branch: _familyId == null ? null : branchFamily(_families, _familyId!),
        families: _families,
        onSelectFamily: _selectFamily,
        onInvite: _loadingFamily ? null : _openInvite,
        onNewStory: _openNewStory,
        onDrafts: _openDrafts,
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
                      farFooter(
                        familyName: family?.name ?? 'Family',
                        stories: bands.fold<int>(
                          0,
                          (sum, band) => sum + band.stories.length,
                        ),
                        decades: bands.length,
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
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
                  alignment: _zoom == TimelineZoom.far
                      ? Alignment.bottomCenter
                      : Alignment.bottomRight,
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
    final midAnchor = _midAnchor(decade);
    final midStories = midWindowStories(_published, midAnchor);
    return switch (_zoom) {
      TimelineZoom.far => _FarRail(bands: bands, onDot: _openMid),
      TimelineZoom.mid => _MidRail(
        stories: midStories.isNotEmpty
            ? midStories
            : decadeOldestFirst(_published, decade),
        decadeStart: midAnchor,
        focusedId: _focusedStoryId,
        child: child,
        anchorFor: _anchor,
        onStub: _openNear,
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

class _TimelineHeader extends StatelessWidget implements PreferredSizeWidget {
  const _TimelineHeader({
    required this.zoom,
    required this.familyName,
    required this.branch,
    required this.families,
    required this.onSelectFamily,
    required this.onInvite,
    required this.onNewStory,
    required this.onDrafts,
  });

  final TimelineZoom zoom;
  final String familyName;
  final MemberFamily? branch;
  final List<MemberFamily> families;
  final ValueChanged<String> onSelectFamily;
  final VoidCallback? onInvite;
  final VoidCallback onNewStory;
  final VoidCallback onDrafts;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final ink = albumInk;
    return Material(
      color: albumParchment,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: albumInk.withValues(alpha: 0.15)),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(
                              'Tell Me a Story',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 16),
                            if (zoom == TimelineZoom.far) ...[
                              _FamilyPill(name: familyName),
                              if (branch != null) ...[
                                const SizedBox(width: 8),
                                _FamilyPill(
                                  name: '${branch!.name} branch',
                                  quiet: true,
                                ),
                              ],
                            ],
                            if (zoom == TimelineZoom.mid)
                              PopupMenuButton<String>(
                                key: const Key('timeline-family'),
                                onSelected: onSelectFamily,
                                itemBuilder: (context) => [
                                  for (final family in families)
                                    PopupMenuItem(
                                      value: family.id,
                                      child: Text(family.name),
                                    ),
                                ],
                                child: _FamilyPill(
                                  name: familyName,
                                  chevron: true,
                                  menu: true,
                                ),
                              ),
                            const SizedBox(width: 12),
                            _NavLink(label: 'Timeline', selected: true),
                            _NavLink(label: 'Stories'),
                            _NavLink(label: 'Family Members'),
                            _NavLink(label: 'Places'),
                            if (zoom == TimelineZoom.far) ...[
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 220,
                                child: TextField(
                                  key: const Key('timeline-search'),
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Search memories, places...',
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 18,
                                    ),
                                    filled: true,
                                    fillColor: albumParchment,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (zoom == TimelineZoom.mid)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: albumInk.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.search, size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'Search archive...',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (zoom == TimelineZoom.far) ...[
                              OutlinedButton.icon(
                                onPressed: onInvite,
                                icon: const Icon(Icons.person_add, size: 18),
                                label: const Text('Invite'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: onNewStory,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('New story'),
                              ),
                            ] else ...[
                              TextButton(
                                onPressed: onDrafts,
                                child: const Text('Save draft'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: onNewStory,
                                child: const Text('Publish'),
                              ),
                            ],
                            IconButton(
                              onPressed: () {},
                              icon: Icon(Icons.help_outline, color: ink),
                              tooltip: 'Help',
                            ),
                            PopupMenuButton<String>(
                              key: const Key('timeline-more'),
                              tooltip: 'More',
                              onSelected: (value) {
                                if (value == 'drafts') onDrafts();
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'drafts',
                                  child: Text('Drafts'),
                                ),
                              ],
                              icon: Icon(Icons.more_vert, color: ink),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: selected ? albumTerracotta : albumInk.withValues(alpha: 0.7),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          decoration: selected ? TextDecoration.underline : null,
          decorationColor: albumTerracotta,
          decorationThickness: 2,
        ),
      ),
    );
  }
}

class _FamilyPill extends StatelessWidget {
  const _FamilyPill({
    required this.name,
    this.quiet = false,
    this.chevron = false,
    this.menu = false,
  });

  final String name;
  final bool quiet;
  final bool chevron;
  final bool menu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: menu
            ? albumInk.withValues(alpha: 0.05)
            : quiet
            ? albumParchment
            : albumSage.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(menu ? 8 : 20),
        border: Border.all(
          color: albumInk.withValues(alpha: quiet ? 0.12 : 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            menu ? Icons.diversity_3 : Icons.groups,
            size: 16,
            color: albumInk.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: menu ? FontWeight.w600 : null),
          ),
          if (chevron) const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
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
      TimelineZoom.far => 'Pinch or tap a dot to zoom',
      TimelineZoom.mid => 'Pinch · tap stub to zoom in · − to pull back',
      TimelineZoom.near => 'Pinch out · tap − · or Fit all to pull back',
    };
    final fitLabel = zoom == TimelineZoom.far ? 'Fit' : 'Fit all';
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
            if (zoom != TimelineZoom.far) ...[
              IconButton(
                key: const Key('timeline-zoom-in'),
                tooltip: 'Zoom in',
                onPressed: onIn,
                icon: const Icon(Icons.add),
              ),
              if (zoom == TimelineZoom.mid)
                Container(
                  width: 1,
                  height: 24,
                  color: albumInk.withValues(alpha: 0.15),
                ),
              TextButton(
                key: const Key('timeline-fit'),
                onPressed: onFit,
                child: Text(fitLabel),
              ),
            ] else ...[
              TextButton(
                key: const Key('timeline-fit'),
                onPressed: onFit,
                child: Text(fitLabel),
              ),
              IconButton(
                key: const Key('timeline-zoom-in'),
                tooltip: 'Zoom in',
                onPressed: onIn,
                icon: const Icon(Icons.add),
              ),
            ],
          ],
        ),
      ),
    );
    final hintText = Text(hint, style: Theme.of(context).textTheme.labelMedium);
    return Column(
      crossAxisAlignment: zoom == TimelineZoom.far
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.end,
      children: [
        if (zoom == TimelineZoom.near)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Near · full cards',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        if (zoom == TimelineZoom.mid) ...[
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

class _FarRail extends StatelessWidget {
  const _FarRail({required this.bands, required this.onDot});

  final List<DecadeBand> bands;
  final ValueChanged<Story> onDot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 140),
      children: [
        Text(
          'Family Archive Constellation',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          farSubtitle(bands.length),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  width: 2,
                  color: albumInk.withValues(alpha: 0.18),
                ),
              ),
            ),
            Column(
              children: [
                for (var i = 0; i < bands.length; i++)
                  _DecadeRow(
                    band: bands[i],
                    labelOnLeft: i.isEven,
                    onDot: onDot,
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _DecadeRow extends StatelessWidget {
  const _DecadeRow({
    required this.band,
    required this.labelOnLeft,
    required this.onDot,
  });

  final DecadeBand band;
  final bool labelOnLeft;
  final ValueChanged<Story> onDot;

  @override
  Widget build(BuildContext context) {
    final label = Column(
      crossAxisAlignment: labelOnLeft
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          band.label,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: albumTerracotta),
        ),
        Text(
          countWord(band.stories.length, 'story', 'stories'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
    final dots = Column(
      children: [
        for (var i = 0; i < band.stories.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Tooltip(
              message: dotTooltip(band.stories[i]),
              child: GestureDetector(
                key: Key('timeline-dot-${band.stories[i].id}'),
                onTap: () => onDot(band.stories[i]),
                child: Container(
                  width: i == 0 ? 14 : 11,
                  height: i == 0 ? 14 : 11,
                  decoration: BoxDecoration(
                    color: i == 0 ? albumTerracotta : albumSage,
                    shape: BoxShape.circle,
                    border: Border.all(color: albumParchment, width: 2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: labelOnLeft
                ? Align(alignment: Alignment.centerRight, child: label)
                : const SizedBox.shrink(),
          ),
          SizedBox(width: 36, child: dots),
          Expanded(
            child: labelOnLeft
                ? const SizedBox.shrink()
                : Align(alignment: Alignment.centerLeft, child: label),
          ),
        ],
      ),
    );
  }
}

class _MidRail extends StatelessWidget {
  const _MidRail({
    required this.stories,
    required this.decadeStart,
    required this.focusedId,
    required this.child,
    required this.anchorFor,
    required this.onStub,
    required this.onMacro,
    required this.onFullCards,
  });

  final List<Story> stories;
  final int decadeStart;
  final String? focusedId;
  final MemberFamily? child;
  final GlobalKey Function(String id) anchorFor;
  final ValueChanged<Story> onStub;
  final VoidCallback onMacro;
  final VoidCallback onFullCards;

  @override
  Widget build(BuildContext context) {
    final joinAt = child == null
        ? -1
        : closestStoryIndex(stories, child!.createdAt);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 160),
      children: [
        _MidContext(
          heading: midHeading(decadeStart),
          onMacro: onMacro,
          onFullCards: onFullCards,
        ),
        const SizedBox(height: 28),
        for (var i = 0; i < stories.length; i++)
          _StubRow(
            key: anchorFor(stories[i].id),
            story: stories[i],
            cardOnLeft: i.isEven,
            elevated:
                stories[i].id == focusedId || (child != null && i == joinAt),
            quiet: excerpt(stories[i].body, max: 88).isEmpty,
            showBranchRail: child != null && i >= joinAt,
            joinNote: child != null && i == joinAt
                ? '← ${child!.name} union joined archive'
                : null,
            branchLabel: child != null && i == joinAt
                ? '${child!.name} Branch'
                : null,
            onTap: () => onStub(stories[i]),
          ),
      ],
    );
  }
}

class _MidContext extends StatelessWidget {
  const _MidContext({
    required this.heading,
    required this.onMacro,
    required this.onFullCards,
  });

  final String heading;
  final VoidCallback onMacro;
  final VoidCallback onFullCards;

  @override
  Widget build(BuildContext context) {
    final segment = DecoratedBox(
      decoration: BoxDecoration(
        color: albumParchment,
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
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: albumInk.withValues(alpha: 0.12)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          spacing: 16,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_stories,
                      size: 16,
                      color: albumTerracotta,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'MID-ZOOM ARCHIVE VIEW',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: albumTerracotta,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  heading,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
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
                segment,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StubRow extends StatelessWidget {
  const _StubRow({
    super.key,
    required this.story,
    required this.cardOnLeft,
    required this.elevated,
    required this.quiet,
    required this.showBranchRail,
    required this.onTap,
    this.joinNote,
    this.branchLabel,
  });

  final Story story;
  final bool cardOnLeft;
  final bool elevated;
  final bool quiet;
  final bool showBranchRail;
  final String? joinNote;
  final String? branchLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final year = '${story.timeframeStart.year}';
    final place = (story.placeLabel ?? '').trim();
    final line = excerpt(story.body, max: 88);
    final titleStyle = Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontWeight: FontWeight.w700, height: 1.2);
    final card = InkWell(
      key: Key('timeline-stub-${story.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(elevated ? 12 : 4),
      child: elevated
          ? _ElevatedStub(
              year: year,
              place: place,
              title: storyTitle(story),
              line: line,
              showPhoto: story.photoCount > 0,
              alignEnd: cardOnLeft,
              titleStyle: titleStyle,
            )
          : _PlainStub(
              year: year,
              place: place,
              title: storyTitle(story),
              line: quiet ? '' : line,
              alignEnd: cardOnLeft,
              titleStyle: quiet
                  ? Theme.of(context).textTheme.titleMedium
                  : titleStyle,
            ),
    );
    final note = joinNote == null
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(
              left: cardOnLeft ? 24 : 0,
              right: cardOnLeft ? 0 : 24,
              top: 28,
            ),
            child: Text(
              joinNote!,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontStyle: FontStyle.italic, color: albumSage),
            ),
          );
    final label = branchLabel == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 8),
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
    final sideNote = cardOnLeft
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, note],
          )
        : note;
    final sideLabel = cardOnLeft ? const SizedBox.shrink() : label;
    return Opacity(
      opacity: quiet && !elevated ? 0.75 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 36),
        child: Column(
          children: [
            if (!cardOnLeft) sideLabel,
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: cardOnLeft ? card : const SizedBox.shrink(),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: _RailNode(
                      elevated: elevated,
                      quiet: quiet && !elevated,
                      showBranchRail: showBranchRail,
                    ),
                  ),
                  Expanded(child: cardOnLeft ? sideNote : card),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlainStub extends StatelessWidget {
  const _PlainStub({
    required this.year,
    required this.place,
    required this.title,
    required this.line,
    required this.alignEnd,
    required this.titleStyle,
  });

  final String year;
  final String place;
  final String title;
  final String line;
  final bool alignEnd;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final yearChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: albumInk.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        year,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    final placeText = place.isEmpty
        ? null
        : Text(
            place,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: albumInk.withValues(alpha: 0.55)),
          );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
            children: [yearChip, ?placeText],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: titleStyle,
          ),
          if (line.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                line,
                textAlign: alignEnd ? TextAlign.end : TextAlign.start,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: albumInk.withValues(alpha: 0.62),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ElevatedStub extends StatelessWidget {
  const _ElevatedStub({
    required this.year,
    required this.place,
    required this.title,
    required this.line,
    required this.showPhoto,
    required this.alignEnd,
    required this.titleStyle,
  });

  final String year;
  final String place;
  final String title;
  final String line;
  final bool showPhoto;
  final bool alignEnd;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: albumInk.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: albumInk.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: alignEnd
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!alignEnd && showPhoto) ...[
                    const Icon(
                      Icons.photo_library,
                      size: 16,
                      color: albumTerracotta,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (alignEnd && place.isNotEmpty) ...[
                    Text(
                      place,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: albumTerracotta,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: albumTerracotta,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      year,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: albumParchment,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!alignEnd && place.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      place,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: albumTerracotta,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (alignEnd && showPhoto) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.photo_library,
                      size: 16,
                      color: albumTerracotta,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: alignEnd ? TextAlign.end : TextAlign.start,
                style: titleStyle,
              ),
              if (line.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    line,
                    textAlign: alignEnd ? TextAlign.end : TextAlign.start,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: albumInk.withValues(alpha: 0.7)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailNode extends StatelessWidget {
  const _RailNode({
    required this.elevated,
    required this.quiet,
    required this.showBranchRail,
  });

  final bool elevated;
  final bool quiet;
  final bool showBranchRail;

  @override
  Widget build(BuildContext context) {
    final nodeSize = elevated
        ? 20.0
        : quiet
        ? 12.0
        : 16.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Container(width: 2, color: albumInk.withValues(alpha: 0.16)),
          ),
        ),
        if (showBranchRail)
          Positioned(
            top: 0,
            bottom: 0,
            left: 36,
            child: CustomPaint(
              painter: _DashPainter(color: albumSage.withValues(alpha: 0.7)),
              child: const SizedBox(width: 2),
            ),
          ),
        Container(
          width: nodeSize,
          height: nodeSize,
          decoration: BoxDecoration(
            color: quiet
                ? albumInk.withValues(alpha: 0.28)
                : elevated
                ? albumTerracotta.withValues(alpha: 0.22)
                : const Color(0xFFFFF8F6),
            shape: BoxShape.circle,
            border: quiet ? null : Border.all(color: albumTerracotta, width: 2),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: albumInk.withValues(alpha: 0.12),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: quiet
              ? null
              : Center(
                  child: Container(
                    width: elevated ? 8 : 6,
                    height: elevated ? 8 : 6,
                    decoration: const BoxDecoration(
                      color: albumTerracotta,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
        ),
      ],
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
              if (excerpt(story.body).isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  excerpt(story.body),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
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
