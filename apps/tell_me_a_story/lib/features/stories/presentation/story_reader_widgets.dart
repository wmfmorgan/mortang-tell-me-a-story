part of 'story_reader_page.dart';

/// `Recorded event: … · Documented … by …` with the author's avatar.
class ReaderMetaLine extends StatelessWidget {
  const ReaderMetaLine({super.key, required this.story, this.authorBytes});

  final Story story;
  final Uint8List? authorBytes;

  @override
  Widget build(BuildContext context) {
    final documented = switch (story.publishedAt) {
      null => '',
      final DateTime at =>
        ' · Documented ${albumMonthYear(at)} by ${displayNameOrMember(story.authorDisplayName)}',
    };
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: const Color(0xFF6B5E55));
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: 'Recorded event: ${storyDateLabelFor(story)}$documented ',
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ProfileAvatar(
              size: 20,
              displayName: story.authorDisplayName,
              bytes: authorBytes,
            ),
          ),
        ],
      ),
    );
  }
}

/// Origin pill, branch pills, story people, then the place.
class ReaderChipRow extends StatelessWidget {
  const ReaderChipRow({
    super.key,
    required this.story,
    required this.tree,
    required this.people,
    this.place,
    this.currentUserId,
  });

  final Story story;
  final List<TreeFamily> tree;
  final List<Person> people;
  final Place? place;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final placeText = switch (place) {
      null => null,
      Place(:final label, :final address) => placeChipText(
        label: label,
        address: address,
      ),
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (tree.any((row) => row.originStoryId == story.id))
          const ReaderLabelPill(
            'Origin',
            key: Key('story-origin-pill'),
            icon: Icons.account_tree_outlined,
            color: albumSage,
          ),
        for (final branch in _branchesFor(story, tree))
          ReaderLabelPill(
            branch.name,
            key: Key('story-branch-${branch.id}'),
            icon: Icons.account_tree_outlined,
          ),
        for (final person in people)
          ReaderPersonChip(person: person, currentUserId: currentUserId),
        if (placeText != null) ReaderTimeframePill(label: placeText),
      ],
    );
  }
}

/// The story's own family, then each branch that starts at this story.
List<TreeFamily> _branchesFor(Story story, List<TreeFamily> tree) {
  final rows = [
    for (final row in tree)
      if (row.id == story.familyId || row.originStoryId == story.id) row,
  ];
  rows.sort((a, b) {
    if (a.id == story.familyId) return -1;
    if (b.id == story.familyId) return 1;
    final name = a.name.compareTo(b.name);
    if (name != 0) return name;
    return a.id.compareTo(b.id);
  });
  return rows;
}

class ReaderLabelPill extends StatelessWidget {
  const ReaderLabelPill(
    this.label, {
    required Key super.key,
    required this.icon,
    this.color = albumInk,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumPillFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: albumPillBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class ReaderTimeframePill extends StatelessWidget {
  const ReaderTimeframePill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDE6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: albumTerracotta),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class ReaderPersonChip extends StatelessWidget {
  const ReaderPersonChip({super.key, required this.person, this.currentUserId});

  final Person person;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return PersonNamePill(
      personId: person.id,
      name: person.name,
      signedInUserId: currentUserId,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF6F1EB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE7DECE)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReaderInitialsAvatar(name: person.name, size: 22),
              const SizedBox(width: 6),
              Text(person.name, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class ReaderInitialsAvatar extends StatelessWidget {
  const ReaderInitialsAvatar({
    super.key,
    required this.name,
    required this.size,
  });

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFE7D5CC),
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            _initials(name),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: size < 28 ? 9 : 12,
              fontWeight: FontWeight.w700,
              color: albumTerracotta,
            ),
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.first;
    return (word.length == 1 ? word : word.substring(0, 2)).toUpperCase();
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// Article body with a large first letter.
class ReaderDropCapText extends StatelessWidget {
  const ReaderDropCapText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? const TextStyle(fontSize: 18, height: 1.5);
    final chars = text.characters;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(
            text: chars.first,
            style: base.copyWith(fontSize: 52, height: 0.8),
          ),
          TextSpan(text: chars.skip(1).string),
        ],
      ),
    );
  }
}

/// Hero photo; with two or more photos, a carousel stepped by buttons or a
/// horizontal swipe. [onStep] receives -1 or 1.
class ReaderHeroPhoto extends StatelessWidget {
  const ReaderHeroPhoto({
    super.key,
    required this.sorted,
    required this.previews,
    required this.index,
    required this.onStep,
  });

  static const _swipeVelocity = 200.0;

