import 'package:flutter/material.dart';

import 'timeline_zoom.dart';
import 'zoom_switch.dart';

class DialSubheader extends StatelessWidget {
  const DialSubheader({
    super.key,
    required this.selected,
    required this.onMacro,
    required this.onMid,
    required this.onFullCards,
  });

  final TimelineZoom selected;
  final VoidCallback onMacro;
  final VoidCallback onMid;
  final VoidCallback onFullCards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        spacing: 16,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: ZoomSwitch(
                  selected: selected,
                  onMacro: onMacro,
                  onMid: onMid,
                  onFullCards: onFullCards,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
