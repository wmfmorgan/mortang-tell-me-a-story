import 'package:flutter/widgets.dart';

import '../../core/theme/album_theme.dart';

const _spineWidth = 2.0;

class ThreadBand extends StatelessWidget {
  const ThreadBand({
    super.key,
    required this.bandWidth,
    required this.roundTop,
    required this.roundBottom,
    required this.knot,
  });

  final double bandWidth;
  final bool roundTop;
  final bool roundBottom;
  final bool knot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: bandWidth,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: _end(roundTop),
          bottom: _end(roundBottom),
        ),
        child: ColoredBox(
          color: sageTint,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                left: (bandWidth - _spineWidth) / 2,
                width: _spineWidth,
                child: const ColoredBox(color: albumTerracotta),
              ),
              if (knot) const _Knot(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Knot extends StatelessWidget {
  const _Knot();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: 4),
        child: SizedBox.square(
          dimension: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: albumTerracotta,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

Radius _end(bool round) {
  return round ? const Radius.circular(albumCardRadius) : Radius.zero;
}
