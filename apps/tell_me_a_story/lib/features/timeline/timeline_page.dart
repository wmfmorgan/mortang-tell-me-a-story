import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/album_header.dart';
import '../../core/theme/album_theme.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/invite_api.dart';
import '../../data/manage_families_api.dart';
import '../../data/people_api.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import '../../data/timeline_live.dart';
import '../family/start_timeline_dialog.dart';
import '../people/person_profile_dialog.dart';
import '../invites/invite_accept.dart';
import '../invites/invite_modal.dart';
import '../stories/photo_frame.dart';
import '../stories/story_date.dart';
import 'days_attached_callout.dart';
import 'days_card_probe.dart';
import 'days_card_slot.dart';
import 'dial_fade.dart';
import 'far_rail.dart';
import 'hang_parent_callout.dart';
import 'origin_banner.dart';
import 'rail_gutter.dart';
import 'timeline_arrow_keys.dart';
import 'timeline_branching.dart';
import 'timeline_empty_tap.dart';
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

  String? _sessionUserId() {
    if (widget.currentUserId != null) return widget.currentUserId;
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

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
    return Scaffold(
      backgroundColor: albumParchment,
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
          return GestureDetector(
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
                    Expanded(child: _body(bands)),
                    if (showFooter)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
        },
      ),
    );
  }

  Widget _body(List<DecadeBand> bands) {
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
        header: _DialSubheader(
          selected: TimelineZoom.far,
          onMacro: () {},
          onMid: _zoomIn,
          onFullCards: _openFullCards,
        ),
      ),
      TimelineZoom.mid => _MidRail(
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
      ),
      TimelineZoom.near => _FullCardRail(
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
      ),
    };
  }
}

class _MidRail extends StatefulWidget {
  const _MidRail({
    required this.stories,
    required this.focusedId,
    required this.branching,
    this.originStoryId,
    this.originTag,
    required this.anchorFor,
    required this.onStub,
    required this.onNode,
    required this.onEmpty,
    required this.onFocus,
    required this.onOpenBranch,
    required this.onMacro,
    required this.onFullCards,
  });

  final List<Story> stories;
  final String? focusedId;
  final RailBranching branching;
  final String? originStoryId;
  final String? originTag;
  final GlobalKey Function(String id) anchorFor;
  final ValueChanged<Story> onStub;
  final ValueChanged<Story> onNode;
  final VoidCallback onEmpty;
  final ValueChanged<String> onFocus;
  final ValueChanged<String> onOpenBranch;
  final VoidCallback onMacro;
  final VoidCallback onFullCards;

  @override
  State<_MidRail> createState() => _MidRailState();
}

