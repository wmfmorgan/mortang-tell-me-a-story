import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/server/app_session.dart';
import 'package:tell_me_a_story/ui/album/album_header.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/manage_families_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/data/timeline_live.dart';
import 'package:tell_me_a_story/features/family/start_timeline_dialog.dart';
import 'package:tell_me_a_story/features/people/person_profile_dialog.dart';
import 'package:tell_me_a_story/features/invites/invite_accept.dart';
import 'package:tell_me_a_story/features/invites/invite_modal.dart';
import 'package:tell_me_a_story/features/timeline/filter/filter_panel.dart';
import 'package:tell_me_a_story/features/timeline/filter/timeline_filter.dart';
import 'package:tell_me_a_story/features/timeline/timeline_branching.dart';
import 'package:tell_me_a_story/features/timeline/timeline_zoom.dart';
import 'package:tell_me_a_story/features/timeline/rails/far_rail.dart';
import 'package:tell_me_a_story/features/timeline/rails/mid_rail.dart';
import 'package:tell_me_a_story/features/timeline/rails/full_card_rail.dart';
import 'package:tell_me_a_story/features/timeline/origin_banner.dart';
import 'package:tell_me_a_story/ui/timeline/empty_timeline.dart';
import 'package:tell_me_a_story/ui/timeline/timeline_entry.dart';

/// The filter sidebar's width at [AlbumBreakpoint.sidebar] and up.
const _sidebarWidth = 300.0;

/// Signed-in home. Far / mid / near rails match the Stitch timeline screens.
class TimelinePage extends StatefulWidget {
  const TimelinePage({
    super.key,
    this.api,
    this.storiesApi,
    this.familiesApi,
    this.photosApi,
    this.live,
    this.manageApi,
    this.peopleApi,
    this.currentUserId,
  });

  final InviteGateway? api;
  final StoriesGateway? storiesApi;
  final FamiliesGateway? familiesApi;
  final PhotosGateway? photosApi;
  final TimelineLive? live;
  final ManageFamiliesGateway? manageApi;
  final PeopleGateway? peopleApi;
  final String? currentUserId;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  late final InviteGateway _api;
  StoriesGateway? _storiesOverride;
  PhotosGateway? _photosOverride;
  TimelineLive? _ownedLive;
  GoRouter? _router;
  var _strippingDecadeView = false;
  String? _familyId = FamilySelection.id;
  List<MemberFamily> _families = const [];
  List<StewardFamily> _stewarded = const [];
  List<TreeFamily> _tree = const [];
  Set<String> _memberIds = FamilyMembership.ids;
  List<Story> _published = const [];
  var _loadingFamily = true;
  var _loadingPublished = true;
  var _inviteHandled = false;
  var _zoom = TimelineZoom.far;
  var _originBannerHidden = false;
  String? _focusedStoryId;
  var _pinchLatched = false;
  var _originQueryHandled = false;
  final _anchorKeys = <String, GlobalKey>{};

  /// Dim-only filter (Q4). It survives zoom changes and resets on a family
  /// switch.
  var _filter = const TimelineFilter();

  StoriesGateway get _stories =>
      widget.storiesApi ?? (_storiesOverride ??= StoriesApi());

