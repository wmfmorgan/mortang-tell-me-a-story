import 'package:flutter/widgets.dart';

import '../../core/theme/album_theme.dart';

class StitchRing extends StatefulWidget {
  const StitchRing({super.key});

  @override
  State<StitchRing> createState() => _StitchRingState();
}

class _StitchRingState extends State<StitchRing>
    with SingleTickerProviderStateMixin {
  AnimationController? _motion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion?.dispose();
      _motion = null;
      return;
    }
    if (_motion != null) return;
    final motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _motion = motion;
    motion.forward();
  }

  @override
  void dispose() {
    _motion?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = _motion;
    if (motion == null) return const _StillRing();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: motion,
        builder: (context, _) => CustomPaint(
          painter: _StitchPainter(motion.value),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _StillRing extends StatelessWidget {
  const _StillRing();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(painter: _StitchPainter(1), child: SizedBox.expand()),
    );
  }
}

class _StitchPainter extends CustomPainter {
  const _StitchPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(0.5);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(albumCardRadius)),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = albumTerracotta;
    for (final contour in path.computeMetrics()) {
      final length = contour.length * progress;
      var start = 0.0;
      while (start < length) {
        final end = start + 4 > length ? length : start + 4;
        canvas.drawPath(contour.extractPath(start, end), paint);
        start = end + 3;
      }
    }
  }

  @override
  bool shouldRepaint(_StitchPainter old) => old.progress != progress;
}
