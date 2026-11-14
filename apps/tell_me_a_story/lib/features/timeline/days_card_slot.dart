import 'package:flutter/rendering.dart';

/// Layout facts for the story card, written by DaysCardProbe during its
/// own layout. The row reads these fields instead of a descendant's size.
class DaysCardSlot {
  Size layoutSize = Size.zero;
  double scale = 1;
  RenderBox? box;
}
