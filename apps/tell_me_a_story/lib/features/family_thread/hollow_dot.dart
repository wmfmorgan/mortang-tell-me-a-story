import 'package:flutter/widgets.dart';

import '../../core/theme/album_theme.dart';

class HollowDot extends StatelessWidget {
  const HollowDot({super.key});

  static const double diameter = 12;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: albumInk, width: 2)),
        ),
      ),
    );
  }
}
