import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/data/timeline_live.dart';
import 'package:tell_me_a_story/features/timeline/tree/tree_graph_view.dart';
import 'package:tell_me_a_story/features/timeline/tree/tree_timeline_loader.dart';
import 'package:tell_me_a_story/features/timeline/tree/treemap_view.dart';
import 'package:tell_me_a_story/ui/album/album_header.dart';

/// The page's two views of the tree (Q2): C3, C4.
enum FamilyTreeView { graph, overview }

String familyTreeViewLabel(FamilyTreeView view) => switch (view) {
  FamilyTreeView.graph => 'Family tree',
  FamilyTreeView.overview => 'Overview',
};

/// `/family/:id/tree`: every published story of the family's tree, as the
/// family tree graph or the treemap overview (Q2). Opened from the family
/// menu (O1).
class FamilyTreePage extends StatefulWidget {
  const FamilyTreePage({
    super.key,
    required this.familyId,
    this.storiesApi,
    this.familiesApi,
    this.live,
  });

  final String familyId;
  final StoriesGateway? storiesApi;
  final FamiliesGateway? familiesApi;
  final TimelineLive? live;

  @override
  State<FamilyTreePage> createState() => _FamilyTreePageState();
}

enum _Phase { loading, ready, error }

class _FamilyTreePageState extends State<FamilyTreePage> {
  StoriesGateway? _storiesOverride;
  FamiliesGateway? _familiesOverride;
  TimelineLive? _ownedLive;
  _Phase _phase = _Phase.loading;
  TreeTimelineData? _data;
  List<MemberFamily> _families = const [];
  List<StewardFamily> _stewarded = const [];
  late bool _canWrite;
  var _loadGeneration = 0;
  FamilyTreeView _view = FamilyTreeView.graph;

  StoriesGateway get _stories =>
      widget.storiesApi ?? (_storiesOverride ??= StoriesApi());

  FamiliesGateway get _familiesApi =>
      widget.familiesApi ?? (_familiesOverride ??= FamiliesApi());

  /// As the timeline: tests that inject only gateways get no live feed.
  TimelineLive? get _live {
    if (widget.live != null) return widget.live;
    if (widget.storiesApi != null) return null;
    return _ownedLive ??= ServerTimelineLive();
  }

  @override
  void initState() {
    super.initState();
    _canWrite = FamilyMembership.canWrite(widget.familyId);
    FamilySelection.remember(widget.familyId);
    _live?.watchTree(
      familyId: widget.familyId,
      onChange: () => _load(showLoading: false),
    );
    _load(showLoading: true);
  }

  @override
  void dispose() {
    _ownedLive?.dispose();
    super.dispose();
  }

  Future<void> _load({required bool showLoading}) async {
    final generation = ++_loadGeneration;
    if (showLoading && mounted) {
      setState(() => _phase = _Phase.loading);
    }
    try {
      final loader = TreeTimelineLoader(
        stories: _stories,
        families: _familiesApi,
      );
      final dataFuture = loader.load(widget.familyId);
      final chromeFuture = _loadChrome();
      final data = await dataFuture;
      final chrome = await chromeFuture;
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _data = data;
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

  /// The header's membership read, best effort as on All Stories: a menu
  /// failure must not replace a loaded treemap with the error line.
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
      FamilyMembership.remember(mine.map((row) => row.id));
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

  Future<void> _openStory(String storyId) async {
    await context.push(AppRoutes.storyPath(storyId));
    if (!mounted) return;
    await _load(showLoading: false);
  }

  void _openFamily(String familyId) {
    FamilySelection.remember(familyId);
    context.go(AppRoutes.timeline);
  }

  String? _nameOf(String id) {
    for (final row in _data?.tree ?? const <TreeFamily>[]) {
      if (row.id == id) return row.name;
    }
    return null;
  }

  /// The tree's root: the live family with no live parent.
  String _rootName() {
    final tree = _data?.tree ?? const <TreeFamily>[];
    final ids = {for (final row in tree) row.id};
    for (final row in tree) {
      final parent = row.parentFamilyId;
      if (parent == null || !ids.contains(parent)) return row.name;
    }
    return _nameOf(widget.familyId) ?? 'Family';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      key: const Key('family-tree-page'),
      backgroundColor: albumParchment,
      appBar: AlbumHeader(
        page: AlbumHeaderPage.familyTree,
        familyName: _nameOf(widget.familyId) ?? 'Family',
        families: _families,
        currentFamilyId: widget.familyId,
        onFamilySelected: FamilySelection.remember,
        stewarded: _stewarded,
        relatedFamilies: [
          for (final row in data?.tree ?? const <TreeFamily>[])
            if (!_families.any((family) => family.id == row.id)) row,
        ],
        canWrite: _canWrite,
      ),
      body: switch (_phase) {
        _Phase.loading => const Center(child: CircularProgressIndicator()),
        _Phase.error => _error(),
        _Phase.ready => _ready(data!),
      },
    );
  }

  Widget _ready(TreeTimelineData data) {
    final title = '${_rootName()} family tree';
    // An empty tree has nothing to switch between: C9 alone.
    if (data.stories.isEmpty) {
      return TreemapView(
        title: title,
        stories: data.stories,
        tree: data.tree,
        onStory: _openStory,
        onFamily: _openFamily,
      );
    }
    final viewSwitch = SegmentedButton<FamilyTreeView>(
      key: const Key('family-tree-view'),
      showSelectedIcon: false,
      segments: [
        for (final v in FamilyTreeView.values)
          ButtonSegment(value: v, label: Text(familyTreeViewLabel(v))),
      ],
      selected: {_view},
      onSelectionChanged: (s) => setState(() => _view = s.first),
    );
    return switch (_view) {
      FamilyTreeView.graph => TreeGraphView(
        title: title,
        stories: data.stories,
        tree: data.tree,
        onStory: _openStory,
        onFamily: _openFamily,
        viewSwitch: viewSwitch,
      ),
      FamilyTreeView.overview => TreemapView(
        title: title,
        stories: data.stories,
        tree: data.tree,
        onStory: _openStory,
        onFamily: _openFamily,
        viewSwitch: viewSwitch,
      ),
    };
  }

  Widget _error() {
    return Padding(
      padding: const EdgeInsets.all(AlbumSpace.xl),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AlbumSpace.m,
        children: [
          Text(
            "Couldn't load stories.",
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            key: const Key('family-tree-retry'),
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
    );
  }
}
