import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import 'river_beat.dart';

/// Circle crop of the lead photo, or a terracotta initial on blush.
class RiverMedallion extends StatefulWidget {
  const RiverMedallion({
    super.key,
    required this.stories,
    required this.size,
    required this.label,
    required this.photos,
    required this.ripple,
    required this.onTap,
  });

  final List<Story> stories;
  final double size;
  final String label;
  final PhotosGateway? photos;
  final bool ripple;
  final VoidCallback onTap;

  @override
  State<RiverMedallion> createState() => _RiverMedallionState();
}

class _RiverMedallionState extends State<RiverMedallion> {
  final Map<String, Uint8List> _bytes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gateway = widget.photos;
    if (gateway == null) return;
    final leads = widget.stories.take(4);
    for (final story in leads) {
      if (story.photoPaths.isEmpty) continue;
      final bytes = await downloadStoryPhotoBytes(
        gateway,
        story.photoPaths.first,
        failure: StoryPhotoFailure.storageOrTransport,
      );
      if (!mounted) return;
      if (bytes == null) continue;
      setState(() => _bytes[story.id] = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: SizedBox(
        width: math.max(widget.size, 44),
        height: math.max(widget.size, 44),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.ripple)
              _Ripple(size: widget.size + 16, key: const Key('river-ripple')),
            _disc(),
          ],
        ),
      ),
    );
  }

  Widget _disc() {
    return Material(
      color: albumBackdropClear,
      child: InkWell(
        customBorder: const CircleBorder(),
        excludeFromSemantics: true,
        onTap: widget.onTap,
        child: Ink(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: albumTerracotta, width: 2),
          ),
          child: ClipOval(child: _face()),
        ),
      ),
    );
  }

  Widget _face() {
    if (widget.size >= 100) return _mosaic();
    return _one(widget.stories.isEmpty ? null : widget.stories.first);
  }

  Widget _one(Story? story) {
    if (story == null) return const ColoredBox(color: albumBlush);
    final bytes = _bytes[story.id];
    if (bytes == null) return _initial(story);
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => _initial(story),
    );
  }

  Widget _mosaic() {
    final stories = widget.stories;
    final leftover = stories.length > 4 ? stories.length - 3 : 0;
    final shown = leftover > 0 ? stories.take(3).toList() : stories.take(4);
    return ColoredBox(
      color: albumBlush,
      child: Column(
        children: [
          Expanded(child: Row(children: [_cell(shown, 0), _cell(shown, 1)])),
          Expanded(child: Row(children: [_cell(shown, 2), _corner(leftover)])),
        ],
      ),
    );
  }

  Widget _cell(Iterable<Story> stories, int index) {
    final list = stories.toList();
    return Expanded(child: _one(index < list.length ? list[index] : null));
  }

  Widget _corner(int leftover) {
    if (leftover > 0) {
      return Expanded(
        child: ColoredBox(
          color: albumBlush,
          child: Center(
            child: Text(
              '$leftover',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: albumTerracotta),
            ),
          ),
        ),
      );
    }
    final stories = widget.stories;
    if (stories.length >= 4) return Expanded(child: _one(stories[3]));
    return const Expanded(child: ColoredBox(color: albumBlush));
  }

  Widget _initial(Story story) {
    return ColoredBox(
      color: albumBlush,
      child: Center(
        child: Text(
          riverInitial(story),
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: albumTerracotta),
        ),
      ),
    );
  }
}

class _Ripple extends StatefulWidget {
  const _Ripple({super.key, required this.size});

  final double size;

  @override
  State<_Ripple> createState() => _RippleState();
}

class _RippleState extends State<_Ripple> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _RipplePainter(_controller.value),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  const _RipplePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = albumTerracotta.withValues(alpha: (1 - t).clamp(0.15, 1));
    final radius = size.shortestSide / 2 * (0.72 + (0.28 * t));
    canvas.drawCircle(size.center(Offset.zero), radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.t != t;
  }
}
