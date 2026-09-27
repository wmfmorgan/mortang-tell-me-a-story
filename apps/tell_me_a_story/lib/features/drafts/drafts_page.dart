import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/invite_api.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import '../stories/timeframe_chips.dart';

enum _DraftsFilter {
  all,
  missingText,
  missingPeople,
  missingPlace,
  missingPhotos,
  readyToPublish,
}

/// Author-only draft list at `/drafts` (missing-field chips + discard).
class DraftsPage extends StatefulWidget {
  const DraftsPage({
    super.key,
    this.inviteApi,
    this.storiesApi,
    this.photosApi,
  });

  final InviteGateway? inviteApi;
  final StoriesGateway? storiesApi;
  final PhotosGateway? photosApi;

  @override
  State<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends State<DraftsPage> {
  late final InviteGateway _invite;
  StoriesGateway? _storiesOverride;
  PhotosGateway? _photosOverride;

  var _loading = true;
  var _busy = false;
  String? _familyId;
  List<Story> _drafts = const [];
  var _filter = _DraftsFilter.all;

  StoriesGateway get _stories =>
      widget.storiesApi ?? (_storiesOverride ??= StoriesApi());

  PhotosGateway get _photos =>
      widget.photosApi ?? (_photosOverride ??= PhotosApi());

  @override
  void initState() {
    super.initState();
    _invite = widget.inviteApi ?? InviteApi();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final familyId = _familyId ?? await _invite.currentFamilyId();
      if (!mounted) return;
      if (familyId == null) {
        setState(() {
          _familyId = null;
          _drafts = const [];
          _loading = false;
        });
        return;
      }
      final drafts = await _stories.listMyDrafts(familyId);
      if (!mounted) return;
      setState(() {
        _familyId = familyId;
        _drafts = drafts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Story> get _visible {
    return [
      for (final story in _drafts)
        if (_matchesFilter(story, _filter)) story,
    ];
  }

  void _continueWriting(Story story) {
    context.push('${AppRoutes.newStory}?draft=${story.id}');
  }

  Future<void> _discard(Story story) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final familyId = _familyId ?? story.familyId;
      await _photos.deleteAllForStory(
        familyId: familyId,
        storyId: story.id,
      );
      await _stories.discard(story.id);
      if (!mounted) return;
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drafts')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip('All', _DraftsFilter.all),
                  _filterChip('Missing text', _DraftsFilter.missingText),
                  _filterChip('Missing people', _DraftsFilter.missingPeople),
                  _filterChip('Missing place', _DraftsFilter.missingPlace),
                  _filterChip('Missing photos', _DraftsFilter.missingPhotos),
                  _filterChip('Ready to publish', _DraftsFilter.readyToPublish),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: Text('Loading drafts…'));
    }
    if (_drafts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No drafts yet. Stories you’re still writing will show up here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final rows = _visible;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: rows.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _DraftRow(
        story: rows[index],
        onContinue: _busy ? null : () => _continueWriting(rows[index]),
        onDiscard: _busy ? null : () => _discard(rows[index]),
      ),
    );
  }

  Widget _filterChip(String label, _DraftsFilter value) {
    return FilterChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.story,
    required this.onContinue,
    required this.onDiscard,
  });

  final Story story;
  final VoidCallback? onContinue;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final ready = publishReadiness(
      body: story.body,
      timeframeStart: story.timeframeStart,
      personIds: story.personIds,
      placeId: story.placeId,
    );
    final preview = _bodyPreview(story);
    return KeyedSubtree(
      key: Key('draft-row-${story.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _timeframeLabel(story),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(preview),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!ready.hasBody) const Chip(label: Text('Missing text')),
              if (!ready.hasPerson) const Chip(label: Text('Missing people')),
              if (!ready.hasPlace) const Chip(label: Text('Missing place')),
              if (story.photoCount <= 0)
                const Chip(label: Text('Missing photos')),
              if (ready.canPublish) const Chip(label: Text('Ready to publish')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: onContinue,
                child: const Text('Continue writing'),
              ),
              TextButton(
                onPressed: onDiscard,
                child: const Text('Discard'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

bool _matchesFilter(Story story, _DraftsFilter filter) {
  final ready = publishReadiness(
    body: story.body,
    timeframeStart: story.timeframeStart,
    personIds: story.personIds,
    placeId: story.placeId,
  );
  return switch (filter) {
    _DraftsFilter.all => true,
    _DraftsFilter.missingText => !ready.hasBody,
    _DraftsFilter.missingPeople => !ready.hasPerson,
    _DraftsFilter.missingPlace => !ready.hasPlace,
    _DraftsFilter.missingPhotos => story.photoCount <= 0,
    _DraftsFilter.readyToPublish => ready.canPublish,
  };
}

String _bodyPreview(Story story) {
  final body = story.body?.trim() ?? '';
  return body.isEmpty ? 'Untitled' : body;
}

String _timeframeLabel(Story story) {
  final end = story.timeframeEnd;
  if (end != null) {
    for (final decade in decadeChips) {
      if (_sameDay(story.timeframeStart, decade.start) &&
          _sameDay(end, decade.end)) {
        return decade.label;
      }
    }
  }
  return _ymd(story.timeframeStart);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _ymd(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