class _MidRailState extends State<_MidRail> {
  final _viewportKey = GlobalKey();
  final _scroll = ScrollController();
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
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _step(int direction) {
    final stories = widget.stories;
    if (stories.isEmpty) return;
    final current = _centerId ?? widget.focusedId ?? stories.first.id;
    var index = stories.indexWhere((story) => story.id == current);
    if (index < 0) index = 0;
    final next = index + direction;
    final target = next < 0 || next >= stories.length
        ? null
        : widget.anchorFor(stories[next].id).currentContext;
    scrollDialStep(controller: _scroll, direction: direction, target: target);
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

  @override
  Widget build(BuildContext context) {
    return ArrowKeys(
      onStep: _step,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: _DialSubheader(
              selected: TimelineZoom.mid,
              onMacro: widget.onMacro,
              onMid: () {},
              onFullCards: widget.onFullCards,
            ),
          ),
          Expanded(
            child: EmptyTap(
              onTap: widget.onEmpty,
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
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(24, pad, 24, pad),
                          children: [
                            for (var i = 0; i < widget.stories.length; i++)
                              _DialRow(
                                key: widget.anchorFor(widget.stories[i].id),
                                story: widget.stories[i],
                                frame: widget.branching.frameFor(
                                  widget.stories[i],
                                ),
                                originTag:
                                    widget.stories[i].id == widget.originStoryId
                                    ? widget.originTag
                                    : null,
                                onOpenBranch: widget.onOpenBranch,
                                cardOnLeft: i.isEven,
                                focused: widget.stories[i].id == _centerId,
                                opacity:
                                    _opacities[widget.stories[i].id] ??
                                    (widget.stories[i].id == _centerId
                                        ? 1
                                        : 0.35),
                                onTap: () => widget.onStub(widget.stories[i]),
                                onNode: () => widget.onNode(widget.stories[i]),
                              ),
                          ],
                        );
                      },
                    ),
                    const DialFade(top: true),
                    const DialFade(top: false),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Terracotta segment that slides between Decades, Years, and Days.
///
/// Each zoom replaces the rail, so the last selection is remembered here
/// and the new switch slides from that segment.
class _ZoomSwitch extends StatefulWidget {
  const _ZoomSwitch({
    required this.selected,
    required this.onMacro,
    required this.onMid,
    required this.onFullCards,
  });

  final TimelineZoom selected;
  final VoidCallback onMacro;
  final VoidCallback onMid;
  final VoidCallback onFullCards;

  static TimelineZoom? _last;

  static int _indexOf(TimelineZoom zoom) {
    return switch (zoom) {
      TimelineZoom.far => 0,
      TimelineZoom.mid => 1,
      TimelineZoom.near => 2,
    };
  }

  @override
  State<_ZoomSwitch> createState() => _ZoomSwitchState();
}

class _ZoomSwitchState extends State<_ZoomSwitch>
    with SingleTickerProviderStateMixin {
  final _stackKey = GlobalKey();
  final _keys = List<GlobalKey>.generate(3, (_) => GlobalKey());
  late final AnimationController _controller;
  late int _fromIndex;
  late int _toIndex;
  Rect? _fromRect;
  Rect? _toRect;
  var _started = false;

  @override
  void initState() {
    super.initState();
    _fromIndex = _ZoomSwitch._indexOf(_ZoomSwitch._last ?? widget.selected);
    _toIndex = _ZoomSwitch._indexOf(widget.selected);
    _ZoomSwitch._last = widget.selected;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void didUpdateWidget(covariant _ZoomSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    _fromIndex = _ZoomSwitch._indexOf(oldWidget.selected);
    _toIndex = _ZoomSwitch._indexOf(widget.selected);
    _ZoomSwitch._last = widget.selected;
    _fromRect = null;
    _toRect = null;
    _started = false;
    _controller.value = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Rect? _localRect(int index) {
    final box = _keys[index].currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.hasSize || !stack.hasSize) {
      return null;
    }
    final topLeft = stack.globalToLocal(box.localToGlobal(Offset.zero));
    return topLeft & box.size;
  }

  void _place() {
    if (!mounted) return;
    final from = _localRect(_fromIndex);
    final to = _localRect(_toIndex);
    if (from == null || to == null) return;
    if (_fromRect == from && _toRect == to) return;
    setState(() {
      _fromRect = from;
      _toRect = to;
    });
    if (_started || _fromIndex == _toIndex) return;
    _started = true;
    _controller.forward(from: 0);
  }

  Color _foreground(int index) {
    const dim = Color(0xB32C2416);
    final t = _fromIndex == _toIndex
        ? 1.0
        : Curves.easeOutCubic.transform(_controller.value);
    if (index == _toIndex && index == _fromIndex) return albumParchment;
    if (index == _toIndex) return Color.lerp(dim, albumParchment, t)!;
    if (index == _fromIndex) return Color.lerp(albumParchment, dim, t)!;
    return dim;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _place());
    final choices = [
      (
        key: 'timeline-zoom-macro',
        label: 'Decades',
        zoom: TimelineZoom.far,
        onPressed: widget.onMacro,
      ),
      (
        key: 'timeline-zoom-mid',
        label: 'Years',
        zoom: TimelineZoom.mid,
        onPressed: widget.onMid,
      ),
      (
        key: 'timeline-zoom-full',
        label: 'Days',
        zoom: TimelineZoom.near,
        onPressed: widget.onFullCards,
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: albumInk.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _fromIndex == _toIndex
                ? 1.0
                : Curves.easeOutCubic.transform(_controller.value);
            final rect = _fromRect == null || _toRect == null
                ? null
                : Rect.lerp(_fromRect, _toRect, t);
            return Stack(
              key: _stackKey,
              children: [
                if (rect != null)
                  Positioned(
                    left: rect.left,
                    top: rect.top,
                    width: rect.width,
                    height: rect.height,
                    child: const DecoratedBox(
                      key: Key('timeline-zoom-pill'),
                      decoration: ShapeDecoration(
                        color: albumTerracotta,
                        shape: StadiumBorder(),
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < choices.length; i++)
                      KeyedSubtree(
                        key: _keys[i],
                        child: TextButton(
                          key: Key(choices[i].key),
                          onPressed: widget.selected == choices[i].zoom
                              ? () {}
                              : choices[i].onPressed,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.transparent,
                            foregroundColor: _foreground(i),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(choices[i].label),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DialSubheader extends StatelessWidget {
  const _DialSubheader({
    required this.selected,
    required this.onMacro,
    required this.onMid,
    required this.onFullCards,
  });

  final TimelineZoom selected;
  final VoidCallback onMacro;
  final VoidCallback onMid;
  final VoidCallback onFullCards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        spacing: 16,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: _ZoomSwitch(
                  selected: selected,
                  onMacro: onMacro,
                  onMid: onMid,
                  onFullCards: onFullCards,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialRow extends StatelessWidget {
  const _DialRow({
    super.key,
    required this.story,
    required this.frame,
    required this.cardOnLeft,
    required this.focused,
    required this.opacity,
    required this.onTap,
    required this.onNode,
    this.originTag,
    required this.onOpenBranch,
  });

  final Story story;
  final StoryFrame frame;
  final bool cardOnLeft;
  final String? originTag;
  final ValueChanged<String> onOpenBranch;
  final bool focused;
  final double opacity;
  final VoidCallback onTap;
  final VoidCallback onNode;

  @override
  Widget build(BuildContext context) {
    final year = storyDateLabelFor(story);
    final place = (story.placeLabel ?? '').trim();
    final photos = story.photoCount > 0
        ? countWord(story.photoCount, 'photo', 'photos')
        : null;
    final card = InkWell(
      key: Key('timeline-stub-${story.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        frame.branchesStory
            ? albumCardRadius
            : focused
            ? 12
            : 4,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: frame.branchesStory
              ? BoxDecoration(
                  color: albumParchment,
                  borderRadius: BorderRadius.circular(albumCardRadius),
                  border: Border.all(color: branchMoss, width: 1),
                )
              : focused
              ? BoxDecoration(
                  color: const Color(0xFFFFF8F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: frame.parent != null ? branchMoss : albumTerracotta,
                    width: 2,
                  ),
                  boxShadow: frame.parent != null
                      ? null
                      : [
                          BoxShadow(
                            color: albumInk.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                )
              : const BoxDecoration(),
          child: Padding(
            padding: EdgeInsets.all(
              frame.branchesStory || focused ? calloutCardPadding : 0,
            ),
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
                if (originTag != null)
                  Text(
                    originTag!,
                    key: Key('timeline-origin-tag-${story.id}'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: albumSage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
    final mark = Container(
      width: focused ? midDotFocusedDiameter : midDotDiameter,
      height: focused ? midDotFocusedDiameter : midDotDiameter,
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
    // The branch ring sits just outside the dot. Extra slop belongs only on
    // a plain node, where it cannot cover that stroke.
    Widget nodeHit({required bool slop}) {
      final hit = GestureDetector(
        key: Key('timeline-mid-node-${story.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onNode,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: slop
              ? Padding(padding: const EdgeInsets.all(8), child: mark)
              : mark,
        ),
      );
      // The square bounds cover the ring on the diagonals. Only the disk
      // should open the story.
      return slop ? hit : ClipOval(child: hit);
    }

    final placed = frame.branchesStory
        ? placeBranchCallout(
            context: context,
            frame: frame,
            side: cardOnLeft ? CalloutSide.left : CalloutSide.right,
            dot: nodeHit(slop: false),
            dotDiameter: focused ? midDotFocusedDiameter : midDotDiameter,
            centerToLane: calloutLaneOffset,
            minCardFromRail: calloutFromRail,
            maxLabelWidth: calloutLabelWidthDial,
            onOpen: onOpenBranch,
          )
        : null;
    final pushPad = placed == null
        ? EdgeInsets.zero
        : EdgeInsets.only(
            left: cardOnLeft ? 0 : placed.push,
            right: cardOnLeft ? placed.push : 0,
          );
    final parentOverlay = frame.parent == null
        ? null
        : parentCalloutOverlay(
            context: context,
            frame: frame,
            side: cardOnLeft ? CalloutSide.left : CalloutSide.right,
            maxLabelWidth: calloutLabelWidthDial,
            onOpen: onOpenBranch,
          );
    Widget sideCard(bool show) {
      if (!show) return const SizedBox.shrink();
      final shown = parentOverlay == null
          ? card
          : HangParentCallout(
              anchor: parentOverlay.anchor,
              cardOnLeft: cardOnLeft,
              balance: placed == null,
              callout: parentOverlay.child,
              card: card,
            );
      if (placed == null) return shown;
      return Padding(padding: pushPad, child: shown);
    }

    Widget sideLabel(bool show) {
      if (!show || placed == null) return const SizedBox.shrink();
      return placed.lane;
    }

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Stack(
          alignment: placed == null ? Alignment.center : Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(child: RailGutter()),
            if (placed == null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: sideCard(cardOnLeft),
                    ),
                  ),
                  const SizedBox(width: calloutGutter),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: sideCard(!cardOnLeft),
                    ),
                  ),
                ],
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BranchCalloutTarget(
                    frame: frame,
                    onOpen: onOpenBranch,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: sideLabel(cardOnLeft),
                          ),
                        ),
                        SizedBox(
                          width: calloutGutter,
                          height: calloutHit,
                          child: Center(child: placed.ringHit),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: sideLabel(!cardOnLeft),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: sideCard(cardOnLeft),
                        ),
                      ),
                      const SizedBox(width: calloutGutter),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: sideCard(!cardOnLeft),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            if (placed != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(child: placed.dot),
              )
            else
              nodeHit(slop: true),
          ],
        ),
      ),
    );
  }
}

class _FullCardRail extends StatefulWidget {
  const _FullCardRail({
    required this.stories,
    required this.focusedId,
    required this.photos,
    required this.branching,
    this.originStoryId,
    this.originTag,
    required this.anchorFor,
    required this.onOpen,
    required this.onEmpty,
    required this.onFocus,
    required this.onOpenBranch,
    required this.onMacro,
    required this.onMid,
    this.onPerson,
  });

  final List<Story> stories;
  final String? focusedId;
  final PhotosGateway? photos;
  final RailBranching branching;
  final String? originStoryId;
  final String? originTag;
  final GlobalKey Function(String id) anchorFor;
  final ValueChanged<Story> onOpen;
  final VoidCallback onEmpty;
  final ValueChanged<String> onFocus;
  final ValueChanged<String> onOpenBranch;
  final VoidCallback onMacro;
  final VoidCallback onMid;
  final void Function(({String id, String name}) person)? onPerson;

  @override
  State<_FullCardRail> createState() => _FullCardRailState();
}

class _FullCardRailState extends State<_FullCardRail> {
  final _viewportKey = GlobalKey();
  final _scroll = ScrollController();
  String? _centerId;
  Map<String, double> _opacities = const {};

  @override
  void initState() {
    super.initState();
    _centerId = widget.focusedId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerThenMeasure());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _step(int direction) {
    final stories = widget.stories;
    if (stories.isEmpty) return;
    final current = _centerId ?? widget.focusedId ?? stories.first.id;
    var index = stories.indexWhere((story) => story.id == current);
    if (index < 0) index = 0;
    final next = index + direction;
    final target = next < 0 || next >= stories.length
        ? null
        : widget.anchorFor(stories[next].id).currentContext;
    scrollDialStep(controller: _scroll, direction: direction, target: target);
  }

  void _centerThenMeasure() {
    if (!mounted) return;
    final id = _centerId;
    final target = id == null ? null : widget.anchorFor(id).currentContext;
    if (target != null && target.mounted) {
      Scrollable.ensureVisible(target, alignment: 0.5, duration: Duration.zero);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
  }

  @override
  void didUpdateWidget(covariant _FullCardRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.focusedId;
    if (next != null && next != oldWidget.focusedId) {
      _centerId = next;
    }
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
    final origin = viewport.localToGlobal(Offset.zero);
    final centerY = origin.dy + viewport.size.height / 2;
    String? bestId;
    var best = double.infinity;
    final opacities = <String, double>{};
    for (final story in widget.stories) {
      final row =
          widget.anchorFor(story.id).currentContext?.findRenderObject()
              as RenderBox?;
      if (row == null || !row.hasSize) continue;
      final top = row.localToGlobal(Offset.zero).dy;
      opacities[story.id] = fullCardOpacity(
        rowTop: top,
        rowHeight: row.size.height,
        viewportTop: origin.dy,
        viewportHeight: viewport.size.height,
      );
      final distance = (top + row.size.height / 2 - centerY).abs();
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

  @override
  Widget build(BuildContext context) {
    return ArrowKeys(
      onStep: _step,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: _DialSubheader(
              selected: TimelineZoom.near,
              onMacro: widget.onMacro,
              onMid: widget.onMid,
              onFullCards: () {},
            ),
          ),
          Expanded(
            child: EmptyTap(
              onTap: widget.onEmpty,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 800;
                    final pad = constraints.maxHeight / 2;
                    final gap = constraints.maxWidth < 720 ? 32.0 : 80.0;
                    return Stack(
                      key: _viewportKey,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Align(
                              alignment: wide
                                  ? Alignment.center
                                  : Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(left: wide ? 0 : 13),
                                child: Container(
                                  key: const Key('timeline-spine'),
                                  width: 2,
                                  color: albumInk.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        ListView(
                          controller: _scroll,
                          scrollCacheExtent: const ScrollCacheExtent.pixels(
                            100000,
                          ),
                          padding: EdgeInsets.fromLTRB(
                            wide ? 24 : 8,
                            pad,
                            24,
                            pad,
                          ),
                          children: [
                            for (var i = 0; i < widget.stories.length; i++)
                              _FullCardRow(
                                key: widget.anchorFor(widget.stories[i].id),
                                story: widget.stories[i],
                                frame: widget.branching.frameFor(
                                  widget.stories[i],
                                ),
                                cardOnLeft: i.isEven,
                                wide: wide,
                                originTag:
                                    widget.stories[i].id == widget.originStoryId
                                    ? widget.originTag
                                    : null,
                                onOpenBranch: widget.onOpenBranch,
                                onPerson: widget.onPerson,
                                focused: widget.stories[i].id == _centerId,
                                opacity:
                                    _opacities[widget.stories[i].id] ??
                                    (widget.stories[i].id == _centerId
                                        ? 1
                                        : 0.4),
                                gap: gap,
                                photos: widget.photos,
                                onOpen: () => widget.onOpen(widget.stories[i]),
                              ),
                          ],
                        ),
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    albumParchment,
                                    Color(0x00FBF7F2),
                                    Color(0x00FBF7F2),
                                    albumParchment,
                                  ],
                                  stops: [0, 0.18, 0.82, 1],
                                ),
                              ),
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
        ],
      ),
    );
  }
}

const _narrowFullDotColumn = 28.0;

class _FullCardRow extends StatelessWidget {
  const _FullCardRow({
    super.key,
    required this.story,
    required this.frame,
    required this.cardOnLeft,
    required this.wide,
    required this.focused,
    required this.opacity,
    required this.gap,
    required this.photos,
    required this.onOpen,
    this.originTag,
    required this.onOpenBranch,
    this.onPerson,
  });

  final Story story;
  final StoryFrame frame;
  final bool cardOnLeft;
  final bool wide;
  final String? originTag;
  final ValueChanged<String> onOpenBranch;
  final void Function(({String id, String name}) person)? onPerson;
  final bool focused;
  final double opacity;
  final double gap;
  final PhotosGateway? photos;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (frame.parent == null) return _row(context, null);
    // Same side as the card, matching the days child callout. The 45° run
    // leaves the top center toward that side.
    final side = !wide || !cardOnLeft ? CalloutSide.right : CalloutSide.left;
    final overlay = parentCalloutOverlay(
      context: context,
      frame: frame,
      side: side,
      maxLabelWidth: calloutLabelWidthDial,
      onOpen: onOpenBranch,
      fontSize: calloutDaysParentFontSize,
      extraRun: 0,
    );
    return DaysAttachedCallout(
      anchor: overlay.anchor,
      callout: Opacity(opacity: opacity.clamp(0, 1), child: overlay.child),
      body: (slot) => _row(context, slot),
    );
  }

  Widget _row(BuildContext context, DaysCardSlot? slot) {
    final storyCard = _FullCard(
      story: story,
      focused: focused,
      branched: frame.branchesStory,
      parentOrigin: frame.parent != null,
      photos: photos,
      originTag: originTag,
      onOpen: onOpen,
      onPerson: onPerson,
    );
    // Narrow rows skip the scale. A 1.05 card overflows the right edge,
    // and focus there is the 20px dot plus the focused card chrome.
    // A branch card and a parent-origin card stay at 1 so focus does not
    // shift them.
    final scale =
        wide && focused && !frame.branchesStory && frame.parent == null
        ? 1.05
        : 1.0;
    final scaled = Transform.scale(scale: scale, child: storyCard);
    final card = Opacity(
      opacity: opacity.clamp(0, 1),
      child: slot == null
          ? scaled
          : DaysCardProbe(slot: slot, scale: scale, child: scaled),
    );
    final dot = _FullCardDot(
      key: Key('timeline-full-dot-${story.id}'),
      focused: focused,
      branched: frame.branchesStory,
    );
    final placed = frame.branchesStory
        ? placeBranchCallout(
            context: context,
            frame: frame,
            side: !wide || !cardOnLeft ? CalloutSide.right : CalloutSide.left,
            dot: GestureDetector(onTap: onOpen, child: dot),
            dotDiameter: focused ? fullDotFocusedDiameter : fullDotDiameter,
            centerToLane: wide ? calloutLaneOffset : calloutHit / 2,
            minCardFromRail: wide ? calloutFromRail : null,
            maxLabelWidth: calloutLabelWidthDial,
            onOpen: onOpenBranch,
          )
        : null;
    if (placed == null) {
      if (!wide) {
        return Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: _narrowFullDotColumn,
                child: Align(alignment: Alignment.center, child: dot),
              ),
              Expanded(child: card),
            ],
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.92,
                      child: cardOnLeft ? card : const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(width: calloutGutter),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.92,
                      child: cardOnLeft ? const SizedBox.shrink() : card,
                    ),
                  ),
                ),
              ],
            ),
            dot,
          ],
        ),
      );
    }
    final pushPad = EdgeInsets.only(
      left: cardOnLeft ? 0 : placed.push,
      right: cardOnLeft ? placed.push : 0,
    );
    if (!wide) {
      return Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                BranchCalloutTarget(
                  frame: frame,
                  onOpen: onOpenBranch,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: calloutHit,
                        height: calloutHit,
                        child: placed.ringHit,
                      ),
                      Expanded(child: placed.lane),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: calloutHit + placed.push),
                  child: card,
                ),
              ],
            ),
            Positioned(
              left: 0,
              top: 0,
              width: calloutHit,
              height: calloutHit,
              child: Center(child: placed.dot),
            ),
          ],
        ),
      );
    }
    Widget fraction(Widget child) {
      return FractionallySizedBox(widthFactor: 0.92, child: child);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BranchCalloutTarget(
                frame: frame,
                onOpen: onOpenBranch,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: cardOnLeft
                            ? fraction(placed.lane)
                            : const SizedBox.shrink(),
                      ),
                    ),
                    SizedBox(
                      width: calloutGutter,
                      height: calloutHit,
                      child: Center(child: placed.ringHit),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: cardOnLeft
                            ? const SizedBox.shrink()
                            : fraction(placed.lane),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: cardOnLeft
                          ? fraction(Padding(padding: pushPad, child: card))
                          : const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: calloutGutter),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: cardOnLeft
                          ? const SizedBox.shrink()
                          : fraction(Padding(padding: pushPad, child: card)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(child: placed.dot),
          ),
        ],
      ),
    );
  }
}