  TimelineLive? get _live {
    if (widget.live != null) return widget.live;
    if (widget.storiesApi != null) return null;
    return _ownedLive ??= ServerTimelineLive();
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
    if (!identical(router, _router)) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router;
      _router?.routerDelegate.addListener(_onRouteChanged);
    }
    final uri = _router?.routerDelegate.currentConfiguration.uri;
    if (uri != null) _consumeDecadeView(uri);
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _ownedLive?.dispose();
    super.dispose();
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final uri = _router?.routerDelegate.currentConfiguration.uri;
    if (uri == null || uri.path != AppRoutes.timeline) return;
    if (_consumeDecadeView(uri)) return;
    // go() back to /timeline keeps this State. A family created from Manage
    // families is remembered before navigation and has to replace the one
    // that was open when the user left.
    final remembered = FamilySelection.id;
    if (remembered != null && remembered != _familyId) {
      _selectFamily(remembered);
      return;
    }
    _reloadOpenTimeline();
  }

  /// `?view=decades` means "open on Decades" once. Apply it, then drop the
  /// query so a later return from a story does not snap the zoom back.
  bool _consumeDecadeView(Uri uri) {
    if (uri.queryParameters['view'] != 'decades') return false;
    if (_zoom != TimelineZoom.far) {
      setState(() => _zoom = TimelineZoom.far);
    }
    if (_strippingDecadeView) return true;
    _strippingDecadeView = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _strippingDecadeView = false;
      if (!mounted) return;
      final now = _router?.routerDelegate.currentConfiguration.uri;
      if (now == null ||
          now.path != AppRoutes.timeline ||
          now.queryParameters['view'] != 'decades') {
        return;
      }
      _router?.go(AppRoutes.timeline);
    });
    return true;
  }

  Future<void> _reloadOpenTimeline() async {
    await _loadPublished();
    await _loadFamilies();
  }

  /// Membership id from [InviteGateway.currentFamilyId], unless the saved
  /// family is tree-readable (`list_family_tree` filters with
  /// `is_family_tree_readable`).
  Future<String?> _readableSavedFamily() async {
    final fallback = await _api.currentFamilyId();
    final remembered = FamilySelection.id;
    if (remembered == null || remembered == fallback) return fallback;
    final gateway = widget.familiesApi;
    if (gateway == null) return fallback;
    try {
      final tree = await gateway.listFamilyTree(remembered);
      for (final row in tree) {
        if (row.id == remembered) return remembered;
      }
    } catch (_) {
      // A tree read that throws cannot confirm the saved family. D9 falls back.
      return fallback;
    }
    return fallback;
  }

  Future<void> _bootstrap() async {
    try {
      final id = await _readableSavedFamily();
      if (!mounted) return;
      setState(() {
        _familyId = id;
        _loadingFamily = false;
      });
      await _loadFamilies();
      _watchLive();
      await _loadPublished();
      await _maybeAcceptInvite();
      await _maybeOpenNewTimelineOrigin();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingFamily = false;
        _loadingPublished = false;
      });
    }
  }

  bool get _canStartTimeline {
    final id = _familyId;
    return id != null && _memberIds.contains(id);
  }

  List<Story> get _parentStories {
    final id = _familyId;
    if (id == null) return const [];
    return [
      for (final story in _published)
        if (story.familyId == id && story.status == StoryStatus.published)
          story,
    ];
  }

  String? _sessionUserId() =>
      widget.currentUserId ?? AppSession.instance.currentUserId;

  Future<void> _startTimeline({Story? origin, bool allowChange = true}) async {
    final parent = _currentFamily;
    final userId = _sessionUserId();
    if (parent == null || userId == null) return;
    final manage = widget.manageApi ?? ManageFamiliesApi();
    final people = widget.peopleApi ?? PeopleApi();
    final families = widget.familiesApi ?? FamiliesApi();
    final created = await showStartTimelineDialog(
      context,
      parentId: parent.id,
      parentName: parent.name,
      stories: _parentStories,
      familiesApi: families,
      peopleApi: people,
      manageApi: manage,
      currentUserId: userId,
      origin: origin,
      allowChange: allowChange,
      onWriteStory: () {
        GoRouter.of(context)
            .push('${AppRoutes.newStory}?newTimelineFrom=${parent.id}');
      },
    );
    if (created == null || !mounted) return;
    await _loadFamilies();
    await _loadPublished();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${created.name} timeline created')));
  }

  Future<void> _maybeOpenNewTimelineOrigin() async {
    if (_originQueryHandled || !mounted) return;
    final router = _router;
    if (router == null) return;
    final uri = router.routerDelegate.currentConfiguration.uri;
    final storyId = uri.queryParameters['newTimelineOrigin'];
    if (storyId == null || storyId.isEmpty) return;
    _originQueryHandled = true;
    Story? origin;
    for (final story in _published) {
      if (story.id == storyId) origin = story;
    }
    if (origin != null) {
      await _startTimeline(origin: origin, allowChange: true);
    }
    if (!mounted) return;
    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (path == AppRoutes.timeline) {
      router.go(AppRoutes.timeline);
    }
  }

  Future<void> _loadFamilies() async {
    final familyId = _familyId;
    List<MemberFamily> rows = const [];
    List<StewardFamily> stewarded = const [];
    List<TreeFamily> tree = const [];
    var memberIds = <String>{};
    final gateway = widget.familiesApi;
    try {
      if (gateway != null) {
        rows = await gateway.listMine();
        stewarded = await gateway.listStewarded();
        memberIds = rows.map((row) => row.id).toSet();
        FamilyMembership.remember(memberIds);
      } else if (widget.storiesApi != null) {
        if (familyId != null) {
          rows = [
            MemberFamily(
              id: familyId,
              name: 'Family',
              createdAt: DateTime.utc(2020),
            ),
          ];
          memberIds = {familyId};
          tree = [TreeFamily(id: familyId, name: 'Family')];
        }
      } else {
        final live = FamiliesApi();
        rows = await live.listMine();
        stewarded = await live.listStewarded();
        memberIds = rows.map((row) => row.id).toSet();
        FamilyMembership.remember(memberIds);
        if (familyId != null) {
          tree = await live.listFamilyTree(familyId);
        }
      }
    } catch (_) {
      rows = const [];
      stewarded = const [];
      tree = const [];
      memberIds = {};
    }
    if (gateway != null && familyId != null) {
      try {
        tree = await gateway.listFamilyTree(familyId);
      } catch (_) {
        tree = const [];
      }
    }
    if (!mounted) return;
    // A name for the header only. This row is not a membership.
    if (rows.isEmpty && familyId != null && memberIds.isEmpty) {
      rows = [
        MemberFamily(
          id: familyId,
          name: 'Family',
          createdAt: DateTime.utc(2020),
        ),
      ];
    }
    setState(() {
      _families = rows;
      _stewarded = stewarded;
      _tree = tree;
      _memberIds = memberIds;
    });
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
      final merged = <Story>[...publishedStories(rows)];
      final originId = _tree
          .cast<TreeFamily?>()
          .firstWhere((row) => row?.id == familyId, orElse: () => null)
          ?.originStoryId;
      if (originId != null && !merged.any((story) => story.id == originId)) {
        final origin = await _stories.getPublished(originId);
        if (origin != null && origin.status == StoryStatus.published) {
          merged.add(origin);
        }
      }
      if (!mounted) return;
      setState(() {
        _published = publishedStories(merged);
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
      _tree = const [];
      _filter = const TimelineFilter();
    });
    _watchLive();
    await _loadFamilies();
    await _loadPublished();
    if (!mounted) return;
    final still =
        previousFocus != null &&
        _published.any((story) => story.id == previousFocus);
    if (!still && previousFocus != null) {
      setState(() {
        _focusedStoryId = null;
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
    await InviteModal.show(
      context,
      familyId: familyId,
      familyName: _currentFamily?.name ?? 'Family',
      api: _api,
      people: widget.peopleApi,
    );
  }

  MemberFamily? get _currentFamily {
    final id = _familyId;
    for (final family in _families) {
      if (family.id == id) return family;
    }
    for (final family in _tree) {
      if (family.id == id) {
        return MemberFamily(
          id: family.id,
          name: family.name,
          createdAt: DateTime.utc(2020),
          parentFamilyId: family.parentFamilyId,
        );
      }
    }
    return _families.isEmpty ? null : _families.first;
  }

  bool get _canWrite {
    final id = _familyId;
    if (id == null) return false;
    if (_memberIds.contains(id)) return true;
    return widget.familiesApi == null && widget.storiesApi != null;
  }

  List<TreeFamily> get _relatedMenu {
    return [
      for (final row in _tree)
        if (!_memberIds.contains(row.id)) row,
    ];
  }

  TreeFamily? get _openTree {
    final id = _familyId;
    if (id == null) return null;
    for (final row in _tree) {
      if (row.id == id) return row;
    }
    return null;
  }

  bool get _showOriginBanner {
    if (_originBannerHidden || _loadingFamily || _loadingPublished) {
      return false;
    }
    final open = _openTree;
    if (open == null || open.originStoryId != null) return false;
    final steward = _stewarded.any(
      (row) =>
          row.id == open.id &&
          row.deletedAt == null &&
          (row.role == 'owner' || row.role == 'co_owner'),
    );
    if (!steward) return false;
    if (open.parentFamilyId != null) return true;
    return _published.any((story) => story.familyId == open.id);
  }

  String? get _originParentName {
    final parentId = _openTree?.parentFamilyId;
    if (parentId == null) return null;
    for (final row in _tree) {
      if (row.id == parentId) return row.name;
    }
    return null;
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
    setState(() => _focusedStoryId = id);
  }

  void _reveal(String storyId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _anchorKeys[storyId]?.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(target, alignment: 0.5);
    });
  }

  GlobalKey _anchor(String id) => _anchorKeys.putIfAbsent(id, GlobalKey.new);

  Future<void> _openStory(Story story) async {
    if (GoRouter.maybeOf(context) == null) return;
    await context.push(AppRoutes.storyPath(story.id));
    if (!mounted) return;
    await _loadFamilies();
    await _loadPublished();
  }

  void _openNear(Story story) {
    setState(() {
      _zoom = TimelineZoom.near;
      _focusedStoryId = story.id;
    });
    _reveal(story.id);
  }

  void _openMidOnYear(int year) {
    final rows = dialStories(_published);
    if (rows.isEmpty) return;
    var best = rows.first;
    var bestDelta = (best.publishedStart.year - year).abs();
    for (final story in rows.skip(1)) {
      final delta = (story.publishedStart.year - year).abs();
      if (delta < bestDelta) {
        best = story;
        bestDelta = delta;
      }
    }
    setState(() {
      _zoom = TimelineZoom.mid;
      _focusedStoryId = best.id;
    });
    _reveal(best.id);
  }

  void _zoomIn() {
    final rows = dialStories(_published);
    if (rows.isEmpty) return;
    final focus = _storyById(_focusedStoryId) ?? rows.first;
    final next = zoomIn(_zoom);
    setState(() {
      _focusedStoryId = focus.id;
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
    final showRail = !_loadingFamily && !_loadingPublished && bands.isNotEmpty;
    final sidebar =
        showRail && MediaQuery.sizeOf(context).width >= AlbumBreakpoint.sidebar;
    final dimmed = _dimmed;
    return Scaffold(
      backgroundColor: albumParchment,
      // The rails are not a form: the keyboard (a search field, a dialog)
      // floats over them instead of squeezing the viewport.
      resizeToAvoidBottomInset: false,
      endDrawer: showRail && !sidebar
          ? Drawer(
              key: const Key('timeline-filter-drawer'),
              width: math.min(360, MediaQuery.sizeOf(context).width * 0.9),
              backgroundColor: albumParchment,
              child: SafeArea(child: _filterPanel(dimmed)),
            )
          : null,
      appBar: AlbumHeader(
        page: AlbumHeaderPage.timeline,
        familyName: family?.name ?? 'Family',
        families: _families,
        currentFamilyId: _familyId,
        onFamilySelected: _selectFamily,
        stewarded: _stewarded,
        relatedFamilies: _relatedMenu,
        canWrite: _canWrite,
        onInvite: _canWrite ? _openInvite : null,
        onStartTimeline: _canStartTimeline ? _startTimeline : null,
        onShowDecades: () {
          if (_zoom == TimelineZoom.far) return;
          setState(() => _zoom = TimelineZoom.far);
        },
        manageApi: widget.manageApi,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // A 1×1 pass (web startup, before the view has a real size) makes
          // the footer wrap one glyph per line and overflow this column.
          if (constraints.maxWidth < 8 || constraints.maxHeight < 8) {
            return const SizedBox.shrink();
          }
          final showFooter =
              showRail &&
              _zoom == TimelineZoom.far &&
              constraints.maxHeight > 96;
          final rail = GestureDetector(
            onScaleStart: (_) => _pinchLatched = false,
            onScaleUpdate: _onPinch,
            child: Stack(
              children: [
                Column(
                  children: [
                    if (_showOriginBanner)
                      OriginBanner(
                        familyName: _openTree?.name ?? 'Family',
                        parentName: _originParentName,
                        onChoose: () {
                          final parentId = _openTree?.parentFamilyId;
                          if (parentId != null) _selectFamily(parentId);
                        },
                        onClose: () =>
                            setState(() => _originBannerHidden = true),
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _body(bands, dimmed, sidebar: sidebar),
                          ),
                          if (showRail &&
                              _filter.isActive &&
                              dimmed.length == _published.length)
                            Positioned.fill(child: _noMatch()),
                        ],
                      ),
                    ),
                    if (showFooter)
                      Padding(
                        // Clear the home indicator on iPad and iPhone.
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          12 + MediaQuery.viewPaddingOf(context).bottom,
                        ),
                        child: Text(
                          farFooter(familyName: family?.name ?? 'Family'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: albumInk.withValues(alpha: 0.55),
                              ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
          if (!sidebar) return rail;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: const Key('timeline-filter-sidebar'),
                width: _sidebarWidth,
                child: _filterPanel(dimmed),
              ),
              const VerticalDivider(width: 1, thickness: 1, color: albumRule),
              Expanded(child: rail),
            ],
          );
        },
      ),
    );
  }

  /// Unmatched story ids; empty while no filter is active.
  Set<String> get _dimmed {
    if (!_filter.isActive) return const {};
    return {
      for (final entry in timelineEntries(_published, matches: _filter.matches))
        if (!entry.matched) entry.id,
    };
  }

  void _setFilter(TimelineFilter filter) => setState(() => _filter = filter);

  /// The filters, scrolling above the keyboard: the sidebar at
  /// [AlbumBreakpoint.sidebar] and up, the end drawer below.
  Widget _filterPanel(Set<String> dimmed) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FilterPanel(
        filter: _filter,
        options: filterOptions(_published),
        matched: _published.length - dimmed.length,
        total: _published.length,
        onChanged: _setFilter,
      ),
    );
  }

  /// Opens the end drawer; beside the zoom switch below the sidebar width.
  Widget _filtersButton() {
    return Builder(
      builder: (context) => TextButton.icon(
        key: const Key('timeline-filters-open'),
        onPressed: () => Scaffold.of(context).openEndDrawer(),
        icon: Icon(_filter.isActive ? Icons.filter_alt : Icons.tune),
        label: const Text('Filters'),
      ),
    );
  }

  /// C17 over the still-mounted rail: every story is dimmed, none hidden.
  Widget _noMatch() {
    return Center(
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: albumParchment,
              shape: albumContainerShape(
                AlbumRadius.card,
                side: const BorderSide(color: albumRule),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AlbumSpace.xl),
              child: EmptyTimeline(
                message: 'No stories match these filters.',
                actionLabel: 'Clear filters',
                onAction: () => _setFilter(const TimelineFilter()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    List<DecadeBand> bands,
    Set<String> dimmed, {
    required bool sidebar,
  }) {
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
    final open = _openTree;
    final originId = open?.originStoryId;
    final originLabel = open == null || originId == null
        ? null
        : originTag(open: open, tree: _tree, storyId: originId);
    final branching = railBranching(
      open: open,
      tree: _tree,
      stories: _published,
    );
    return switch (_zoom) {
      TimelineZoom.far => FarRail(
        bands: bands,
        focusedId: _focusedStoryId,
        branching: branching,
        originStoryId: originId,
        onDot: _openStory,
        onEmpty: _zoomOut,
        onYear: _openMidOnYear,
        onFocus: _onDialFocus,
        onOpenBranch: _selectFamily,
        onMid: _zoomIn,
        onFullCards: _openFullCards,
        dimmed: dimmed,
        filtering: _filter.isActive,
        filterAction: sidebar ? null : _filtersButton(),
      ),
      TimelineZoom.mid => MidRail(
        stories: dialStories(_published),
        focusedId: _focusedStoryId,
        branching: branching,
        originStoryId: originId,
        originTag: originLabel,
        anchorFor: _anchor,
        onStub: _openStory,
        onNode: _openNear,
        onEmpty: _zoomOut,
        onFocus: _onDialFocus,
        onOpenBranch: _selectFamily,
        onMacro: _fitAll,
        onFullCards: _zoomIn,
        dimmed: dimmed,
        filterAction: sidebar ? null : _filtersButton(),
      ),
      TimelineZoom.near => FullCardRail(
        stories: dialStories(_published),
        focusedId: _focusedStoryId,
        photos: _photos,
        onPerson: (person) => showPersonProfile(
          context,
          personId: person.id,
          name: person.name,
          people: widget.peopleApi,
          signedInUserId: _sessionUserId(),
        ),
        branching: branching,
        originStoryId: originId,
        originTag: originLabel,
        anchorFor: _anchor,
        onOpen: _openStory,
        onEmpty: _zoomOut,
        onFocus: _onDialFocus,
        onOpenBranch: _selectFamily,
        onMacro: _fitAll,
        onMid: () => setState(() => _zoom = TimelineZoom.mid),
        dimmed: dimmed,
        filterAction: sidebar ? null : _filtersButton(),
      ),
    };
  }
}
