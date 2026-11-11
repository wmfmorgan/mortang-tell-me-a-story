import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/photos_repository.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/app_session_provider.dart';
import 'package:tell_me_a_story/core/session/family_membership.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/session/timeline_live.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/core/widgets/timeline/empty_timeline.dart';
import 'package:tell_me_a_story/core/widgets/timeline/timeline_entry.dart';
import 'package:tell_me_a_story/features/family/presentation/start_timeline_dialog.dart';
import 'package:tell_me_a_story/features/invites/presentation/invite_accept.dart';
import 'package:tell_me_a_story/features/invites/presentation/invite_modal.dart';
import 'package:tell_me_a_story/features/people/presentation/person_profile_dialog.dart';
import 'package:tell_me_a_story/features/timeline/presentation/filter/filter_panel.dart';
import 'package:tell_me_a_story/features/timeline/presentation/filter/timeline_filter.dart';
import 'package:tell_me_a_story/features/timeline/presentation/origin_banner.dart';
import 'package:tell_me_a_story/features/timeline/presentation/rails/far_rail.dart';
import 'package:tell_me_a_story/features/timeline/presentation/rails/full_card_rail.dart';
import 'package:tell_me_a_story/features/timeline/presentation/rails/mid_rail.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_branching.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_providers.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_zoom.dart';

/// The filter sidebar's width at [AlbumBreakpoint.sidebar] and up, the
/// drawer's widest: wide enough for the whole C15 search hint.
const _filterPanelWidth = 360.0;

/// Signed-in home. Far / mid / near rails match the Stitch timeline screens.
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key, this.currentUserId});

  final String? currentUserId;

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

/// Where the first family decision stands.
enum _Boot { loading, ready, failed }

/// What the open timeline shows, from the timeline providers.
class _TimelineData {
  const _TimelineData({
    this.families = const [],
    this.stewarded = const [],
    this.tree = const [],
    this.memberIds = const {},
    this.published = const [],
    this.loading = false,
  });

  final List<MemberFamily> families;
  final List<StewardFamily> stewarded;
  final List<TreeFamily> tree;
  final Set<String> memberIds;
  final List<Story> published;
  final bool loading;
}

/// Still waiting for a first value (a refresh keeps the previous one).
bool _pending(AsyncValue<Object?>? value) =>
    value != null && value.isLoading && !value.hasValue && !value.hasError;

