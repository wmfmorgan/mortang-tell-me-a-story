part of 'album_header.dart';

class _HeaderBar extends ConsumerWidget {
  const _HeaderBar({
    required this.header,
    required this.onHome,
    required this.onTimeline,
    required this.onStories,
    required this.onDrafts,
    required this.onNewStory,
    required this.metrics,
  });

  final AlbumHeader header;
  final VoidCallback onHome;
  final VoidCallback onTimeline;
  final VoidCallback onStories;
  final VoidCallback onDrafts;
  final VoidCallback onNewStory;
  final _HeaderMetrics metrics;

  /// Even gap between search, New story, and the avatar (UX Q5).
  static const _clusterGap = 12.0;

  /// Unscaled gaps for the bar [Row], in child order: wordmark, hairline,
  /// family, Home, Stories, Timeline, Drafts. [fit] may scale these.
  static const barGaps = <double>[16, 12, 20, 8, 14, 14, 12];

  /// Show New story on the first frame. Hide it only after membership has
  /// loaded and this family is not one the caller can write in.
  bool _showNewStory(WidgetRef ref) {
    if (header.canWrite) return true;
    final membership = ref.watch(familyMembershipProvider);
    final id = header.currentFamilyId ?? ref.watch(familySelectionProvider);
    if (!membership.known) return true;
    if (id == null) return membership.ids.isNotEmpty;
    return membership.ids.contains(id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = header.page;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.pad),
      child: Row(
        mainAxisSize: metrics.loose ? MainAxisSize.min : MainAxisSize.max,
        children: [
          ..._headerLeading(header, metrics),
          ..._headerNav(this),
          ..._headerCluster(header, metrics, onNewStory, _showNewStory(ref)),
          _HeaderAvatar(page: page, onLogout: header.onLogout),
        ],
      ),
    );
  }
}

/// Search, then capture actions or New story, before the avatar.
List<Widget> _headerCluster(
  AlbumHeader header,
  _HeaderMetrics metrics,
  VoidCallback onNewStory,
  bool showNewStory,
) {
  if (header.page == AlbumHeaderPage.capture) {
    return [
      const SizedBox(width: 40, height: 40, child: _SearchButton()),
      _CaptureActions(header: header, loose: metrics.loose),
      const SizedBox(width: 12),
    ];
  }
  return [
    const _SearchButton(),
    const SizedBox(width: _HeaderBar._clusterGap),
    if (showNewStory) ...[
      _NewStoryButton(onPressed: onNewStory),
      const SizedBox(width: _HeaderBar._clusterGap),
    ],
  ];
}

/// Wordmark, hairline, and the family menu slot. A list, not a widget, so
/// the family slot can stay a [Flexible] child of the bar row.
List<Widget> _headerLeading(AlbumHeader header, _HeaderMetrics metrics) {
  return [
    SizedBox(width: metrics.word, child: const _Wordmark()),
    SizedBox(width: metrics.gaps[0]),
    Container(width: 1, height: 20, color: albumInk.withValues(alpha: 0.15)),
    SizedBox(width: metrics.gaps[1]),
    _FamilySlot(
      metrics: metrics,
      child: _FamilyMenu(
        header: header,
        active: header.page == AlbumHeaderPage.manageFamilies,
      ),
    ),
    SizedBox(width: metrics.gaps[2]),
  ];
}

/// Home and the three nav labels.
List<Widget> _headerNav(_HeaderBar bar) {
  final page = bar.header.page;
  final gaps = bar.metrics.gaps;
  return [
    _HomeNav(onTap: bar.onHome),
    SizedBox(width: gaps[3]),
    _NavItem(
      key: const Key('header-nav-stories'),
      label: 'Stories',
      active: page == AlbumHeaderPage.allStories,
      underlineKey: const Key('header-underline-stories'),
      onTap: bar.onStories,
    ),
    SizedBox(width: gaps[4]),
    _NavItem(
      key: const Key('header-nav-timeline'),
      label: 'Timeline',
      active: page == AlbumHeaderPage.timeline,
      underlineKey: const Key('header-underline-timeline'),
      onTap: bar.onTimeline,
    ),
    SizedBox(width: gaps[5]),
    _NavItem(
      key: const Key('drafts-nav'),
      label: 'Draft Stories',
      active: page == AlbumHeaderPage.drafts,
      underlineKey: const Key('header-underline-drafts'),
      onTap: bar.onDrafts,
    ),
    SizedBox(width: gaps[6]),
  ];
}

/// Loose bars keep a text-sized slot so [FittedBox] can scale them.
/// Fitted bars give the name the leftover width left of the right cluster.
class _FamilySlot extends StatelessWidget {
  const _FamilySlot({required this.metrics, required this.child});

  final _HeaderMetrics metrics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (metrics.loose) {
      return SizedBox(width: metrics.family, child: child);
    }
    return Flexible(child: child);
  }
}

class _NewStoryButton extends StatelessWidget {
  const _NewStoryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => onPressed(),
      style: FilledButton.styleFrom(
        backgroundColor: albumTerracotta,
        foregroundColor: albumParchment,
        elevation: 1,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: PlusLabel(
        label: 'New story',
        onTerracotta: true,
        style: GoogleFonts.sourceSans3(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: albumParchment,
        ),
      ),
    );
  }
}

/// Status, Save draft, and Publish on the capture bar.
class _CaptureActions extends StatelessWidget {
  const _CaptureActions({required this.header, required this.loose});

  final AlbumHeader header;
  final bool loose;

  @override
  Widget build(BuildContext context) {
    final actions = _CaptureButtons(header: header);
    if (loose) return actions;
    // The capture bar is already at its shrink floor on an 800px window.
    // Scale the buttons instead of overflowing when Saved or Not saved appears.
    return Flexible(
      child: Align(
        alignment: Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: actions,
        ),
      ),
    );
  }
}

class _CaptureButtons extends StatelessWidget {
  const _CaptureButtons({required this.header});

  final AlbumHeader header;

  @override
  Widget build(BuildContext context) {
    final status = header.captureStatus;
    final label = GoogleFonts.sourceSans3(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status != null) ...[
          Text(
            status,
            style: label.copyWith(color: albumInk.withValues(alpha: 0.55)),
          ),
          const SizedBox(width: 12),
        ],
        TextButton(
          onPressed: header.onSaveDraft,
          style: TextButton.styleFrom(
            foregroundColor: albumInk,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            side: BorderSide(color: albumInk.withValues(alpha: 0.3)),
            shape: const StadiumBorder(),
            textStyle: label,
          ),
          child: Text(header.captureSecondaryLabel),
        ),
        const SizedBox(width: 12),
        _PublishButton(header: header, textStyle: label),
      ],
    );
  }
}

class _PublishButton extends StatelessWidget {
  const _PublishButton({required this.header, required this.textStyle});

  final AlbumHeader header;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: header.onPublish,
      style: FilledButton.styleFrom(
        backgroundColor: albumTerracotta,
        foregroundColor: albumOnAccent,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: const StadiumBorder(),
        textStyle: textStyle,
      ),
      child: Text(header.capturePrimaryLabel),
    );
  }
}
