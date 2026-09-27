import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/invite_api.dart';
import '../../data/stories_api.dart';
import '../invites/invite_accept.dart';
import '../invites/invite_modal.dart';
import '../stories/timeframe_chips.dart';

/// Signed-in home stub. Full timeline UX is M6.
/// M2: `+ Invite` opens Email/Link modal (chrome locks).
/// M3: smoke-only `New story` → `/stories/new` (no Stitch/Memory Album chrome).
/// M4: smoke-only `Drafts` → `/drafts`; published preview list (no zoom).
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key, this.api, this.storiesApi});

  final InviteGateway? api;
  final StoriesGateway? storiesApi;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  late final InviteGateway _api;
  StoriesGateway? _storiesOverride;
  GoRouter? _router;
  String? _familyId;
  List<Story> _published = const [];
  var _loadingFamily = true;
  var _loadingPublished = true;
  var _inviteHandled = false;

  StoriesGateway get _stories =>
      widget.storiesApi ?? (_storiesOverride ??= StoriesApi());

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
        _published = rows;
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
    await acceptInviteFromUriIfPresent(
      context: context,
      uri: uri,
      api: _api,
    );
  }

  Future<void> _openInvite() async {
    var familyId = _familyId;
    if (familyId == null) {
      // Data/API bootstrap when inviting without membership (no Create Family screen).
      familyId = await _api.createFamily('Family');
      if (!mounted) return;
      setState(() => _familyId = familyId);
    }
    if (!mounted) return;
    await InviteModal.show(context, familyId: familyId!, api: _api);
  }

  void _openNewStory() {
    context.push(AppRoutes.newStory);
  }

  void _openDrafts() {
    context.push(AppRoutes.drafts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        actions: [
          TextButton(
            onPressed: _openNewStory,
            child: const Text('New story'),
          ),
          TextButton(
            onPressed: _openDrafts,
            child: const Text('Drafts'),
          ),
          TextButton(
            onPressed: _loadingFamily ? null : _openInvite,
            child: const Text('+ Invite'),
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loadingFamily || _loadingPublished) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_published.isEmpty) {
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _published.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _PublishedRow(story: _published[index]),
    );
  }
}

class _PublishedRow extends StatelessWidget {
  const _PublishedRow({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _timeframeLabel(story),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(_bodyPreview(story)),
      ],
    );
  }
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
