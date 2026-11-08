import 'package:flutter/material.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';

/// The one rail line every zoom draws behind its dots: a 2 pt [albumRule]
/// stroke the height of the viewport, keyed `timeline-spine`. Fill a [Stack]
/// with it.
class RailSpine extends StatelessWidget {
  const RailSpine({this.left}) : super(key: const Key('timeline-spine'));

  /// The line's centre, measured from the viewport's left edge. Null centres
  /// it in the viewport.
  final double? left;

  @override
  Widget build(BuildContext context) {
    const line = SizedBox(
      width: AlbumStroke.mark,
      height: double.infinity,
      child: ColoredBox(color: albumRule),
    );
    final at = left;
    return Positioned.fill(
      child: IgnorePointer(
        child: at == null
            ? const Center(child: line)
            : Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: at - AlbumStroke.mark / 2),
                  child: line,
                ),
              ),
      ),
    );
  }
}
