import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import 'callout_layout.dart';

class RailGutter extends StatelessWidget {
  const RailGutter({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: SizedBox.shrink()),
        SizedBox(
          width: calloutGutter,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                left: 27,
                width: 2,
                child: ColoredBox(color: albumInk.withValues(alpha: 0.16)),
              ),
            ],
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}
