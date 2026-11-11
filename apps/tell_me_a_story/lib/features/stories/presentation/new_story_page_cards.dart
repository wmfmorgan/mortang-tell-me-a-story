part of 'new_story_page.dart';

const _cardDecoration = BoxDecoration(
  color: Color(0xFFFFFFFF),
  borderRadius: BorderRadius.all(Radius.circular(20)),
  boxShadow: [
    BoxShadow(color: Color(0x142C2416), blurRadius: 24, offset: Offset(0, 10)),
  ],
);

class _CaptureActions extends StatelessWidget {
  const _CaptureActions({
    required this.editing,
    required this.autosaveLabel,
    required this.onSaveDraft,
    required this.onPrimary,
  });

  final bool editing;
  final String? autosaveLabel;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    final label = autosaveLabel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!editing && label != null) ...[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: albumInk.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (!editing)
          TextButton(onPressed: onSaveDraft, child: const Text('Save draft')),
        FilledButton(
          onPressed: onPrimary,
          style: FilledButton.styleFrom(
            backgroundColor: albumTerracotta,
            foregroundColor: albumParchment,
          ),
          child: Text(editing ? 'Save changes' : 'Publish story'),
        ),
        IconButton(
          key: const Key('story-capture-close'),
          onPressed: () => popOrGoTimeline(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _CaptureBody extends StatelessWidget {
  const _CaptureBody({
    required this.editing,
    required this.showPublishBanner,
    required this.story,
    required this.details,
  });

  final bool editing;
  final bool showPublishBanner;
  final Widget story;
  final Widget details;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AlbumColumn(
        maxWidth: 720,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (editing) ...[
                Text(
                  'Edit story',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
              ],
              if (showPublishBanner) ...[
                const Text('Finish the highlighted fields to publish.'),
                const SizedBox(height: 12),
              ],
              story,
              const SizedBox(height: _storyCardGap),
              details,
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightIfMissing extends StatelessWidget {
  const _HighlightIfMissing({required this.missing, required this.child});

  final bool missing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!missing) return child;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: albumTerracotta, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: child,
    );
  }
}

class _StoryColumn extends StatelessWidget {
  const _StoryColumn({
    required this.title,
    required this.body,
    required this.titleMissing,
    required this.bodyMissing,
    required this.onTextChanged,
    required this.photos,
  });

  final TextEditingController title;
  final TextEditingController body;
  final bool titleMissing;
  final bool bodyMissing;
  final ValueChanged<String> onTextChanged;
  final Widget photos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: _cardDecoration,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HighlightIfMissing(
                  missing: titleMissing,
                  child: _TitleField(
                    controller: title,
                    onChanged: onTextChanged,
                  ),
                ),
                const SizedBox(height: 8),
                _HighlightIfMissing(
                  missing: bodyMissing,
                  child: _BodyField(controller: body, onChanged: onTextChanged),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: _storyCardGap),
        photos,
      ],
    );
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium
        ?.copyWith(fontSize: 30, height: 1.2, fontWeight: FontWeight.w700);
    return TextField(
      key: const Key('story-title'),
      controller: controller,
      minLines: 1,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: albumTerracotta,
      onChanged: onChanged,
      style: style,
      decoration: InputDecoration(
        hintText: 'Give your memory a title...',
        hintStyle: style?.copyWith(color: albumInk.withValues(alpha: 0.38)),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: albumTerracotta),
        ),
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }
}

