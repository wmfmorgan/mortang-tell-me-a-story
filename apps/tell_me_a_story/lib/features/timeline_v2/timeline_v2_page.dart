import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/album_header.dart';
import '../../core/theme/album_theme.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/invite_api.dart';
import '../../data/postgrest_exception.dart';
import '../../data/rpc_error.dart';
import '../../data/stories_api.dart';
import '../timeline/timeline_zoom.dart';
import 'timeline_v2_filter.dart';
import 'timeline_v2_filter_options.dart';
import 'timeline_v2_filter_panel.dart';
import 'timeline_v2_rails.dart';
import 'timeline_v2_zoom_bar.dart';

const _couldNotLoad = "Couldn't load stories.";
const _emptyFamily = 'No stories yet. Capture the first one for this family.';
const _noMatch = 'No stories match these filters.';

/// Prototype timeline. Decades, years, and days, with dim-only filters.
class TimelineV2Page extends StatefulWidget {
  const TimelineV2Page({
    super.key,
    this.storiesApi,
    this.familiesApi,
    this.inviteApi,
  });

  final StoriesGateway? storiesApi;
  final FamiliesGateway? familiesApi;
  final InviteGateway? inviteApi;

  @override
  State<TimelineV2Page> createState() => _TimelineV2PageState();
}

class _TimelineV2PageState extends State<TimelineV2Page> {
  StoriesGateway? _storiesOverride;
  FamiliesGateway? _familiesOverride;
  String? _familyId;
  List<MemberFamily> _families = const [];
  List<Story> _stories = const [];
  var _loading = true;
  String? _error;
  var _zoom = TimelineZoom.far;
  var _filter = const TimelineV2Filter();
  var _sidebarOpen = false;

  StoriesGateway get _storiesApi =>
      widget.storiesApi ?? (_storiesOverride ??= StoriesApi());

  FamiliesGateway get _familiesApi =>
      widget.familiesApi ?? (_familiesOverride ??= FamiliesApi());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<String?> _resolveFamilyId() async {
    final saved = FamilySelection.id;
    if (saved != null) return saved;
    final invite = widget.inviteApi ?? InviteApi();
    return invite.currentFamilyId();
  }

  Future<void> _bootstrap() async {
    try {
      final id = await _resolveFamilyId();
      final mine = await _familiesApi.listMine();
      if (!mounted) return;
      setState(() {
        _familyId = id;
        _families = mine;
      });
      await _loadStories();
    } on PostgrestException catch (error) {
      _fail(error);
    } on NotSignedInException catch (error) {
      _fail(error);
    }
  }

  Future<void> _loadStories() async {
    final id = _familyId;
    try {
      final rows = id == null
          ? const <Story>[]
          : await _storiesApi.listPublished(id);
      if (!mounted) return;
      setState(() {
        _stories = publishedStories(rows);
        _loading = false;
        _error = null;
      });
    } on PostgrestException catch (error) {
      _fail(error);
    } on NotSignedInException catch (error) {
      _fail(error);
    }
  }

  void _fail(Object error) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = mapRpcError(error) ?? _couldNotLoad;
    });
  }

  Future<void> _selectFamily(String id) async {
    FamilySelection.remember(id);
    if (id == _familyId) return;
    setState(() {
      _familyId = id;
      _filter = const TimelineV2Filter();
      _loading = true;
      _error = null;
    });
    await _loadStories();
  }

  Future<void> _openStory(Story story) async {
    await context.push(AppRoutes.storyPath(story.id));
  }

  void _openFilters(BuildContext context, bool wide) {
    if (wide) {
      setState(() => _sidebarOpen = !_sidebarOpen);
      return;
    }
    Scaffold.of(context).openEndDrawer();
  }

  bool get _noneMatch {
    if (!_filter.isActive || _stories.isEmpty) return false;
    return _stories.every((story) => !_filter.matches(story));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: albumParchment,
      endDrawer: wide ? null : _drawer(),
      appBar: _header(),
      body: _body(wide),
    );
  }

  Widget _body(bool wide) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _failure();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide && _sidebarOpen) _sidebar(),
        Expanded(child: _main(wide)),
      ],
    );
  }

  Widget _main(bool wide) {
    if (_stories.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Text(_emptyFamily)),
      );
    }
    return Column(
      children: [
        Builder(
          builder: (context) => TimelineV2ZoomBar(
            selected: _zoom,
            onSelected: (zoom) => setState(() => _zoom = zoom),
            onFilters: () => _openFilters(context, wide),
            filterActive: _filter.isActive,
          ),
        ),
        Expanded(child: _stage()),
      ],
    );
  }

  Widget _stage() {
    return Stack(
      children: [
        TimelineV2Rails(
          stories: _stories,
          zoom: _zoom,
          filter: _filter,
          onOpen: (story) => _openStory(story),
        ),
        if (_noneMatch)
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _NoMatchCard(
                onClear: () =>
                    setState(() => _filter = const TimelineV2Filter()),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sidebar() {
    return DecoratedBox(
      key: const Key('timeline-v2-filter-sidebar'),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: albumSage.withValues(alpha: 0.45)),
        ),
      ),
      child: SizedBox(width: 360, child: _panel()),
    );
  }

  Widget _drawer() {
    return Drawer(
      key: const Key('timeline-v2-filter-drawer'),
      width: 360,
      backgroundColor: albumParchment,
      child: SafeArea(child: _panel()),
    );
  }

  Widget _panel() {
    final matched = _stories.where(_filter.matches).length;
    return TimelineV2FilterPanel(
      filter: _filter,
      options: TimelineV2FilterOptions.fromStories(_stories),
      matched: matched,
      total: _stories.length,
      onChanged: (filter) => setState(() => _filter = filter),
    );
  }

  Widget _failure() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(
            key: const Key('timeline-v2-retry'),
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _bootstrap();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _header() {
    final family = _currentFamily();
    return AlbumHeader(
      page: AlbumHeaderPage.timelineV2,
      familyName: family?.name ?? 'Family',
      families: _families,
      currentFamilyId: _familyId,
      onFamilySelected: (id) => _selectFamily(id),
      canWrite: false,
    );
  }

  MemberFamily? _currentFamily() {
    for (final family in _families) {
      if (family.id == _familyId) return family;
    }
    return null;
  }
}

class _NoMatchCard extends StatelessWidget {
  const _NoMatchCard({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('timeline-v2-no-match'),
      decoration: BoxDecoration(
        color: albumParchment,
        borderRadius: BorderRadius.circular(albumCardRadius),
        border: Border.all(color: albumPillBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(_noMatch),
            TextButton(onPressed: onClear, child: const Text('Clear filters')),
          ],
        ),
      ),
    );
  }
}
