import 'package:flutter/material.dart';

import '../../core/theme/album_header.dart';
import '../../core/theme/album_theme.dart';
import '../../data/current_session.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/stories_api.dart';
import 'family_thread_copy.dart';
import 'thread_skeleton.dart';

class FamilyThreadPage extends StatefulWidget {
  const FamilyThreadPage({super.key, this.storiesApi, this.familiesApi});

  final StoriesGateway? storiesApi;
  final FamiliesGateway? familiesApi;

  @override
  State<FamilyThreadPage> createState() => _FamilyThreadPageState();
}

class _FamilyThreadPageState extends State<FamilyThreadPage> {
  StoriesGateway? _ownedStories;
  FamiliesGateway? _ownedFamilies;
  var _loading = true;
  var _failed = false;
  String? _familyId;
  var _familyName = 'Family';
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

  Future<void> _load() async {
    try {
      final opened = await _opened();
      final stories = await _storiesFor(opened.id, opened.originId);
      if (!mounted) return;
      setState(() {
        _familyId = opened.id;
        _familyName = opened.name;
        _families = opened.mine;
        _stories = stories;
        _loading = false;
        _failed = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<({String? id, String name, List<MemberFamily> mine, String? originId})>
  _opened() async {
    final mine = await _familiesApi.listMine();
    FamilyMembership.remember([for (final row in mine) row.id]);
    final remembered = FamilySelection.id;
    var id = _selected(mine, remembered);
    if (remembered != null &&
        remembered != id &&
        await _readable(_familiesApi, remembered)) {
      id = remembered;
    }
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
        merged.add(origin);
      }
    }
    return _published(merged);
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
    return const SizedBox(key: Key('family-thread-loaded'));
  }
}

String? _selected(List<MemberFamily> mine, String? remembered) {
  final ids = [for (final row in mine) row.id];
  final fallback = ids.isEmpty ? null : ids.first;
  final userId = CurrentSession.userId;
  if (userId == null) {
    if (remembered != null && ids.contains(remembered)) return remembered;
    return fallback;
  }
  return resolveCurrentFamilyId(
    userId: userId,
    remembered: remembered,
    membershipIds: ids,
    fallback: fallback,
  );
}

Future<bool> _readable(FamiliesGateway families, String familyId) async {
  try {
    final tree = await families.listFamilyTree(familyId);
    for (final row in tree) {
      if (row.id == familyId) return true;
    }
  } on Exception {
    // A tree read that throws cannot confirm the saved family.
    return false;
  }
  return false;
}

String _nameFor(String? id, List<MemberFamily> mine, List<TreeFamily> tree) {
  if (id == null) return 'Family';
  for (final row in mine) {
    if (row.id == id) return row.name;
  }
  for (final row in tree) {
    if (row.id == id) return row.name;
  }
  return 'Family';
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