/// A name for the header only when no membership row came back. This row is
/// not a membership.
List<MemberFamily> _headerRows(List<MemberFamily> rows, String? familyId) {
  if (rows.isNotEmpty || familyId == null) return rows;
  return [
    MemberFamily(id: familyId, name: 'Family', createdAt: DateTime.utc(2020)),
  ];
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  GoRouter? _router;
  var _strippingDecadeView = false;
  String? _familyId;
  var _boot = _Boot.loading;
  var _data = const _TimelineData(loading: true);
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

  /// The docked filter sidebar at [AlbumBreakpoint.sidebar] and up. It
  /// starts closed and stays as the user left it across zooms (owner,
  /// 2026-11-08).
  var _sidebarOpen = false;

  @override
  void initState() {
    super.initState();
    _familyId = ref.read(familySelectionProvider);
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
    final remembered = ref.read(familySelectionProvider);
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

  /// Refetches the membership, the open tree and its stories; the rail keeps
  /// showing the current rows meanwhile.
  void _reloadOpenTimeline() {
    if (_boot != _Boot.ready) return;
    ref.invalidate(timelineMembershipProvider);
    final familyId = _familyId;
    if (familyId == null) return;
    ref.invalidate(timelineTreeProvider(familyId));
    ref.invalidate(timelinePublishedProvider(familyId));
  }

  /// The open family's published stories once they settle; empty when the
  /// read fails (the rail shows its empty state).
  Future<List<Story>> _settledPublished() async {
    // Let the pending build watch the provider first. A listener of our own
    // that closes before that build would let the provider auto-dispose,
    // and the build would then list the stories a second time.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return const [];
    final familyId = _familyId;
    if (familyId == null) return const [];
    final sub = ref.listenManual(
      timelinePublishedProvider(familyId).future,
      (_, _) {},
    );
    try {
      return await sub.read();
    } on Exception {
      return const [];
    } finally {
      sub.close();
    }
  }

  Future<void> _bootstrap() async {
    final String? id;
    try {
      id = await readableSavedFamily(
        invites: ref.read(inviteRepositoryProvider),
        families: ref.read(familiesRepositoryProvider),
        remembered: ref.read(familySelectionProvider),
      );
    } on Exception {
      if (mounted) setState(() => _boot = _Boot.failed);
      return;
    }
    if (!mounted) return;
    setState(() {
      _familyId = id;
      _boot = _Boot.ready;
    });
    _watchLive();
    final published = await _settledPublished();
    await _maybeAcceptInvite();
    await _maybeOpenNewTimelineOrigin(published);
  }

  bool get _canStartTimeline {
    final id = _familyId;
    return id != null && _data.memberIds.contains(id);
  }

  List<Story> get _parentStories => _storiesOf(_data.published);

  /// Published stories of the open family from [stories].
  List<Story> _storiesOf(List<Story> stories) {
    final id = _familyId;
    if (id == null) return const [];
    return [
      for (final story in stories)
        if (story.familyId == id && story.status == StoryStatus.published)
          story,
    ];
  }

  /// The open family's membership row once the membership read settles,
  /// else what the header shows. Bootstrap reads settle before the next
  /// build refreshes [_data], so the origin path cannot rely on it.
  Future<MemberFamily?> _settledFamily() async {
    final id = _familyId;
    if (id == null) return null;
    final sub = ref.listenManual(timelineMembershipProvider.future, (_, _) {});
    try {
      final membership = await sub.read();
      for (final row in membership.rows) {
        if (row.id == id) return row;
      }
    } on Exception {
      // A failed membership read falls back to the header's family below.
    } finally {
      sub.close();
    }
    return _currentFamily;
  }

  String? _sessionUserId() =>
      widget.currentUserId ?? ref.read(appSessionProvider).currentUserId;

  Future<void> _startTimeline({
    Story? origin,
    bool allowChange = true,
    MemberFamily? parentFamily,
    List<Story>? parentStories,
  }) async {
    final parent = parentFamily ?? _currentFamily;
    final userId = _sessionUserId();
    if (parent == null || userId == null) return;
    final created = await showStartTimelineDialog(
      context,
      parentId: parent.id,
      parentName: parent.name,
      stories: parentStories ?? _parentStories,
      currentUserId: userId,
      origin: origin,
      allowChange: allowChange,
      onWriteStory: () {
        GoRouter.of(context)
            .push('${AppRoutes.newStory}?newTimelineFrom=${parent.id}');
      },
    );
    if (created == null || !mounted) return;
    _reloadOpenTimeline();
    await _settledPublished();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${created.name} timeline created')));
  }

  Future<void> _maybeOpenNewTimelineOrigin(List<Story> published) async {
    if (_originQueryHandled || !mounted) return;
    final router = _router;
    if (router == null) return;
    final uri = router.routerDelegate.currentConfiguration.uri;
    final storyId = uri.queryParameters['newTimelineOrigin'];
    if (storyId == null || storyId.isEmpty) return;
    _originQueryHandled = true;
    Story? origin;
    for (final story in published) {
      if (story.id == storyId) origin = story;
    }
    if (origin != null) {
      final parent = await _settledFamily();
      if (!mounted) return;
      await _startTimeline(
        origin: origin,
        allowChange: true,
        parentFamily: parent,
        parentStories: _storiesOf(published),
      );
    }
    if (!mounted) return;
    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (path == AppRoutes.timeline) {
      router.go(AppRoutes.timeline);
    }
  }

  void _watchLive() {
    final familyId = _familyId;
    if (familyId == null) return;
    ref
        .read(timelineLiveProvider)
        .watch(
          familyId: familyId,
          onChange: () {
            if (mounted) ref.invalidate(timelinePublishedProvider(familyId));
          },
        );
  }

  Future<void> _maybeAcceptInvite() async {
    if (_inviteHandled || !mounted) return;
    _inviteHandled = true;
    // Outside a router (widget tests) there is no invite query to accept.
    if (GoRouter.maybeOf(context) == null) return;
    final uri = GoRouterState.of(context).uri;
    if (!uri.queryParameters.containsKey('invite')) return;
    await acceptInviteFromUriIfPresent(context: context, ref: ref, uri: uri);
  }

  Future<void> _selectFamily(String id) async {
    ref.read(familySelectionProvider.notifier).remember(id);
    if (id == _familyId) return;
    final previousFocus = _focusedStoryId;
    setState(() {
      _familyId = id;
      _filter = const TimelineFilter();
    });
    _watchLive();
    final published = await _settledPublished();
    if (!mounted) return;
    final still =
        previousFocus != null &&
        published.any((story) => story.id == previousFocus);
    if (!still && previousFocus != null) {
      setState(() {
        _focusedStoryId = null;
        _zoom = TimelineZoom.far;
      });
    }
  }

  Future<void> _openInvite() async {
    final invites = ref.read(inviteRepositoryProvider);
    var familyId = _familyId;
    familyId ??= await invites.currentFamilyId();
    if (familyId == null) {
      familyId = await invites.createFamily('Family');
      if (!mounted) return;
      setState(() => _familyId = familyId);
    }
    if (!mounted) return;
    await InviteModal.show(
      context,
      familyId: familyId,
      familyName: _currentFamily?.name ?? 'Family',
    );
  }

  MemberFamily? get _currentFamily {
    final id = _familyId;
    final families = _data.families;
    for (final family in families) {
      if (family.id == id) return family;
    }
    for (final family in _data.tree) {
      if (family.id == id) {
        return MemberFamily(
          id: family.id,
          name: family.name,
          createdAt: DateTime.utc(2020),
          parentFamilyId: family.parentFamilyId,
        );
      }
    }
    return families.isEmpty ? null : families.first;
  }

  bool get _canWrite {
    final id = _familyId;
    return id != null && _data.memberIds.contains(id);
  }

  List<TreeFamily> get _relatedMenu {
    return [
      for (final row in _data.tree)
        if (!_data.memberIds.contains(row.id)) row,
    ];
  }

  TreeFamily? get _openTree {
    final id = _familyId;
    if (id == null) return null;
    for (final row in _data.tree) {
      if (row.id == id) return row;
    }
    return null;
  }

  bool get _showOriginBanner {
    if (_originBannerHidden || _data.loading) return false;
    final open = _openTree;
    if (open == null || open.originStoryId != null) return false;
    final steward = _data.stewarded.any(
      (row) =>
          row.id == open.id &&
          row.deletedAt == null &&
          (row.role == 'owner' || row.role == 'co_owner'),
    );
    if (!steward) return false;
    if (open.parentFamilyId != null) return true;
    return _data.published.any((story) => story.familyId == open.id);
  }

  String? get _originParentName {
    final parentId = _openTree?.parentFamilyId;
    if (parentId == null) return null;
    for (final row in _data.tree) {
      if (row.id == parentId) return row.name;
    }
    return null;
  }

  Story? _storyById(String? id) {
    if (id == null) return null;
    for (final story in _data.published) {
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
    _reloadOpenTimeline();
  }

  void _openNear(Story story) {
    setState(() {
      _zoom = TimelineZoom.near;
      _focusedStoryId = story.id;
    });
    _reveal(story.id);
  }

  void _openMidOnYear(int year) {
    final rows = dialStories(_data.published);
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
    final rows = dialStories(_data.published);
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
    final rows = dialStories(_data.published);
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

  void _showDecades() {
    if (_zoom == TimelineZoom.far) return;
    setState(() => _zoom = TimelineZoom.far);
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

  void _openPerson(({String id, String name}) person) {
    showPersonProfile(
      context,
      personId: person.id,
      name: person.name,
      signedInUserId: _sessionUserId(),
    );
  }

  void _chooseOriginParent() {
    final parentId = _openTree?.parentFamilyId;
    if (parentId != null) _selectFamily(parentId);
  }

  void _setFilter(TimelineFilter filter) => setState(() => _filter = filter);

  void _toggleSidebar() => setState(() => _sidebarOpen = !_sidebarOpen);

  void _hideOriginBanner() => setState(() => _originBannerHidden = true);

  void _showMid() => setState(() => _zoom = TimelineZoom.mid);

  /// Remembers the signed-in user's memberships once they load.
  void _onMembership(
    AsyncValue<TimelineMembership>? _,
    AsyncValue<TimelineMembership> next,
  ) {
    if (next.isLoading || next.hasError) return;
    final membership = next.value;
    if (membership == null) return;
    ref
        .read(familyMembershipProvider.notifier)
        .remember(membership.rows.map((row) => row.id));
  }

  /// Watches the timeline providers for the open family.
  _TimelineData _watchData() {
    if (_boot != _Boot.ready) {
      return _TimelineData(loading: _boot == _Boot.loading);
    }
    final familyId = _familyId;
    ref.listen(timelineMembershipProvider, _onMembership);
    final membership = ref.watch(timelineMembershipProvider);
    final tree = familyId == null
        ? null
        : ref.watch(timelineTreeProvider(familyId));
    final published = familyId == null
        ? null
        : ref.watch(timelinePublishedProvider(familyId));
    final rows = membership.value?.rows ?? const <MemberFamily>[];
    return _TimelineData(
      families: _headerRows(rows, familyId),
      stewarded: membership.value?.stewarded ?? const [],
      tree: tree?.value ?? const [],
      memberIds: {for (final row in rows) row.id},
      published: published?.value ?? const [],
      loading: _pending(membership) || _pending(tree) || _pending(published),
    );
  }

  /// Unmatched story ids; empty while no filter is active.
  Set<String> get _dimmed {
    if (!_filter.isActive) return const {};
    return {
      for (final entry in timelineEntries(
        _data.published,
        matches: _filter.matches,
      ))
        if (!entry.matched) entry.id,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the live feed open while the page is up.
    ref.watch(timelineLiveProvider);
    _data = _watchData();
    final family = _currentFamily;
    final bands = decadeBands(_data.published);
    final showRail = !_data.loading && bands.isNotEmpty;
    final width = MediaQuery.sizeOf(context).width;
    final wide = showRail && width >= AlbumBreakpoint.sidebar;
    final dimmed = _dimmed;
    final panel = _FilterPanelHost(host: this, dimmed: dimmed);
    return Scaffold(
      backgroundColor: albumParchment,
      // The rails are not a form: the keyboard (a search field, a dialog)
      // floats over them instead of squeezing the viewport.
      resizeToAvoidBottomInset: false,
      endDrawer: showRail && !wide
          ? Drawer(
              key: const Key('timeline-filter-drawer'),
              width: math.min(_filterPanelWidth, width * 0.9),
              backgroundColor: albumParchment,
              child: SafeArea(child: panel),
            )
          : null,
      appBar: AlbumHeader(
        page: AlbumHeaderPage.timeline,
        familyName: family?.name ?? 'Family',
        families: _data.families,
        currentFamilyId: _familyId,
        onFamilySelected: _selectFamily,
        stewarded: _data.stewarded,
        relatedFamilies: _relatedMenu,
        canWrite: _canWrite,
        onInvite: _canWrite ? _openInvite : null,
        onStartTimeline: _canStartTimeline ? _startTimeline : null,
        onShowDecades: _showDecades,
      ),
      body: _TimelineLayout(
        host: this,
        bands: bands,
        dimmed: dimmed,
        showRail: showRail,
        wide: wide,
        sidebar: wide && _sidebarOpen ? panel : null,
        familyName: family?.name ?? 'Family',
      ),
    );
  }
}

/// The rail column (origin banner, rail, Decades footer) beside the docked
/// filter sidebar when [sidebar] is set.
class _TimelineLayout extends StatelessWidget {
  const _TimelineLayout({
    required this.host,
    required this.bands,
    required this.dimmed,
    required this.showRail,
    required this.wide,
    required this.sidebar,
    required this.familyName,
  });

  final _TimelinePageState host;
  final List<DecadeBand> bands;
  final Set<String> dimmed;
  final bool showRail;
  final bool wide;
  final Widget? sidebar;
  final String familyName;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // A 1×1 pass (web startup, before the view has a real size) makes
        // the footer wrap one glyph per line and overflow this column.
        if (constraints.maxWidth < 8 || constraints.maxHeight < 8) {
          return const SizedBox.shrink();
        }
        final showFooter =
            showRail &&
            host._zoom == TimelineZoom.far &&
            constraints.maxHeight > 96;
        final rail = _RailColumn(
          host: host,
          bands: bands,
          dimmed: dimmed,
          wide: wide,
          footer: showFooter ? _FarFooter(familyName: familyName) : null,
        );
        final panel = sidebar;
        if (panel == null) return rail;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: const Key('timeline-filter-sidebar'),
              width: _filterPanelWidth,
              child: panel,
            ),
            const VerticalDivider(width: 1, thickness: 1, color: albumRule),
            Expanded(child: rail),
          ],
        );
      },
    );
  }
}