  /// Non-empty, in [comparePhotoOrder] order.
  final List<Photo> sorted;
  final Map<String, Uint8List> previews;
  final int index;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final photo = sorted[index.clamp(0, sorted.length - 1)];
    final bytes = previews[photo.id];
    final frame = FramedPhoto(
      key: Key('story-hero-${photo.id}'),
      bytes: bytes != null && bytes.isNotEmpty ? bytes : null,
    );
    if (sorted.length < 2) return frame;
    return GestureDetector(
      key: const Key('story-hero-carousel'),
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity <= -_swipeVelocity) onStep(1);
        if (velocity >= _swipeVelocity) onStep(-1);
      },
      child: _HeroStepOverlay(frame: frame, onStep: onStep),
    );
  }
}

/// [frame] with previous / next buttons centred on its edges.
class _HeroStepOverlay extends StatelessWidget {
  const _HeroStepOverlay({required this.frame, required this.onStep});

  final Widget frame;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        frame,
        Positioned(
          left: 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: _HeroStepButton(
              buttonKey: const Key('story-hero-prev'),
              icon: Icons.chevron_left,
              onPressed: () => onStep(-1),
            ),
          ),
        ),
        Positioned(
          right: 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: _HeroStepButton(
              buttonKey: const Key('story-hero-next'),
              icon: Icons.chevron_right,
              onPressed: () => onStep(1),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroStepButton extends StatelessWidget {
  const _HeroStepButton({
    required this.buttonKey,
    required this.icon,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: albumParchment,
      shape: const CircleBorder(),
      child: IconButton(
        key: buttonKey,
        onPressed: onPressed,
        icon: Icon(icon, color: albumInk),
      ),
    );
  }
}

/// Terracotta `+ label` pill. [compact] is the smaller Comments variant.
class ReaderAddButton extends StatelessWidget {
  const ReaderAddButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: albumTerracotta,
        foregroundColor: albumParchment,
        elevation: 1,
        minimumSize: compact ? const Size(0, 32) : null,
        tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
        visualDensity: compact ? VisualDensity.compact : null,
        shape: const StadiumBorder(),
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: PlusLabel(
        label: label,
        onTerracotta: true,
        size: compact ? 16 : 20,
        style: GoogleFonts.sourceSans3(
          fontSize: compact ? 13 : 14,
          fontWeight: FontWeight.w500,
          color: albumParchment,
        ),
      ),
    );
  }
}

/// Section title with icon, optional count badge and subtitle; [trailing]
/// sits right on wide layouts and below on narrow ones.
class ReaderSectionHeader extends StatelessWidget {
  const ReaderSectionHeader({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.countLabel,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? countLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleBlock = _SectionTitle(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      countLabel: countLabel,
    );
    final action = trailing;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              if (action != null) ...[const SizedBox(height: 8), action],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            ?action,
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.countLabel,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? countLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = countLabel;
    final sub = subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              _CountBadge(label: count),
            ],
          ],
        ),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(
            sub,
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF6B5E55),
            ),
          ),
        ],
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDE6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// One perspective: author, date, the telling, and its Edit/Delete menu.
class ReaderPerspectiveCard extends StatelessWidget {
  const ReaderPerspectiveCard({
    super.key,
    required this.row,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final Perspective row;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1EB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7DECE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PerspectiveHeader(
              row: row,
              canEdit: canEdit,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: albumTerracotta, width: 2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  row.body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerspectiveHeader extends StatelessWidget {
  const _PerspectiveHeader({
    required this.row,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final Perspective row;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReaderInitialsAvatar(name: row.authorLabel, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.authorLabel,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
              ),
              Text(
                'Recorded ${albumDate(row.createdAt)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF6B5E55),
                ),
              ),
            ],
          ),
        ),
        if (canEdit || row.canDelete)
          _PerspectiveMenu(
            row: row,
            canEdit: canEdit,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
      ],
    );
  }
}

class _PerspectiveMenu extends StatelessWidget {
  const _PerspectiveMenu({
    required this.row,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final Perspective row;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: Key('perspective-menu-${row.id}'),
      tooltip: 'Perspective actions',
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
          return;
        }
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        if (canEdit)
          PopupMenuItem<String>(
            key: Key('perspective-edit-${row.id}'),
            value: 'edit',
            child: const Text('Edit'),
          ),
        if (row.canDelete)
          PopupMenuItem<String>(
            key: Key('perspective-delete-${row.id}'),
            value: 'delete',
            child: const Text('Delete'),
          ),
      ],
    );
  }
}
