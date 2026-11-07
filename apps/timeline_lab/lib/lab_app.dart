import 'package:flutter/material.dart';

import 'filter/timeline_filter.dart';
import 'lab_controller.dart';
import 'model/seed.dart';
import 'playback/playback_controller.dart';
import 'renderers/renderer_contract.dart';
import 'theme/lab_theme.dart';
import 'widgets/filter_panel.dart';
import 'widgets/playback_bar.dart';
import 'widgets/story_card.dart';

class LabApp extends StatefulWidget {
  const LabApp({super.key, this.useGoogleFonts = true, this.controller});

  final bool useGoogleFonts;
  final LabController? controller;

  @override
  State<LabApp> createState() => _LabAppState();
}

class _LabAppState extends State<LabApp> with SingleTickerProviderStateMixin {
  late final LabController _controller = widget.controller ?? LabController();
  late final PlaybackController _playback = PlaybackController(
    vsync: this,
    lab: _controller,
  );
  bool _showPerf = false;

  @override
  void dispose() {
    _playback.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    showPerformanceOverlay: _showPerf,
    theme: labTheme(useGoogleFonts: widget.useGoogleFonts),
    home: LabHome(
      controller: _controller,
      playback: _playback,
      onTogglePerf: () => setState(() => _showPerf = !_showPerf),
    ),
  );
}

class LabHome extends StatelessWidget {
  const LabHome({
    super.key,
    required this.controller,
    required this.playback,
    this.onTogglePerf,
  });

  final LabController controller;
  final PlaybackController playback;
  final VoidCallback? onTogglePerf;

  @override
  Widget build(BuildContext context) {
    // Reduced motion → instant reveals. iOS reports Reduce Motion separately
    // from disableAnimations, so check both.
    playback.reducedMotion =
        MediaQuery.disableAnimationsOf(context) ||
        View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final c = controller;
    final renderer = KeyedSubtree(
      key: ValueKey((c.renderer, c.datasetSize)),
      child: buildRenderer(
        c.renderer,
        TimelineViewData(
          dataset: c.dataset,
          entries: c.entries,
          mode: c.filter.mode,
          selectedId: c.selectedStoryId,
          onSelect: c.select,
          playback: playback,
        ),
      ),
    );
    final selected = c.selectedStory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline Lab'),
        actions: [
          DropdownMenu<RendererKind>(
            key: const Key('renderer-picker'),
            initialSelection: c.renderer,
            label: const Text('Renderer'),
            width: 220,
            onSelected: (k) {
              if (k != null) c.setRenderer(k);
            },
            dropdownMenuEntries: [
              for (final k in RendererKind.values)
                DropdownMenuEntry(value: k, label: k.label),
            ],
          ),
          const SizedBox(width: 12),
          DropdownMenu<int>(
            key: const Key('dataset-size'),
            initialSelection: c.datasetSize,
            label: const Text('Stories'),
            width: 140,
            onSelected: (n) {
              if (n != null) c.setDatasetSize(n);
            },
            dropdownMenuEntries: [
              for (final n in datasetSizes)
                DropdownMenuEntry(value: n, label: '$n'),
            ],
          ),
          IconButton(
            tooltip: 'Performance overlay',
            icon: const Icon(Icons.speed),
            onPressed: onTogglePerf,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                // One Flex in both layouts so the renderer keeps its element
                // (scroll, zoom, lane mode) across the breakpoint.
                return Flex(
                  direction: wide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      SizedBox(
                        width: 300,
                        child: SingleChildScrollView(
                          child: FilterPanel(controller: c),
                        ),
                      )
                    else
                      ExpansionTile(
                        title: const Text('Filters'),
                        children: [FilterPanel(controller: c)],
                      ),
                    if (wide)
                      const VerticalDivider(width: 1)
                    else
                      const Divider(height: 1),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(child: renderer),
                          PlaybackWatermark(playback: playback),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          PlaybackBar(controller: c, playback: playback),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: selected == null
                ? const SizedBox(width: double.infinity)
                : DecoratedBox(
                    key: const Key('selected-panel'),
                    decoration: const BoxDecoration(
                      color: labPillFill,
                      border: Border(top: BorderSide(color: labBorder)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StoryCard(
                            story: selected,
                            dataset: c.dataset,
                            matched: true,
                            selected: false,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selected.body,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          IconButton(
                            key: const Key('selected-close'),
                            tooltip: 'Close',
                            icon: const Icon(Icons.close),
                            onPressed: () => c.select(null),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Container(
            key: const Key('status-bar'),
            height: 40,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: labBorder)),
            ),
            child: Text(
              statusLine(c.matchCount, c.dataset.stories.length, c.filter),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
