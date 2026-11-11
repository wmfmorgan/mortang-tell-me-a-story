part of 'story_reader_page.dart';

const _sectionRule = Divider(height: 1, color: Color(0xFFE7DECE));

/// Edit (when allowed), the story actions menu, and Close.
class _ReaderTrailing extends StatelessWidget {
  const _ReaderTrailing({
    required this.canEdit,
    required this.onEdit,
    required this.overflow,
  });

  final bool canEdit;
  final VoidCallback? onEdit;
  final Widget overflow;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canEdit)
          OutlinedButton.icon(
            key: const Key('story-edit'),
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          ),
        if (canEdit) const SizedBox(width: 12),
        overflow,
        IconButton(
          key: const Key('story-reader-close'),
          onPressed: () => popOrGoTimeline(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

/// Start a branch, set origin, delete. Hidden when it would be empty.
class _ReaderOverflow extends StatelessWidget {
  const _ReaderOverflow({
    required this.entries,
    required this.canDelete,
    required this.showStartTimeline,
    required this.onSelected,
  });

  final List<OriginMenuEntry> entries;
  final bool canDelete;
  final bool showStartTimeline;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty && !canDelete && !showStartTimeline) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<String>(
      key: const Key('reader-overflow'),
      tooltip: 'Story actions',
      onSelected: onSelected,
      itemBuilder: (context) => [
        if (showStartTimeline)
          const PopupMenuItem<String>(
            key: Key('reader-start-timeline'),
            value: 'start-timeline',
            child: Text('Add a family branch from this story'),
          ),
        for (final entry in entries)
          PopupMenuItem<String>(
            key: Key('set-origin-${entry.familyId}'),
            value: entry.familyId,
            child: Text(entry.label),
          ),
        if (canDelete)
          const PopupMenuItem<String>(
            key: Key('delete-story'),
            value: 'delete',
            child: Text('Delete story'),
          ),
      ],
    );
  }
}

class _ReaderBody extends StatelessWidget {
  const _ReaderBody({required this.host, required this.data});

  final _StoryReaderPageState host;
  final ReaderData data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReaderArticle(host: host, data: data),
            const SizedBox(height: 28),
            _sectionRule,
            const SizedBox(height: 20),
            _PhotosSection(host: host, data: data),
            const SizedBox(height: 28),
            _sectionRule,
            const SizedBox(height: 20),
            _PerspectivesSection(host: host, data: data),
            const SizedBox(height: 16),
            _sectionRule,
            const SizedBox(height: 20),
            _CommentsSection(host: host, data: data),
          ],
        ),
      ),
    );
  }
}

/// Headline, meta line, chips, hero photo and the article.
class _ReaderArticle extends StatelessWidget {
  const _ReaderArticle({required this.host, required this.data});

  final _StoryReaderPageState host;
  final ReaderData data;

  @override
  Widget build(BuildContext context) {
    final story = data.story;
    final rest = readerArticleBody(body: story.body);
    final headlineText = readerHeadline(title: story.title);
    final sorted = [...data.photos]..sort(comparePhotoOrder);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (headlineText.isNotEmpty) _Headline(text: headlineText),
        const SizedBox(height: 8),
        ReaderMetaLine(story: story, authorBytes: data.authorBytes),
        const SizedBox(height: 16),
        ReaderChipRow(
          story: story,
          tree: data.tree,
          people: data.people,
          place: data.place,
          currentUserId: host._currentUserId,
        ),
        if (sorted.isNotEmpty) ...[
          const SizedBox(height: 20),
          ReaderHeroPhoto(
            sorted: sorted,
            previews: data.previews,
            index: host._heroIndex,
            onStep: (delta) => host._stepHero(delta, sorted.length),
          ),
        ],
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 28),
          _ArticleText(text: rest),
        ],
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineMedium
          ?.copyWith(fontSize: 36, height: 1.15, fontWeight: FontWeight.w700),
    );
  }
}

class _ArticleText extends StatelessWidget {
  const _ArticleText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ReaderDropCapText(
          text: text,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(fontSize: 18, height: 1.55),
        ),
      ),
    );
  }
}

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({required this.host, required this.data});

  final _StoryReaderPageState host;
  final ReaderData data;

  @override
  Widget build(BuildContext context) {
    final uid = host._currentUserId;
    final canEditStory = _canEditStory(data, uid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ReaderSectionHeader(
          icon: Icons.photo_library_outlined,
          iconColor: albumTerracotta,
          title: 'Keepsake Photos',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 900 ? 4 : (width >= 560 ? 2 : 1);
            return PhotoStrip(
              photos: data.photos,
              previews: data.previews,
              onAdd: host._onAddPhoto,
              onRemove: host._onRemovePhoto,
              canRemove: (photo) =>
                  uid != null &&
                  (canEditStory || (data.canWrite && photo.uploaderId == uid)),
              onRetry: host._onRetryPhoto,
              uploadFailed: host._photoError,
              canAdd: data.canWrite && data.photos.length < maxPhotosPerStory,
              columns: columns,
              addLabel: 'Add photo',
              addHint: 'Up to $maxPhotosPerStory photos',
            );
          },
        ),
      ],
    );
  }
}

class _PerspectivesSection extends StatelessWidget {
  const _PerspectivesSection({required this.host, required this.data});

  final _StoryReaderPageState host;
  final ReaderData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReaderSectionHeader(
          icon: Icons.diversity_3_outlined,
          iconColor: albumSage,
          title: 'Perspectives',
          subtitle:
              'Contribute an alternate or additional telling of this story',
          trailing: data.canWrite
              ? ReaderAddButton(
                  label: 'Add perspective',
                  onPressed: host._openPerspective,
                )
              : null,
        ),
        if (data.perspectives.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final row in data.perspectives) ...[
            ReaderPerspectiveCard(
              row: row,
              canEdit: host._ownsNote(data, row.authorId),
              onEdit: () => host._openEditPerspective(row),
              onDelete: () => host._confirmDeletePerspective(row),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({required this.host, required this.data});

  final _StoryReaderPageState host;
  final ReaderData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CommentsHeader(host: host, data: data),
        const SizedBox(height: 12),
        for (final row in data.comments)
          CommentTile(
            comment: row,
            canDelete: row.canDelete,
            editing: host._editingCommentId == row.id,
            onEdit: host._ownsNote(data, row.authorId)
                ? () => host._startEditComment(row)
                : null,
            onDelete: () => host._deleteComment(row),
            onSave: (body) => host._saveComment(row, body),
            onCancelEdit: host._cancelEditComment,
            editFocus: host._editFocus,
          ),
        if (host._composingComment)
          KeyedSubtree(
            key: host._composerKey,
            child: CommentComposer(
              onPost: host._postComment,
              focusNode: host._composerFocus,
            ),
          ),
      ],
    );
  }
}

class _CommentsHeader extends StatelessWidget {
  const _CommentsHeader({required this.host, required this.data});

  final _StoryReaderPageState host;
  final ReaderData data;

  @override
  Widget build(BuildContext context) {
    final count = data.comments.length;
    return ReaderSectionHeader(
      icon: Icons.forum_outlined,
      iconColor: albumTerracotta,
      title: 'Comments',
      countLabel: count == 1 ? '1 note' : '$count notes',
      trailing: data.canWrite
          ? ReaderAddButton(
              label: 'Add comment',
              onPressed: host._openComposer,
              compact: true,
            )
          : null,
    );
  }
}
