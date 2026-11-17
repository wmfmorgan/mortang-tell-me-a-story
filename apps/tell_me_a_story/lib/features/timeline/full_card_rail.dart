import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import 'dial_subheader.dart';
import 'full_card_row.dart';
import 'timeline_arrow_keys.dart';
import 'callout_layout.dart';
import 'timeline_empty_tap.dart';
import 'timeline_zoom.dart';

class FullCardRail extends StatefulWidget {
  const FullCardRail({
    super.key,
    required this.stories,
    required this.focusedId,
    required this.photos,
    required this.branching,
    this.originStoryId,
    this.originTag,
    required this.anchorFor,
    required this.onOpen,
    required this.onEmpty,
    required this.onFocus,
    required this.onOpenBranch,
    required this.onMacro,
    required this.onMid,
    this.onPerson,
  });

  final List<Story> stories;
  final String? focusedId;
  final PhotosGateway? photos;
  final RailBranching branching;
  final String? originStoryId;
  final String? originTag;
  final GlobalKey Function(String id) anchorFor;
  final ValueChanged<Story> onOpen;
  final VoidCallback onEmpty;
  final ValueChanged<String> onFocus;
  final ValueChanged<String> onOpenBranch;
  final VoidCallback onMacro;
  final VoidCallback onMid;
  final void Function(({String id, String name}) person)? onPerson;

  @override
  State<FullCardRail> createState() => _FullCardRailState();
}

class _FullCardRailState extends State<FullCardRail> {
  final _viewportKey = GlobalKey();
  final _scroll = ScrollController();
  String? _centerId;
  Map<String, double> _opacities = const {};

  @override
  void initState() {
    super.initState();
    _centerId = widget.focusedId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerThenMeasure());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _step(int direction) {
    final stories = widget.stories;
    if (stories.isEmpty) return;
    final current = _centerId ?? widget.focusedId ?? stories.first.id;
    var index = stories.indexWhere((story) => story.id == current);
    if (index < 0) index = 0;
    final next = index + direction;
    final target = next < 0 || next >= stories.length
        ? null
        : widget.anchorFor(stories[next].id).currentContext;
    scrollDialStep(controller: _scroll, direction: direction, target: target);
  }

  void _centerThenMeasure() {
    if (!mounted) return;
    final id = _centerId;
    final target = id == null ? null : widget.anchorFor(id).currentContext;
    if (target != null && target.mounted) {
      Scrollable.ensureVisible(target, alignment: 0.5, duration: Duration.zero);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
  }

  @override
  void didUpdateWidget(covariant FullCardRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.focusedId;
    if (next != null && next != oldWidget.focusedId) {
      _centerId = next;
    }
  }

  bool _sameOpacity(Map<String, double> next) {
    if (next.length != _opacities.length) return false;
    for (final entry in next.entries) {
      final previous = _opacities[entry.key];
      if (previous == null || (previous - entry.value).abs() > 0.02) {
        return false;
      }
    }
    return true;
  }

  void _measure() {
    if (!mounted) return;
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final origin = viewport.localToGlobal(Offset.zero);
    final centerY = origin.dy + viewport.size.height / 2;
    String? bestId;
    var best = double.infinity;
    final opacities = <String, double>{};
    for (final story in widget.stories) {
      final row =
          widget.anchorFor(story.id).currentContext?.findRenderObject()
              as RenderBox?;
      if (row == null || !row.hasSize) continue;
      final top = row.localToGlobal(Offset.zero).dy;
      opacities[story.id] = fullCardOpacity(
        rowTop: top,
        rowHeight: row.size.height,
        viewportTop: origin.dy,
        viewportHeight: viewport.size.height,
      );
      final distance = (top + row.size.height / 2 - centerY).abs();
      if (distance < best) {
        best = distance;
        bestId = story.id;
      }
    }
    final idChanged = bestId != null && bestId != _centerId;
    if (!idChanged && _sameOpacity(opacities)) return;
    setState(() {
      if (bestId != null) _centerId = bestId;
      _opacities = opacities;
    });
    final id = bestId;
    if (idChanged && id != null && id != widget.focusedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && id != widget.focusedId) widget.onFocus(id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArrowKeys(
      onStep: _step,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: DialSubheader(
              selected: TimelineZoom.near,
              onMacro: widget.onMacro,
              onMid: widget.onMid,
              onFullCards: () {},
            ),
          ),
          Expanded(
            child: EmptyTap(
              onTap: widget.onEmpty,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification ||
                      notification is ScrollEndNotification) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _measure();
                    });
                  }
                  return false;
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 800;
                    final pad = constraints.maxHeight / 2;
                    final gap = constraints.maxWidth < 720 ? 32.0 : 80.0;
                    return Stack(
                      key: _viewportKey,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Align(
                              alignment: wide
                                  ? Alignment.center
                                  : Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(left: wide ? 0 : 13),
                                child: Container(
                                  key: const Key('timeline-spine'),
                                  width: 2,
                                  color: albumInk.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        ListView(
                          controller: _scroll,
                          scrollCacheExtent: const ScrollCacheExtent.pixels(
                            100000,
                          ),
                          padding: EdgeInsets.fromLTRB(
                            wide ? 24 : 8,
                            pad,
                            24,
                            pad,
                          ),
                          children: [
                            for (var i = 0; i < widget.stories.length; i++)
                              FullCardRow(
                                key: widget.anchorFor(widget.stories[i].id),
                                story: widget.stories[i],
                                frame: widget.branching.frameFor(
                                  widget.stories[i],
                                ),
                                cardOnLeft: i.isEven,
                                wide: wide,
                                originTag:
                                    widget.stories[i].id == widget.originStoryId
                                    ? widget.originTag
                                    : null,
                                onOpenBranch: widget.onOpenBranch,
                                onPerson: widget.onPerson,
                                focused: widget.stories[i].id == _centerId,
                                opacity:
                                    _opacities[widget.stories[i].id] ??
                                    (widget.stories[i].id == _centerId
                                        ? 1
                                        : 0.4),
                                gap: gap,
                                photos: widget.photos,
                                onOpen: () => widget.onOpen(widget.stories[i]),
                              ),
                          ],
                        ),
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    albumParchment,
                                    albumParchmentClear,
                                    albumParchmentClear,
                                    albumParchment,
                                  ],
                                  stops: [0, 0.18, 0.82, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
