import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'filter/timeline_filter.dart';
import 'lab_controller.dart';
import 'model/lab_models.dart';
import 'model/seed.dart';
import 'playback/playback_controller.dart';
import 'renderers/renderer_contract.dart';
import 'shell/lab_shortcuts.dart';
import 'theme/lab_theme.dart';
import 'widgets/empty_timeline.dart';
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
      showPerf: _showPerf,
      onTogglePerf: () => setState(() => _showPerf = !_showPerf),
    ),
  );
}

class LabHome extends StatefulWidget {
  const LabHome({
    super.key,
    required this.controller,
    required this.playback,
    this.showPerf = false,
    this.onTogglePerf,
  });

  final LabController controller;
  final PlaybackController playback;
  final bool showPerf;
  final VoidCallback? onTogglePerf;

  @override
  State<LabHome> createState() => _LabHomeState();
}

class _LabHomeState extends State<LabHome> {
  final _rootFocus = FocusNode(debugLabel: 'lab-root');
  final _searchFocus = FocusNode(debugLabel: 'filter-search');
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// The last non-empty timeline, fed to the offstage renderer while the
  /// empty state is up.
  ({LabDataset dataset, List<TimelineEntry> entries})? _lastShown;

  @override
  void dispose() {
    _rootFocus.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Space and the arrows act only when no control has focus.
  bool get _shellFocused => _rootFocus.hasPrimaryFocus;

  void _focusSearch() {
    final scaffold = _scaffoldKey.currentState!;
    if (scaffold.hasEndDrawer && !scaffold.isEndDrawerOpen) {
      scaffold.openEndDrawer();
      // The drawer's FilterPanel attaches the node on the next frame.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _searchFocus.requestFocus(),
      );
    } else {
      _searchFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    // Reduced motion → instant reveals. iOS reports Reduce Motion separately
    // from disableAnimations, so check both.
    playback.reducedMotion =
        MediaQuery.disableAnimationsOf(context) ||
        View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;
    return Shortcuts(
      shortcuts: labShortcuts,
      child: Actions(
        actions: {
          PlayPauseIntent: GuardedAction<PlayPauseIntent>(
            enabled: () => _shellFocused && playback.total > 0,
            onInvoke: (_) =>
                playback.playing ? playback.pause() : playback.play(),
          ),
          StepIntent: GuardedAction<StepIntent>(
            enabled: () => _shellFocused && playback.total > 0,
            onInvoke: (i) => playback.step(i.delta),
          ),
          FocusSearchIntent: GuardedAction<FocusSearchIntent>(
            enabled: () => true,
            onInvoke: (_) => _focusSearch(),
          ),
          // An open drawer takes Esc first (Scaffold's DismissIntent).
          ClearSelectionIntent: GuardedAction<ClearSelectionIntent>(
            enabled: () =>
                widget.controller.selectedStoryId != null &&
                !(_scaffoldKey.currentState?.isEndDrawerOpen ?? false),
            onInvoke: (_) => widget.controller.select(null),
          ),
        },
        child: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => _build(context),
          ),
        ),
      ),
    );
  }

  Widget _build(BuildContext context) {
    final c = widget.controller;
    final playback = widget.playback;
    final empty = c.entries.isEmpty;
    if (!empty) _lastShown = (dataset: c.dataset, entries: c.entries);
    final shown = _lastShown ?? (dataset: c.dataset, entries: c.entries);
    // The renderer stays mounted under the empty state so a transient
    // no-match query keeps its zoom, scroll offset and view switches. While
    // hidden it gets the last non-empty entries, so scrollables keep their
    // extent, and it leaves the focus order.
    final renderer = Offstage(
      offstage: empty,
      child: ExcludeFocus(
        excluding: empty,
        child: KeyedSubtree(
          key: ValueKey((c.renderer, c.datasetSize)),
          child: buildRenderer(
            c.renderer,
            TimelineViewData(
              dataset: shown.dataset,
              entries: shown.entries,
              mode: c.filter.mode,
              selectedId: c.selectedStoryId,
              onSelect: c.select,
              playback: playback,
            ),
          ),
        ),
      ),
    );
    final selected = c.selectedStory;
    final window = MediaQuery.sizeOf(context);
    final wide = window.width >= LabBreakpoint.sidebar;

    return Scaffold(
      key: _scaffoldKey,
      // The keyboard covers the playback and status bars rather than
      // shrinking the renderer (F4). Scroll views below pad themselves.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Timeline Lab'),
        actions: [
          _BenchMenu(
            controller: c,
            showPerf: widget.showPerf,
            onTogglePerf: widget.onTogglePerf,
          ),
          const SizedBox(width: 8),
        ],
        bottom: _RendererSwitch(controller: c),
      ),
      endDrawer: wide
          ? null
          : Drawer(
              key: const Key('filters-drawer'),
              width: math.min(360, window.width * 0.9),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            // Live count: the scrim hides the status bar.
                            child: Text(
                              statusLine(
                                c.matchCount,
                                c.dataset.stories.length,
                                c.filter,
                              ),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          Builder(
                            builder: (context) => IconButton(
                              key: const Key('filters-close'),
                              tooltip: 'Close',
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  Scaffold.of(context).closeEndDrawer(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.viewInsetsOf(context).bottom,
                        ),
                        child: FilterPanel(
                          controller: c,
                          searchFocusNode: _searchFocus,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: Column(
        children: [
          Expanded(
            // One Flex in both layouts so the renderer keeps its element
            // (scroll, zoom, lane mode) across the breakpoint.
            child: Flex(
              direction: wide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide)
                  SizedBox(
                    width: 300,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: FilterPanel(
                        controller: c,
                        searchFocusNode: _searchFocus,
                      ),
                    ),
                  )
                else
                  _FilterBar(filter: c.filter),
                if (wide)
                  const VerticalDivider(width: 1)
                else
                  const Divider(height: 1),
                Expanded(
                  // Touching the timeline takes focus back from the search
                  // field (and dismisses the keyboard).
                  child: Listener(
                    onPointerDown: (_) => _rootFocus.requestFocus(),
                    child: Stack(
                      children: [
                        // Behind the renderer: tiles and cards cover it.
                        PlaybackWatermark(playback: playback),
                        Positioned.fill(child: renderer),
                        if (c.entries.isEmpty)
                          Positioned.fill(
                            child: EmptyTimeline(
                              onClear: () => c.setFilter(
                                TimelineFilter(mode: c.filter.mode),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlaybackBar(playback: playback),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: selected == null
                      ? const SizedBox(width: double.infinity)
                      : _SelectedPanel(controller: c, story: selected),
                ),
                _StatusRow(controller: c, playback: playback),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Below [LabBreakpoint.sidebar]: a single row with the Filters button. The
/// panel opens as an end drawer, so the renderer keeps its full height.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter});

  final TimelineFilter filter;

  int get _activeGroups => [
    filter.query.trim().isNotEmpty,
    filter.fromYear != null || filter.toYear != null,
    filter.personIds.isNotEmpty,
    filter.placeIds.isNotEmpty,
    filter.familyIds.isNotEmpty,
  ].where((on) => on).length;

  @override
  Widget build(BuildContext context) {
    final n = _activeGroups;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: TextButton.icon(
          key: const Key('filters-open'),
          onPressed: () => Scaffold.of(context).openEndDrawer(),
          icon: const Icon(Icons.tune),
          label: Text(n == 0 ? 'Filters' : 'Filters · $n'),
        ),
      ),
    );
  }
}

/// The selected story under the playback bar. Compact windows stack the card
/// over a 3-line body. The panel never takes more than 30% of the window; it
/// scrolls instead.
class _SelectedPanel extends StatelessWidget {
  const _SelectedPanel({required this.controller, required this.story});

  final LabController controller;
  final LabStory story;

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    final compact = window.width < LabBreakpoint.compact;
    final card = StoryCard(
      story: story,
      dataset: controller.dataset,
      matched: true,
      selected: false,
    );
    final body = Text(
      story.body,
      maxLines: compact ? 3 : null,
      overflow: compact ? TextOverflow.ellipsis : null,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    final close = IconButton(
      key: const Key('selected-close'),
      tooltip: 'Close',
      icon: const Icon(Icons.close),
      onPressed: () => controller.select(null),
    );
    return DecoratedBox(
      key: const Key('selected-panel'),
      decoration: const BoxDecoration(
        color: labPillFill,
        border: Border(top: BorderSide(color: labBorder)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: window.height * 0.3),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: card,
                          ),
                        ),
                        close,
                      ],
                    ),
                    const SizedBox(height: 8),
                    body,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    card,
                    const SizedBox(width: 12),
                    Expanded(child: body),
                    close,
                  ],
                ),
        ),
      ),
    );
  }
}

/// One tap per renderer: comparing them is the point of the lab.
class _RendererSwitch extends StatelessWidget implements PreferredSizeWidget {
  const _RendererSwitch({required this.controller});

  final LabController controller;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SegmentedButton<RendererKind>(
        key: const Key('renderer-picker'),
        showSelectedIcon: false,
        segments: [
          for (final k in RendererKind.values)
            ButtonSegment(value: k, label: Text(k.label)),
        ],
        selected: {controller.renderer},
        onSelectionChanged: (s) => controller.setRenderer(s.first),
      ),
    ),
  );
}

/// Dataset size and the performance overlay: bench settings, one button.
class _BenchMenu extends StatelessWidget {
  const _BenchMenu({
    required this.controller,
    required this.showPerf,
    this.onTogglePerf,
  });

  final LabController controller;
  final bool showPerf;
  final VoidCallback? onTogglePerf;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      for (final n in datasetSizes)
        MenuItemButton(
          key: Key('dataset-size-$n'),
          leadingIcon: Icon(n == controller.datasetSize ? Icons.check : null),
          onPressed: () => controller.setDatasetSize(n),
          child: Text('$n stories'),
        ),
      const Divider(height: 1),
      CheckboxMenuButton(
        value: showPerf,
        onChanged: (_) => onTogglePerf?.call(),
        child: const Text('Performance overlay'),
      ),
    ],
    builder: (context, menu, _) => TextButton.icon(
      key: const Key('dataset-size'),
      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      icon: const Icon(Icons.speed),
      label: Text('${controller.datasetSize} stories'),
    ),
  );
}

/// Match count, playback caption and Hide/Dim on one line. Below
/// [LabBreakpoint.compact] the caption drops out so the count keeps the room;
/// the count ellipsizes rather than overflow.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.controller, required this.playback});

  final LabController controller;
  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final filter = c.filter;
    final compact = MediaQuery.sizeOf(context).width < LabBreakpoint.compact;
    final status = Text(
      statusLine(c.matchCount, c.dataset.stories.length, filter),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelLarge,
    );
    return Container(
      key: const Key('status-bar'),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: labBorder)),
      ),
      child: Row(
        children: [
          if (compact) Expanded(child: status) else status,
          if (!compact) ...[
            const SizedBox(width: 16),
            Expanded(
              child: PlaybackCaption(controller: c, playback: playback),
            ),
          ],
          const SizedBox(width: 16),
          SegmentedButton<FilterMode>(
            key: const Key('filter-mode'),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: FilterMode.hide, label: Text('Hide')),
              ButtonSegment(value: FilterMode.dim, label: Text('Dim')),
            ],
            selected: {filter.mode},
            onSelectionChanged: (s) =>
                c.setFilter(filter.copyWith(mode: s.first)),
          ),
        ],
      ),
    );
  }
}