class _RailColumn extends StatelessWidget {
  const _RailColumn({
    required this.host,
    required this.bands,
    required this.dimmed,
    required this.wide,
    required this.footer,
  });

  final _TimelinePageState host;
  final List<DecadeBand> bands;
  final Set<String> dimmed;
  final bool wide;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    return GestureDetector(
      onScaleStart: (_) => host._pinchLatched = false,
      onScaleUpdate: host._onPinch,
      child: Stack(
        children: [
          Column(
            children: [
              if (host._showOriginBanner)
                OriginBanner(
                  familyName: host._openTree?.name ?? 'Family',
                  parentName: host._originParentName,
                  onChoose: host._chooseOriginParent,
                  onClose: host._hideOriginBanner,
                ),
              Expanded(
                child: _TimelineBody(
                  host: host,
                  bands: bands,
                  dimmed: dimmed,
                  wide: wide,
                ),
              ),
              ?footer,
            ],
          ),
        ],
      ),
    );
  }
}

class _FarFooter extends StatelessWidget {
  const _FarFooter({required this.familyName});

  final String familyName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Clear the home indicator on iPad and iPhone.
      padding: EdgeInsets.fromLTRB(
        AlbumSpace.l,
        AlbumSpace.s,
        AlbumSpace.l,
        AlbumSpace.m + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Text(
        farFooter(familyName: familyName),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(fontStyle: FontStyle.italic, color: albumDimInk),
      ),
    );
  }
}

