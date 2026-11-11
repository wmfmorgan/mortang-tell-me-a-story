import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';

class OriginBanner extends StatelessWidget {
  const OriginBanner({
    super.key,
    required this.familyName,
    required this.parentName,
    required this.onChoose,
    required this.onClose,
  });

  final String familyName;
  final String? parentName;
  final VoidCallback onChoose;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _outerPadding,
      child: DecoratedBox(
        key: const Key('timeline-origin-banner'),
        decoration: ShapeDecoration(
          color: albumParchment,
          shape: albumContainerShape(
            AlbumRadius.card,
            side: const BorderSide(color: albumSageLine),
          ),
        ),
        child: Padding(
          padding: _innerPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OriginMessage(
                  familyName: familyName,
                  parentName: parentName,
                  onChoose: onChoose,
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
                color: albumInk,
                tooltip: 'Close',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _outerPadding = EdgeInsets.fromLTRB(
  AlbumSpace.xl,
  AlbumSpace.l,
  AlbumSpace.xl,
  0,
);

const _innerPadding = EdgeInsets.fromLTRB(
  AlbumSpace.l,
  AlbumSpace.m,
  AlbumSpace.s,
  AlbumSpace.m,
);

/// The banner's prompt and, when there is a parent family, its button.
class _OriginMessage extends StatelessWidget {
  const _OriginMessage({
    required this.familyName,
    required this.parentName,
    required this.onChoose,
  });

  final String familyName;
  final String? parentName;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final parent = parentName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Every timeline starts with a story. Set the origin story for $familyName.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: albumInk, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AlbumSpace.s),
        if (parent != null)
          FButton(
            key: const Key('timeline-origin-choose'),
            variant: FButtonVariant.primary,
            mainAxisSize: MainAxisSize.min,
            onPress: onChoose,
            child: Text('Choose from $parent'),
          )
        else
          Text(
            'Open one of your stories and choose Set as origin for $familyName.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: albumInk),
          ),
      ],
    );
  }
}
