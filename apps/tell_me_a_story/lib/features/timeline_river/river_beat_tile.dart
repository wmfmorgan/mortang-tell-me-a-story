import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../timeline/timeline_zoom.dart' hide decadeStartYear;
import 'river_beat.dart';
import 'river_density.dart';
import 'river_medallion.dart';
import 'river_story_card.dart';

/// One beat on the sage band, faded by how far it sits from the focus.
class RiverBeatTile extends StatelessWidget {
  const RiverBeatTile({
    super.key,
    required this.beat,
    required this.density,
    required this.focused,
    required this.distance,
    required this.reducedMotion,
    required this.showDecade,
    required this.focusId,
    required this.photos,
    required this.onTap,
    required this.onOpen,
  });

  final RiverBeat beat;
  final RiverDensity density;
  final bool focused;
  final int distance;
  final bool reducedMotion;
  final bool showDecade;
  final String focusId;
  final PhotosGateway? photos;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      key: Key('river-fade-${beat.id}'),
      opacity: riverBeatOpacity(distance, reducedMotion: reducedMotion),
      child: Transform.translate(
        offset: Offset(
          0,
          riverBeatShift(distance, reducedMotion: reducedMotion),
        ),
        child: _row(context),
      ),
    );
  }

  Widget _row(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 96, child: _landmark(context)),
            SizedBox(width: 128, child: Center(child: _marker())),
            const SizedBox(width: 12),
            Expanded(child: _detail(context)),
          ],
        ),
      ),
    );
  }

  Widget _landmark(BuildContext context) {
    if (!showDecade || density == RiverDensity.overview) {
      return const SizedBox.shrink();
    }
    return Text(
      '${decadeStartYearDate(beat.anchorYear)}s',
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _marker() {
    if (!beat.matches) return _dot();
    if (density == RiverDensity.read) return _dot(filled: true);
    return RiverMedallion(
      stories: beat.stories,
      size: density == RiverDensity.overview ? 112 : 64,
      label: riverBeatSemantics(beat: beat, density: density, focusId: focusId),
      photos: photos,
      ripple: focused && !reducedMotion,
      onTap: _activate,
    );
  }

  Widget _dot({bool filled = false}) {
    final label = riverBeatSemantics(
      beat: beat,
      density: density,
      focusId: focusId,
    );
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 44,
        height: 44,
        child: InkWell(
          excludeFromSemantics: true,
          customBorder: const CircleBorder(),
          onTap: _activate,
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? albumTerracotta : sageTint,
                border: Border.all(
                  color: filled ? albumTerracotta : albumInkDim,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail(BuildContext context) {
    if (!beat.matches) return _dimTitle(context);
    return switch (density) {
      RiverDensity.overview => _decadeTitle(context),
      RiverDensity.browse =>
        focused ? _card(expanded: false) : _yearTitle(context),
      RiverDensity.read => _card(expanded: focused),
    };
  }

  Widget _decadeTitle(BuildContext context) {
    return Text(
      riverDecadeLine(beat),
      key: focused ? const Key('river-focused-label') : null,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _yearTitle(BuildContext context) {
    return Text(
      '${beat.anchorYear}',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _dimTitle(BuildContext context) {
    final story = riverLead(beat, focusId);
    final title = density == RiverDensity.overview
        ? riverDecadeLine(beat)
        : storyTitle(story);
    return Text(
      title,
      key: focused ? const Key('river-focused-label') : null,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: albumInkDim),
    );
  }

  Widget _card({required bool expanded}) {
    return RiverStoryCard(
      story: riverLead(beat, focusId),
      photos: photos,
      focused: focused,
      expanded: expanded,
      onTap: _activate,
    );
  }

  void _activate() {
    if (focused) {
      onOpen();
      return;
    }
    onTap();
  }
}

int decadeStartYearDate(int year) => (year ~/ 10) * 10;
