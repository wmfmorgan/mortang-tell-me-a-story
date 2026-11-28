import 'package:flutter/material.dart';

import '../../core/theme/album_header.dart';
import '../../data/families_api.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import 'river_beat.dart';
import 'river_density.dart';
import 'river_density_pill.dart';
import 'river_filter.dart';
import 'river_filter_options.dart';
import 'river_filter_panel.dart';
import 'river_filter_pills.dart';
import 'river_filter_sheet.dart';
import 'river_jump.dart';
import 'river_no_match.dart';
import 'river_scrubber.dart';
import 'river_spine.dart';

/// Header, density, filters, the river, and the scrubber.
class RiverScaffold extends StatelessWidget {
  const RiverScaffold({
    super.key,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.familyName,
    required this.families,
    required this.familyId,
    required this.stories,
    required this.filter,
    required this.density,
    required this.storyId,
    required this.announcement,
    required this.photos,
    required this.onFamilySelected,
    required this.onFilter,
    required this.onDensity,
    required this.onDensityStep,
    required this.onFocusBeat,
    required this.onOpen,
    required this.onMove,
    required this.onEdge,
    required this.onJumpYear,
    required this.onJumpDecade,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final String familyName;
  final List<MemberFamily> families;
  final String? familyId;
  final List<Story> stories;
  final RiverFilter filter;
  final RiverDensity density;
  final String storyId;
  final String announcement;
  final PhotosGateway? photos;
  final ValueChanged<String> onFamilySelected;
  final ValueChanged<RiverFilter> onFilter;
  final ValueChanged<RiverDensity> onDensity;
  final ValueChanged<int> onDensityStep;
  final ValueChanged<RiverBeat> onFocusBeat;
  final VoidCallback onOpen;
  final ValueChanged<int> onMove;
  final ValueChanged<bool> onEdge;
  final ValueChanged<int> onJumpYear;
  final ValueChanged<int> onJumpDecade;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Column(
      children: [
        _header(),
        _toolbar(context, width),
        RiverFilterPills(
          filter: filter,
          options: _options,
          onChanged: onFilter,
        ),
        if (announcement.isNotEmpty) _live(announcement),
        Expanded(child: _body(context, width >= 900, width < 600)),
      ],
    );
  }

  Widget _header() {
    return AlbumHeader(
      page: AlbumHeaderPage.timeline,
      familyName: familyName.isEmpty ? 'Family' : familyName,
      families: families,
      currentFamilyId: familyId,
      onFamilySelected: onFamilySelected,
    );
  }

  Widget _toolbar(BuildContext context, double width) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          RiverDensityPill(density: density, onChanged: onDensity),
          _toolButton(
            key: const Key('river-filters'),
            label: 'Filters',
            onPressed: () => _openFilters(context, width),
          ),
          _toolButton(
            key: const Key('river-jump'),
            label: 'Jump to year',
            onPressed: () => showRiverYearJump(context, onJumpYear),
          ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required Key key,
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      key: key,
      style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  Widget _live(String label) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: const SizedBox(width: 1, height: 1),
    );
  }

  Widget _body(BuildContext context, bool wide, bool phone) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) return _failure(context);
    return Column(
      children: [
        if (density == RiverDensity.overview && familyName.isNotEmpty)
          _caption(context),
        if (filter.isActive && _matched == 0)
          RiverNoMatch(onClear: () => onFilter(const RiverFilter())),
        Expanded(
          child: Row(
            children: [
              if (wide) _sidebar(),
              Expanded(child: _spine()),
              if (!phone) _scrubber(Axis.vertical),
            ],
          ),
        ),
        if (phone) _scrubber(Axis.horizontal),
      ],
    );
  }

  Widget _caption(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        riverOverviewCaption(familyName),
        key: const Key('river-overview-caption'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _failure(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            key: const Key('timeline-river-retry'),
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _sidebar() {
    return SizedBox(
      width: 300,
      child: RiverFilterPanel(
        filter: filter,
        options: _options,
        matched: _matched,
        total: stories.length,
        onChanged: onFilter,
      ),
    );
  }

  Widget _spine() {
    return RiverSpine(
      beats: _beats,
      density: density,
      focusId: storyId,
      photos: photos,
      onFocus: onFocusBeat,
      onOpen: onOpen,
      onMove: onMove,
      onEdge: onEdge,
      onDensity: onDensityStep,
    );
  }

  Widget _scrubber(Axis axis) {
    return SizedBox(
      width: axis == Axis.vertical ? 112 : null,
      height: axis == Axis.horizontal ? 88 : null,
      child: RiverScrubber(
        stories: stories,
        filter: filter,
        showingDecade: _showingDecade,
        axis: axis,
        onSelect: onJumpDecade,
      ),
    );
  }

  void _openFilters(BuildContext context, double width) {
    if (width >= 900) return;
    final matched = _matched;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => RiverFilterSheet(
        filter: filter,
        options: _options,
        matched: matched,
        total: stories.length,
        onChanged: onFilter,
      ),
    );
  }

  RiverFilterOptions get _options => RiverFilterOptions.fromStories(stories);

  int get _matched => riverMatchCount(stories, filter);

  List<RiverBeat> get _beats {
    return buildRiverBeats(stories: stories, density: density, filter: filter);
  }

  int get _showingDecade {
    for (final story in stories) {
      if (story.id == storyId) return decadeStartYear(story.publishedStart);
    }
    if (stories.isEmpty) return 0;
    return decadeStartYear(stories.last.publishedStart);
  }
}