class _BodyField extends StatelessWidget {
  const _BodyField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(fontSize: 22, height: 1.55);
    return TextField(
      key: const Key('story-body'),
      controller: controller,
      minLines: 8,
      maxLines: null,
      cursorColor: albumTerracotta,
      onChanged: onChanged,
      style: style,
      decoration: InputDecoration(
        hintText: 'Write the story',
        hintStyle: style?.copyWith(color: albumInk.withValues(alpha: 0.38)),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _PhotosCard extends StatelessWidget {
  const _PhotosCard({
    required this.photos,
    required this.previews,
    required this.uploadFailed,
    required this.dated,
    required this.showTimeframeHint,
    required this.onAdd,
    required this.onRemove,
    required this.onToggleHero,
    required this.onRetry,
  });

  final List<Photo> photos;
  final Map<String, Uint8List> previews;
  final bool uploadFailed;
  final bool dated;
  final bool showTimeframeHint;
  final VoidCallback onAdd;
  final ValueChanged<Photo> onRemove;
  final ValueChanged<Photo> onToggleHero;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _cardDecoration,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PhotosHeader(count: photos.length),
            const SizedBox(height: 14),
            PhotoStrip(
              photos: photos,
              previews: previews,
              onAdd: onAdd,
              onRemove: onRemove,
              onToggleHero: onToggleHero,
              onRetry: onRetry,
              uploadFailed: uploadFailed,
              canAdd: photos.length < maxPhotosPerStory,
              columns: 3,
              addLabel: 'Add photo',
              addHint: 'Up to $maxPhotosPerStory photos',
              addEnabled: dated,
            ),
            if (showTimeframeHint) ...[
              const SizedBox(height: 8),
              Text(
                'A Timeframe is required before adding a photo.',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: albumTerracotta),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotosHeader extends StatelessWidget {
  const _PhotosHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        const Icon(
          Icons.photo_library_outlined,
          color: albumTerracotta,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Photos & Keepsakes',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '$count of $maxPhotosPerStory added',
          style: textTheme.labelSmall?.copyWith(
            color: albumInk.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _ContextColumn extends StatelessWidget {
  const _ContextColumn({
    required this.timeframeMissing,
    required this.peopleMissing,
    required this.placeMissing,
    required this.timeframe,
    required this.people,
    required this.place,
  });

  final bool timeframeMissing;
  final bool peopleMissing;
  final bool placeMissing;
  final Widget timeframe;
  final Widget people;
  final Widget place;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HighlightIfMissing(
          missing: timeframeMissing,
          child: _PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timeframe',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                timeframe,
              ],
            ),
          ),
        ),
        _HighlightIfMissing(
          missing: peopleMissing,
          child: _PaperCard(child: people),
        ),
        _HighlightIfMissing(
          missing: placeMissing,
          child: _PaperCard(child: place),
        ),
      ],
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _storyCardGap),
      child: DecoratedBox(
        decoration: _cardDecoration,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: child,
        ),
      ),
    );
  }
}

class _PeopleCardBody extends StatelessWidget {
  const _PeopleCardBody({
    required this.people,
    required this.canRemove,
    required this.onRemove,
    required this.onAdd,
  });

  final List<Person> people;
  final bool canRemove;
  final ValueChanged<Person> onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('People', style: textTheme.titleSmall)),
            Text('${people.length}', style: textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final person in people)
              PersonNamePill(
                personId: person.id,
                name: person.name,
                child: Chip(
                  label: Text(person.name),
                  labelStyle: textTheme.titleMedium,
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  onDeleted: canRemove ? () => onRemove(person) : null,
                ),
              ),
            TextButton(
              onPressed: onAdd,
              child: const PlusLabel(label: 'Add person'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlaceCardBody extends StatelessWidget {
  const _PlaceCardBody({
    required this.place,
    required this.mapFailed,
    required this.mapBuilder,
    required this.onRetryMap,
    required this.onMapFailed,
    required this.onChoose,
  });

  final Place? place;
  final bool mapFailed;
  final PlaceMapBuilder? mapBuilder;
  final VoidCallback onRetryMap;
  final VoidCallback onMapFailed;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final selected = place;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Place', style: textTheme.titleSmall),
        if (selected != null) ...[
          const SizedBox(height: 8),
          Text(selected.label, style: textTheme.titleSmall),
          Text(selected.address, style: textTheme.bodySmall),
          const SizedBox(height: 8),
          _SelectedPlaceMap(
            place: selected,
            failed: mapFailed,
            mapBuilder: mapBuilder,
            onRetry: onRetryMap,
            onFailed: onMapFailed,
          ),
        ],
        TextButton(onPressed: onChoose, child: const Text('Choose place')),
      ],
    );
  }
}

class _SelectedPlaceMap extends StatelessWidget {
  const _SelectedPlaceMap({
    required this.place,
    required this.failed,
    required this.mapBuilder,
    required this.onRetry,
    required this.onFailed,
  });

  final Place place;
  final bool failed;
  final PlaceMapBuilder? mapBuilder;
  final VoidCallback onRetry;
  final VoidCallback onFailed;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(placeMapFailureCopy),
          TextButton(onPressed: onRetry, child: const Text(placeMapRetryLabel)),
        ],
      );
    }
    final builder = mapBuilder;
    if (builder != null) return builder(lat: place.lat, lng: place.lng);
    return PlaceMap(
      lat: place.lat,
      lng: place.lng,
      height: 200,
      onTileError: (error, stackTrace) => onFailed(),
    );
  }
}
