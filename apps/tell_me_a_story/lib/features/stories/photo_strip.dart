import 'package:flutter/material.dart';

import '../../data/photos_api.dart';

const photoUploadFailureCopy =
    'Couldn’t upload the photo. Check your connection and try again.';

const photoUploadRetryLabel = 'Try again';

/// Horizontal add / thumbnail / retry strip for story capture.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    required this.onRetry,
    required this.uploadFailed,
    required this.canAdd,
  });

  final List<Photo> photos;
  final VoidCallback onAdd;
  final ValueChanged<Photo> onRemove;
  final VoidCallback onRetry;
  final bool uploadFailed;
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (uploadFailed) ...[
          const Text(photoUploadFailureCopy),
          TextButton(
            onPressed: onRetry,
            child: const Text(photoUploadRetryLabel),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 88,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final photo in photos)
                  _Thumb(photo: photo, onRemove: onRemove),
                if (canAdd) _AddTile(onAdd: onAdd),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: const Key('photo-add'),
          onTap: onAdd,
          borderRadius: BorderRadius.circular(8),
          child: const SizedBox(
            width: 72,
            height: 72,
            child: Icon(Icons.add_a_photo_outlined),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo, required this.onRemove});

  final Photo photo;
  final ValueChanged<Photo> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        key: const Key('photo-thumb'),
        width: 72,
        height: 72,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_outlined),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                key: const Key('photo-remove'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                iconSize: 18,
                onPressed: () => onRemove(photo),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
