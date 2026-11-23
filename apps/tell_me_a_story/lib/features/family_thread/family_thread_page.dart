import 'package:flutter/material.dart';

import '../../core/theme/album_header.dart';
import '../../core/theme/album_theme.dart';
import '../../data/current_session.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/gateway_read.dart';
import '../../data/stories_api.dart';
import '../../data/timeline_live.dart';
import 'family_thread_copy.dart';
import 'insert_published_origin.dart';
import 'thread_focus.dart';
import 'thread_skeleton.dart';
import 'thread_view.dart';

class FamilyThreadPage extends StatefulWidget {
  const FamilyThreadPage({
    super.key,
    this.storiesApi,
    this.familiesApi,
    this.currentUserId,
    required this.live,
  });

  final StoriesGateway? storiesApi;
  final FamiliesGateway? familiesApi;

  /// Signed-in user. Widget tests pass this because [CurrentSession] is null
  /// before Supabase starts. Null means [CurrentSession.userId].
  final String? Function()? currentUserId;

  /// Realtime signal. The route passes [SupabaseTimelineLive].
  final TimelineLive live;

  @override
  State<FamilyThreadPage> createState() => _FamilyThreadPageState();
}

class _FamilyThreadPageState extends State<FamilyThreadPage> {
  StoriesGateway? _ownedStories;
  FamiliesGateway? _ownedFamilies;
  TimelineLive? _subscribed;
  var _loading = true;
  var _failed = false;
  var _ready = false;
  var _onRoute = false;
  var _ticket = 0;
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
    if (returned) _reloadStories();
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
      final stories = await guardRead(
        () => _storiesFor(opened.id, opened.originId),
      );
      if (!mounted || ticket != _ticket) return;
      _show(opened, stories);
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

  void _show(_Opened opened, List<Story> stories) {
    setState(() {
      _familyId = opened.id;
      _originId = opened.originId;
      _familyName = opened.name;
      _families = opened.mine;
      _loading = false;
      _failed = false;
      _ready = true;
      _applyStories(stories);
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
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const ThreadSkeleton();
    if (_failed) return _LoadError(onRetry: _retry);
    if (_stories.isEmpty) return const _EmptyFamily();
    return ThreadView(
      key: const Key('family-thread-loaded'),
      stories: _stories,
      focusStoryId: _focusId,
      onFocusChanged: _onScrollFocus,
    );
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

List<Story> _published(Iterable<Story> stories) {
  return [
    for (final story in stories)
      if (story.status == StoryStatus.published) story,
  ];
}

class _ThreadBar extends StatelessWidget implements PreferredSizeWidget {
  const _ThreadBar({
    required this.familyName,
    required this.families,
    required this.familyId,
  });

  final String familyName;
  final List<MemberFamily> families;
  final String? familyId;

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
        onFamilySelected: FamilySelection.remember,
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
