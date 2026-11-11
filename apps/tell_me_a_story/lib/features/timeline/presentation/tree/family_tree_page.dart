import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/family_membership.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/session/timeline_live.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/core/widgets/timeline/empty_timeline.dart';
import 'package:tell_me_a_story/core/widgets/timeline/view_switch.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/family_tree_providers.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/tree_graph_view.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/tree_timeline_loader.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/treemap_view.dart';

/// The page's two views of the tree (Q2): C3, C4.
enum FamilyTreeView { graph, overview }

String familyTreeViewLabel(FamilyTreeView view) => switch (view) {
  FamilyTreeView.graph => 'Family tree',
  FamilyTreeView.overview => 'Overview',
};

/// `/family/:id/tree`: every published story of the family's tree, as the
/// family tree graph or the treemap overview (Q2). Opened from the family
/// menu (O1).
class FamilyTreePage extends ConsumerStatefulWidget {
  const FamilyTreePage({super.key, required this.familyId});

  final String familyId;

  @override
  ConsumerState<FamilyTreePage> createState() => _FamilyTreePageState();
}

class _FamilyTreePageState extends ConsumerState<FamilyTreePage> {
  FamilyTreeView _view = FamilyTreeView.graph;

  @override
  void initState() {
    super.initState();
    // Providers can't be modified while the tree builds.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(familySelectionProvider.notifier).remember(widget.familyId);
    });
    // The subscription keeps the auto-dispose feed alive for the page.
    ref
        .listenManual(timelineLiveProvider, (_, _) {})
        .read()
        .watchTree(familyId: widget.familyId, onChange: _reload);
  }

  void _reload() {
    if (!mounted) return;
    ref.invalidate(familyTreeProvider(widget.familyId));
  }

  Future<void> _openStory(String storyId) async {
    await context.push(AppRoutes.storyPath(storyId));
    _reload();
  }

  void _openFamily(String familyId) {
    ref.read(familySelectionProvider.notifier).remember(familyId);
    context.go(AppRoutes.timeline);
  }

  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(familyTreeProvider(widget.familyId));
    final content = tree.value;
    final families = content?.families ?? const <MemberFamily>[];
    final rows = content?.data.tree ?? const <TreeFamily>[];
    return Scaffold(
      key: const Key('family-tree-page'),
      backgroundColor: albumParchment,
      appBar: AlbumHeader(
        page: AlbumHeaderPage.familyTree,
        familyName: _nameOf(rows, widget.familyId) ?? 'Family',
        families: families,
        currentFamilyId: widget.familyId,
        onFamilySelected: (id) =>
            ref.read(familySelectionProvider.notifier).remember(id),
        stewarded: content?.stewarded ?? const [],
        relatedFamilies: _relatedFamilies(rows, families),
        canWrite:
            content?.canWrite ??
            ref.watch(familyMembershipProvider).canWrite(widget.familyId),
      ),
      // A live refresh keeps the drawn tree; Retry after an error spins.
      body: tree.when(
        skipLoadingOnRefresh: !tree.hasError,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _LoadError(
          onRetry: () => ref.invalidate(familyTreeProvider(widget.familyId)),
        ),
        data: (content) => _TreeViews(
          title: '${_rootName(content.data.tree, widget.familyId)} family tree',
          data: content.data,
          view: _view,
          onView: (v) => setState(() => _view = v),
          onStory: _openStory,
          onFamily: _openFamily,
        ),
      ),
    );
  }
}

String? _nameOf(List<TreeFamily> tree, String id) {
  for (final row in tree) {
    if (row.id == id) return row.name;
  }
  return null;
}

/// The tree's families the user is not a member of.
List<TreeFamily> _relatedFamilies(
  List<TreeFamily> rows,
  List<MemberFamily> families,
) => [
  for (final row in rows)
    if (!families.any((family) => family.id == row.id)) row,
];

/// The tree failed to load: the error copy and Retry.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyTimeline(
    message: "Couldn't load stories.",
    actionLabel: 'Retry',
    onAction: onRetry,
  );
}

/// The tree's root: the live family with no live parent.
String _rootName(List<TreeFamily> tree, String familyId) {
  final ids = {for (final row in tree) row.id};
  for (final row in tree) {
    final parent = row.parentFamilyId;
    if (parent == null || !ids.contains(parent)) return row.name;
  }
  return _nameOf(tree, familyId) ?? 'Family';
}

/// The graph or the treemap, with the view switch; C9 alone when empty.
class _TreeViews extends StatelessWidget {
  const _TreeViews({
    required this.title,
    required this.data,
    required this.view,
    required this.onView,
    required this.onStory,
    required this.onFamily,
  });

  final String title;
  final TreeTimelineData data;
  final FamilyTreeView view;
  final ValueChanged<FamilyTreeView> onView;
  final ValueChanged<String> onStory;
  final ValueChanged<String> onFamily;

  @override
  Widget build(BuildContext context) {
    // An empty tree has nothing to switch between: C9 alone.
    if (data.stories.isEmpty) {
      return TreemapView(
        title: title,
        stories: data.stories,
        tree: data.tree,
        onStory: onStory,
        onFamily: onFamily,
      );
    }
    final viewSwitch = ViewSwitch<FamilyTreeView>(
      key: const Key('family-tree-view'),
      values: FamilyTreeView.values,
      labelOf: familyTreeViewLabel,
      selected: view,
      onChanged: onView,
    );
    return switch (view) {
      FamilyTreeView.graph => TreeGraphView(
        title: title,
        stories: data.stories,
        tree: data.tree,
        onStory: onStory,
        onFamily: onFamily,
        viewSwitch: viewSwitch,
      ),
      FamilyTreeView.overview => TreemapView(
        title: title,
        stories: data.stories,
        tree: data.tree,
        onStory: onStory,
        onFamily: onFamily,
        viewSwitch: viewSwitch,
      ),
    };
  }
}
