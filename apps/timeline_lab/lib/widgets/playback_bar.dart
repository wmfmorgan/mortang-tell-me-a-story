import 'package:flutter/material.dart';

import '../lab_controller.dart';
import '../playback/playback_controller.dart';
import '../playback/playback_schedule.dart';
import '../theme/lab_theme.dart';

String speedLabel(double s) => '${s == s.roundToDouble() ? s.toInt() : s}×';

String designLabel(PlaybackDesign d) => switch (d) {
  PlaybackDesign.sweep => 'Sweep',
  PlaybackDesign.steps => 'Steps',
};

/// Transport, scrubber, options and camera follow. Only this bar, the
/// caption and the watermark rebuild on ticks; renderers listen directly.
class PlaybackBar extends StatelessWidget {
  const PlaybackBar({super.key, required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, _) {
      final pb = playback;
      final steps = pb.design == PlaybackDesign.steps;
      return Container(
        key: const Key('playback-bar'),
        padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: labBorder)),
        ),
        child: Row(
          children: [
            IconButton(
              key: const Key('playback-play'),
              tooltip: pb.playing ? 'Pause' : 'Play',
              icon: Icon(pb.playing ? Icons.pause : Icons.play_arrow),
              onPressed: pb.total == 0
                  ? null
                  : (pb.playing ? pb.pause : pb.play),
            ),
            IconButton(
              key: const Key('playback-stop'),
              tooltip: 'Stop and show all',
              icon: const Icon(Icons.stop),
              onPressed: pb.active ? pb.stop : null,
            ),
            if (steps) ...[
              IconButton(
                key: const Key('playback-prev'),
                tooltip: 'Previous',
                icon: const Icon(Icons.skip_previous),
                onPressed: pb.total == 0 ? null : () => pb.step(-1),
              ),
              IconButton(
                key: const Key('playback-next'),
                tooltip: 'Next',
                icon: const Icon(Icons.skip_next),
                onPressed: pb.total == 0 ? null : () => pb.step(1),
              ),
            ],
            Expanded(
              child: Slider(
                key: const Key('playback-scrubber'),
                value: pb.progress,
                onChangeStart: (_) => pb.pause(),
                onChanged: pb.total == 0
                    ? null
                    : (v) => pb.seek(v * pb.duration),
              ),
            ),
            _PlaybackOptions(playback: pb),
            IconButton(
              key: const Key('playback-follow'),
              tooltip: pb.follow
                  ? 'Camera follows playback'
                  : 'Camera free (tap to follow)',
              isSelected: pb.follow,
              icon: const Icon(Icons.center_focus_weak),
              selectedIcon: const Icon(Icons.center_focus_strong),
              onPressed: () => pb.setFollow(!pb.follow),
            ),
          ],
        ),
      );
    },
  );
}

/// Design and speed in one menu whose label shows both (`Sweep · 1×`).
class _PlaybackOptions extends StatelessWidget {
  const _PlaybackOptions({required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final pb = playback;
    return MenuAnchor(
      menuChildren: [
        for (final d in PlaybackDesign.values)
          MenuItemButton(
            key: Key('playback-design-${d.name}'),
            leadingIcon: Icon(d == pb.design ? Icons.check : null),
            onPressed: () => pb.setDesign(d),
            child: Text(designLabel(d)),
          ),
        const Divider(height: 1),
        for (final s in playbackSpeeds)
          MenuItemButton(
            key: Key('playback-speed-$s'),
            leadingIcon: Icon(s == pb.speed ? Icons.check : null),
            onPressed: () => pb.setSpeed(s),
            child: Text(speedLabel(s)),
          ),
      ],
      builder: (context, menu, _) => TextButton.icon(
        key: const Key('playback-design'),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: const Icon(Icons.tune),
        label: Text('${designLabel(pb.design)} · ${speedLabel(pb.speed)}'),
      ),
    );
  }
}

/// Playback state in words; a polite live region in the status row.
class PlaybackCaption extends StatelessWidget {
  const PlaybackCaption({
    super.key,
    required this.controller,
    required this.playback,
  });

  final LabController controller;
  final PlaybackController playback;

  String _caption() {
    final pb = playback;
    if (!pb.active) return 'Press play to replay the timeline';
    final count = '${pb.revealedCount} of ${pb.total}';
    final current = pb.current;
    if (pb.design == PlaybackDesign.steps && current != null) {
      return '${controller.dataset.dateLabel(current)} · ${current.title} '
          '· $count';
    }
    return '${pb.cursorYear!.floor()} · $count';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, _) => Semantics(
      liveRegion: true,
      child: Text(
        _caption(),
        key: const Key('playback-caption'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    ),
  );
}

/// Large year behind the renderer while a session is active (Gapminder).
class PlaybackWatermark extends StatelessWidget {
  const PlaybackWatermark({super.key, required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context) => Positioned(
    right: 24,
    bottom: 8,
    child: IgnorePointer(
      child: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final year = playback.cursorYear;
          if (year == null) return const SizedBox.shrink();
          return Text(
            '${year.floor()}',
            key: const Key('playback-watermark'),
            style: Theme.of(context).textTheme.headlineLarge
                ?.copyWith(fontSize: 72, color: labWatermark),
          );
        },
      ),
    ),
  );
}