/// The filters, scrolling above the keyboard: the docked sidebar at
/// [AlbumBreakpoint.sidebar] and up, the end drawer below.
class _FilterPanelHost extends StatelessWidget {
  const _FilterPanelHost({required this.host, required this.dimmed});

  final _TimelinePageState host;
  final Set<String> dimmed;

  @override
  Widget build(BuildContext context) {
    final published = host._data.published;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FilterPanel(
        filter: host._filter,
        options: filterOptions(published),
        matched: published.length - dimmed.length,
        total: published.length,
        onChanged: host._setFilter,
      ),
    );
  }
}

/// Beside the zoom switch at every width: Family tree (once a family is
/// open) and Filters, which toggles the docked sidebar when [wide], else
/// opens the end drawer.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.familyId,
    required this.filtering,
    required this.wide,
    required this.onToggleSidebar,
  });

  final String? familyId;
  final bool filtering;
  final bool wide;
  final VoidCallback onToggleSidebar;

  @override
  Widget build(BuildContext context) {
    final familyId = this.familyId;
    return Wrap(
      spacing: AlbumSpace.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (familyId != null)
          FButton(
            key: const Key('timeline-open-tree'),
            variant: FButtonVariant.ghost,
            mainAxisSize: MainAxisSize.min,
            prefix: const Icon(Icons.account_tree_outlined),
            onPress: () =>
                GoRouter.of(context).go(AppRoutes.familyTreePath(familyId)),
            child: const Text('Family tree'),
          ),
        FButton(
          key: const Key('timeline-filters-open'),
          variant: FButtonVariant.ghost,
          mainAxisSize: MainAxisSize.min,
          prefix: Icon(filtering ? Icons.filter_alt : Icons.tune),
          onPress: wide
              ? onToggleSidebar
              : () => Scaffold.of(context).openEndDrawer(),
          child: const Text('Filters'),
        ),
      ],
    );
  }
}