class _FullCardDot extends StatelessWidget {
  const _FullCardDot({
    super.key,
    required this.focused,
    required this.branched,
  });

  final bool focused;
  final bool branched;

  @override
  Widget build(BuildContext context) {
    final size = focused ? fullDotFocusedDiameter : fullDotDiameter;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: focused ? albumTerracotta : albumParchment,
        border: focused
            ? null
            : Border.all(color: albumInk.withValues(alpha: 0.4), width: 2),
        boxShadow: focused && !branched
            ? const [
                BoxShadow(
                  color: Color(0xFFF5DED6),
                  spreadRadius: 8,
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
    );
  }
}

class _FullCard extends StatelessWidget {
  const _FullCard({
    required this.story,
    required this.focused,
    required this.branched,
    required this.parentOrigin,
    required this.photos,
    required this.onOpen,
    this.originTag,
    this.onPerson,
  });

  final Story story;
  final bool focused;
  final bool branched;
  final bool parentOrigin;
  final PhotosGateway? photos;
  final VoidCallback onOpen;
  final String? originTag;
  final void Function(({String id, String name}) person)? onPerson;

  @override
  Widget build(BuildContext context) {
    final notes = story.commentCount + story.perspectiveCount;
    final author = (story.authorDisplayName ?? '').trim().isEmpty
        ? 'Member'
        : story.authorDisplayName!.trim();
    final paths = focused
        ? (story.photoPaths.isEmpty
              ? const <String>[]
              : [story.photoPaths.first])
        : story.photoPaths.take(2).toList();
    return Material(
      color: branched ? albumParchment : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(albumCardRadius),
        side: BorderSide(
          color: branched || (focused && parentOrigin)
              ? branchMoss
              : focused
              ? albumTerracotta
              : albumInk.withValues(alpha: 0.2),
          width: branched ? 1 : (focused ? 2 : 1),
        ),
      ),
      child: InkWell(
        key: Key('timeline-card-${story.id}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(albumCardRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(albumCardRadius),
            boxShadow: branched || (focused && parentOrigin)
                ? null
                : [
                    BoxShadow(
                      color: albumInk.withValues(alpha: focused ? 0.08 : 0.04),
                      blurRadius: focused ? 24 : 8,
                      offset: Offset(0, focused ? 8 : 2),
                    ),
                    if (focused && !parentOrigin)
                      BoxShadow(
                        color: const Color(0xFFF5DED6).withValues(alpha: 0.3),
                        spreadRadius: 4,
                        blurRadius: 0,
                      ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      storyDateLabelFor(story),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: albumTerracotta,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final person
                            in story.people.isNotEmpty
                                ? story.people
                                : [
                                    for (final name in story.personNames)
                                      (id: '', name: name),
                                  ])
                          GestureDetector(
                            key: Key(
                              'timeline-person-${story.id}-${person.name}',
                            ),
                            onTap: person.id.isEmpty || onPerson == null
                                ? null
                                : () => onPerson!(person),
                            child: _FullChip(
                              icon: Icons.person,
                              label: person.name,
                              filled: focused,
                            ),
                          ),
                        if ((story.placeLabel ?? '').isNotEmpty)
                          _FullChip(
                            icon: Icons.location_on,
                            label: story.placeLabel!,
                            filled: focused,
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (originTag != null)
                  Text(
                    originTag!,
                    key: Key('timeline-origin-tag-${story.id}'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: albumSage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  story.title ?? '',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    height: 1.15,
                  ),
                ),
                if (paths.isNotEmpty && photos != null)
                  _CardPhotos(paths: paths, photos: photos!, focused: focused),
                if (focused) ...[
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: albumInk.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Added by $author',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 12,
                                  color: albumInk.withValues(alpha: 0.7),
                                ),
                          ),
                          Text(
                            '${countWord(story.photoCount, 'photo', 'photos')} · ${countWord(notes, 'note', 'notes')}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: albumTerracotta,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FullChip extends StatelessWidget {
  const _FullChip({
    required this.icon,
    required this.label,
    required this.filled,
  });

  final IconData icon;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(fontSize: 12, color: albumInk.withValues(alpha: 0.75));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFF5DED6) : const Color(0xFFF5ECE9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textMax = constraints.maxWidth.isFinite
              ? (constraints.maxWidth - 26)
                    .clamp(0.0, constraints.maxWidth)
                    .toDouble()
              : double.infinity;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: albumInk.withValues(alpha: filled ? 0.85 : 0.7),
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: textMax),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CardPhotos extends StatefulWidget {
  const _CardPhotos({
    required this.paths,
    required this.photos,
    required this.focused,
  });

  final List<String> paths;
  final PhotosGateway photos;
  final bool focused;

  @override
  State<_CardPhotos> createState() => _CardPhotosState();
}

class _CardPhotosState extends State<_CardPhotos> {
  final Map<String, Uint8List> _bytes = {};
  final Map<String, double> _aspect = {};

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
        setState(() {
          _bytes[path] = bytes;
          _aspect[path] = encodedPhotoAspect(bytes) ?? (16 / 9);
        });
      } catch (_) {
        // A photo that cannot be read stays out of the well.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = [
      for (final path in widget.paths)
        if (_bytes[path] != null) path,
    ];
    if (ready.isEmpty) return const SizedBox.shrink();
    final shared = ready.length > 1;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gaps = 12.0 * (ready.length - 1);
          final cellWidth = ready.length == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - gaps) / ready.length;
          final height = shared
              ? cardPhotoRowHeight(focused: widget.focused)
              : cardPhotoHeight(
                  width: cellWidth,
                  imageAspect: _aspect[ready.first] ?? (16 / 9),
                  focused: widget.focused,
                );
          return SizedBox(
            key: Key('timeline-card-photos-${ready.first}'),
            height: height,
            child: Row(
              children: [
                for (var i = 0; i < ready.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColoredBox(
                          color: albumParchment,
                          child: Image.memory(
                            _bytes[ready[i]]!,
                            height: height,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
