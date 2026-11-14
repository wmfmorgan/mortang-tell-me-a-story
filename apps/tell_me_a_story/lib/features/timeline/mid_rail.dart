import 'package:flutter/material.dart';

import '../../data/stories_api.dart';
import 'dial_fade.dart';
import 'dial_row.dart';
import 'dial_subheader.dart';
import 'timeline_arrow_keys.dart';
import 'timeline_branching.dart';
import 'timeline_empty_tap.dart';
import 'timeline_zoom.dart';

class MidRail extends StatefulWidget {
  const MidRail({
    super.key,
    required this.stories,
    required this.focusedId,
    required this.branching,
    this.originStoryId,
    this.originTag,
    required this.anchorFor,
    required this.onStub,
    required this.onNode,
    required this.onEmpty,
    required this.onFocus,
    required this.onOpenBranch,
    required this.onMacro,
    required this.onFullCards,
  });

  final List<Story> stories;
  final String? focusedId;
  final RailBranching branching;
  final String? originStoryId;
  final String? originTag;
  final GlobalKey Function(String id) anchorFor;
  final ValueChanged<Story> onStub;
  final ValueChanged<Story> onNode;
  final VoidCallback onEmpty;
  final ValueChanged<String> onFocus;
  final ValueChanged<String> onOpenBranch;
  final VoidCallback onMacro;
  final VoidCallback onFullCards;

  @override
  State<MidRail> createState() => _MidRailState();
}

class _MidRailState extends State<MidRail> {
  final _viewportKey = GlobalKey();
  final _scroll = ScrollController();
  String? _centerId;
  Map<String, double> _opacities = const {};
  var _centered = false;

  @override
  void initState() {
    super.initState();
    _centerId = widget.focusedId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerInitial());
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

  @override
  void didUpdateWidget(covariant MidRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.focusedId;
    if (next != null && next != oldWidget.focusedId && next != _centerId) {
      _centerId = next;
      _centerOn(next);
    }
  }

  void _centerInitial() {
    if (!mounted || _centered) return;
    _centered = true;
    final id =
        _centerId ?? (widget.stories.isEmpty ? null : widget.stories.first.id);
    if (id == null) return;
    _centerId = id;
    _centerOn(id);
  }

  void _centerOn(String id) {
    final target = widget.anchorFor(id).currentContext;
    if (target == null || !target.mounted) return;
    Scrollable.ensureVisible(target, alignment: 0.5, duration: Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
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
    final centerY = viewport
        .localToGlobal(Offset(0, viewport.size.height / 2))
        .dy;
    final half = viewport.size.height / 2;
    String? bestId;
    var best = double.infinity;
    final opacities = <String, double>{};
    for (final story in widget.stories) {
      final row =
          widget.anchorFor(story.id).currentContext?.findRenderObject()
              as RenderBox?;
      if (row == null || !row.hasSize) continue;
      final mid = row.localToGlobal(Offset(0, row.size.height / 2)).dy;
      final distance = (mid - centerY).abs();
      opacities[story.id] = dialOpacity(distance: distance, halfExtent: half);
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
              selected: TimelineZoom.mid,
              onMacro: widget.onMacro,
              onMid: () {},
              onFullCards: widget.onFullCards,
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
                child: Stack(
                  key: _viewportKey,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final pad = constraints.maxHeight / 2;
                        return ListView(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(24, pad, 24, pad),
                          children: [
                            for (var i = 0; i < widget.stories.length; i++)
                              DialRow(
                                key: widget.anchorFor(widget.stories[i].id),
                                story: widget.stories[i],
                                frame: widget.branching.frameFor(
                                  widget.stories[i],
                                ),
                                originTag:
                                    widget.stories[i].id == widget.originStoryId
                                    ? widget.originTag
                                    : null,
                                onOpenBranch: widget.onOpenBranch,
                                cardOnLeft: i.isEven,
                                focused: widget.stories[i].id == _centerId,
                                opacity:
                                    _opacities[widget.stories[i].id] ??
                                    (widget.stories[i].id == _centerId
                                        ? 1
                                        : 0.35),
                                onTap: () => widget.onStub(widget.stories[i]),
                                onNode: () => widget.onNode(widget.stories[i]),
                              ),
                          ],
                        );
                      },
                    ),
                    const DialFade(top: true),
                    const DialFade(top: false),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
