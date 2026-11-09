import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';

/// A pill chip: sage tint when selected, pale blush otherwise. Tappable
/// chips are at least [AlbumTarget.min] tall; static ones size to content.
class AlbumChip extends StatelessWidget {
  const AlbumChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.avatar,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Shown before the label.
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final avatar = this.avatar;
    final onTap = this.onTap;
    Widget chip = DecoratedBox(
      decoration: ShapeDecoration(
        color: selected ? albumSageTint : albumBlushPale,
        shape: const StadiumBorder(side: BorderSide(color: albumSageLine)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: onTap == null ? 0 : AlbumTarget.min,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AlbumSpace.m,
            vertical: AlbumSpace.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (avatar != null) ...[
                avatar,
                const SizedBox(width: AlbumSpace.s),
              ],
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
    if (onTap != null) {
      // FTappable reports button + selected to semantics itself.
      return FTappable(selected: selected, onPress: onTap, child: chip);
    }
    return Semantics(selected: selected, child: chip);
  }
}