/// C17, pinned above the still-mounted rows when every story is dimmed
/// (none hidden).
class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IntrinsicWidth(
        child: DecoratedBox(
          key: const Key('timeline-no-match'),
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
              onAction: onClear,
            ),
          ),
        ),
      ),
    );
  }
}

/// Spinner, empty copy, or the rail for the current zoom.
class _TimelineBody extends ConsumerWidget {
  const _TimelineBody({
    required this.host,
    required this.bands,
    required this.dimmed,
    required this.wide,
  });

  final _TimelinePageState host;
  final List<DecadeBand> bands;
  final Set<String> dimmed;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (host._data.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bands.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AlbumSpace.xl),
        child: EmptyTimeline(
          message: 'No stories yet. Capture the first one for this family.',
        ),
      );
    }
    final rails = _RailParts.of(host, dimmed: dimmed, wide: wide);
    return switch (host._zoom) {
      TimelineZoom.far => _farRail(rails),
      TimelineZoom.mid => _midRail(rails),
      TimelineZoom.near => _nearRail(
        rails,
        ref.watch(photosRepositoryProvider),
      ),
    };
  }

  FarRail _farRail(_RailParts parts) => FarRail(
    bands: bands,
    focusedId: host._focusedStoryId,
    branching: parts.branching,
    originStoryId: parts.originId,
    onDot: host._openStory,
    onEmpty: host._zoomOut,
    onYear: host._openMidOnYear,
    onFocus: host._onDialFocus,
    onOpenBranch: host._selectFamily,
    onMid: host._zoomIn,
    onFullCards: host._openFullCards,
    dimmed: dimmed,
    filtering: host._filter.isActive,
    toolbar: parts.toolbar,
    notice: parts.notice,
  );

  MidRail _midRail(_RailParts parts) => MidRail(
    stories: dialStories(host._data.published),
    focusedId: host._focusedStoryId,
    branching: parts.branching,
    originStoryId: parts.originId,
    originTag: parts.originLabel,
    anchorFor: host._anchor,
    onStub: host._openStory,
    onNode: host._openNear,
    onEmpty: host._zoomOut,
    onFocus: host._onDialFocus,
    onOpenBranch: host._selectFamily,
    onMacro: host._fitAll,
    onFullCards: host._zoomIn,
    dimmed: dimmed,
    toolbar: parts.toolbar,
    notice: parts.notice,
  );

  FullCardRail _nearRail(_RailParts parts, PhotosRepository photos) =>
      FullCardRail(
        stories: dialStories(host._data.published),
        focusedId: host._focusedStoryId,
        photos: photos,
        onPerson: host._openPerson,
        branching: parts.branching,
        originStoryId: parts.originId,
        originTag: parts.originLabel,
        anchorFor: host._anchor,
        onOpen: host._openStory,
        onEmpty: host._zoomOut,
        onFocus: host._onDialFocus,
        onOpenBranch: host._selectFamily,
        onMacro: host._fitAll,
        onMid: host._showMid,
        dimmed: dimmed,
        toolbar: parts.toolbar,
        notice: parts.notice,
      );
}

/// What every rail shares: branching, origin tag, toolbar and notice.
class _RailParts {
  const _RailParts({
    required this.branching,
    required this.originId,
    required this.originLabel,
    required this.toolbar,
    required this.notice,
  });

  factory _RailParts.of(
    _TimelinePageState host, {
    required Set<String> dimmed,
    required bool wide,
  }) {
    final data = host._data;
    final open = host._openTree;
    final originId = open?.originStoryId;
    final filter = host._filter;
    return _RailParts(
      branching: railBranching(
        open: open,
        tree: data.tree,
        stories: data.published,
      ),
      originId: originId,
      originLabel: open == null || originId == null
          ? null
          : originTag(open: open, tree: data.tree, storyId: originId),
      toolbar: Builder(
        builder: (context) => _Toolbar(
          familyId: host._familyId,
          filtering: filter.isActive,
          wide: wide,
          onToggleSidebar: host._toggleSidebar,
        ),
      ),
      notice: filter.isActive && dimmed.length == data.published.length
          ? _NoMatch(onClear: () => host._setFilter(const TimelineFilter()))
          : null,
    );
  }

  final RailBranching branching;
  final String? originId;
  final String? originLabel;
  final Widget toolbar;
  final Widget? notice;
}
