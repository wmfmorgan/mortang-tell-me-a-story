part of 'album_header.dart';

class _FamilyMenu extends StatelessWidget {
  const _FamilyMenu({required this.header, required this.active});

  static const _treeValue = 'family-tree';
  static const _inviteValue = 'invite';
  static const _timelineValue = 'start-timeline';
  static const _manageValue = 'manage-families';

  final AlbumHeader header;
  final bool active;

  AlbumHeaderPage get _page => header.page;

  bool get _showInvite => _page != AlbumHeaderPage.capture && header.canWrite;

  /// Hidden where Invite is always hidden (capture) and on the tree page.
  bool get _showTree =>
      header.currentFamilyId != null &&
      _page != AlbumHeaderPage.capture &&
      _page != AlbumHeaderPage.familyTree;

  String? _nameFor(String id) {
    for (final family in header.families) {
      if (family.id == id) return family.name;
    }
    return null;
  }

  Future<void> _pickFamily(BuildContext context, String value) async {
    final switching = value != header.currentFamilyId;
    if (switching) {
      final leave = await _confirmFamilySwitch(context, _nameFor(value));
      if (!leave || !context.mounted) return;
      header.onFamilySelected(value);
    }
    final router = GoRouter.maybeOf(context);
    switch (_page) {
      case AlbumHeaderPage.timeline:
        return;
      case AlbumHeaderPage.familyTree:
        if (switching) router?.go(AppRoutes.familyTreePath(value));
        return;
      case AlbumHeaderPage.allStories:
        if (switching) router?.go(AppRoutes.allStoriesPath(value));
        return;
      case AlbumHeaderPage.familyLanding:
        return;
      default:
        router?.go(AppRoutes.familyLanding);
    }
  }

  List<PopupMenuEntry<String>> _menuItems() {
    return [
      ..._familyItems(),
      PopupMenuDivider(
        key: const Key('family-menu-divider'),
        height: 1,
        thickness: 1,
        color: albumSage.withValues(alpha: 0.3),
      ),
      ..._actionItems(),
    ];
  }

  List<PopupMenuEntry<String>> _familyItems() {
    final rows = nestFamilies(header.families);
    final lastId = rows.isEmpty ? null : rows.last.family.id;
    return [
      for (final row in rows)
        PopupMenuItem<String>(
          key: Key('family-menu-item-${row.family.id}'),
          value: row.family.id,
          child: _FamilyRow(
            row: row,
            current: row.family.id == header.currentFamilyId,
            last: row.family.id == lastId,
          ),
        ),
    ];
  }

  List<PopupMenuEntry<String>> _actionItems() {
    final inviteLabel = 'Invite a family member to ${header.familyName}';
    final branchLabel = 'Add a family branch to ${header.familyName}';
    return [
      if (_showTree)
        const PopupMenuItem<String>(
          key: Key('family-menu-tree'),
          value: _treeValue,
          child: _FamilyActionRow(
            icon: Icons.forest_outlined,
            label: 'See the whole family tree',
          ),
        ),
      if (_showInvite)
        _tooltipItem(
          'family-menu-invite',
          _inviteValue,
          inviteLabel,
          Icons.person_add_outlined,
        ),
      if (header.onStartTimeline != null)
        _tooltipItem(
          'family-menu-start-timeline',
          _timelineValue,
          branchLabel,
          Icons.account_tree_outlined,
        ),
      const PopupMenuItem<String>(
        key: Key('family-menu-manage'),
        value: _manageValue,
        child: _FamilyActionRow(
          icon: Icons.group_outlined,
          label: 'Manage families',
        ),
      ),
    ];
  }

  Future<String?> _showFamilyMenu(
    BuildContext context,
    BoxConstraints menuConstraints,
  ) {
    final box = context.findRenderObject() as RenderBox;
    final overlay =
        // The header always sits under a Navigator, so its overlay exists.
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    return showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      color: albumDialogSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: albumModalBorder),
      ),
      constraints: menuConstraints,
      items: _menuItems(),
    );
  }

  Future<void> _openMenu(
    BuildContext context,
    BoxConstraints menuConstraints,
  ) async {
    final selected = await _showFamilyMenu(context, menuConstraints);
    if (selected == null || !context.mounted) return;
    switch (selected) {
      case _treeValue:
        final familyId = header.currentFamilyId;
        if (familyId != null) {
          GoRouter.of(context).go(AppRoutes.familyTreePath(familyId));
        }
      case _inviteValue:
        header.onInvite?.call();
      case _timelineValue:
        header.onStartTimeline?.call();
      case _manageValue:
        GoRouter.of(context).go(AppRoutes.manageFamilies);
      default:
        unawaited(_pickFamily(context, selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.newsreader(
      color: albumInk,
      fontSize: 18,
      fontWeight: FontWeight.w500,
    );
    final width = MediaQuery.sizeOf(context).width;
    final menuConstraints = width < 640
        ? BoxConstraints.tightFor(width: width - 32)
        : const BoxConstraints(maxWidth: 320);
    return Align(
      alignment: Alignment.centerLeft,
      child: Builder(
        builder: (buttonContext) {
          return Tooltip(
            message: header.familyName,
            child: GestureDetector(
              key: const Key('family-menu'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                unawaited(_openMenu(buttonContext, menuConstraints));
              },
              child: _ClosedFamilyLabel(
                familyName: header.familyName,
                style: style,
                active: active,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A menu action whose full label shows in a tooltip.
PopupMenuItem<String> _tooltipItem(
  String key,
  String value,
  String label,
  IconData icon,
) {
  return PopupMenuItem<String>(
    key: Key(key),
    value: value,
    child: Tooltip(
      message: label,
      child: _FamilyActionRow(icon: icon, label: label),
    ),
  );
}

/// One family in the open menu: guide, check, monogram, and name.
class _FamilyRow extends StatelessWidget {
  const _FamilyRow({
    required this.row,
    required this.current,
    required this.last,
  });

  final FamilyMenuRow row;
  final bool current;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final family = row.family;
    return Row(
      children: [
        FamilyIndentGuide(depth: row.depth, height: 48, stopShort: last),
        SizedBox(
          width: 24,
          child: current
              ? const Icon(Icons.check, size: 16, color: albumTerracotta)
              : null,
        ),
        FamilyMonogram(
          key: Key('family-monogram-${family.id}'),
          name: family.name,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            family.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: current
                ? const TextStyle(fontWeight: FontWeight.w500)
                : null,
          ),
        ),
      ],
    );
  }
}

class _FamilyActionRow extends StatelessWidget {
  const _FamilyActionRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: albumSage),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sourceSans3(
              color: albumInk,
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.15,
            ),
          ),
        ),
      ],
    );
  }
}

/// Name and chevron only. No Material or ink surface, so the closed
/// control blends into the parchment header.
class _ClosedFamilyLabel extends StatelessWidget {
  const _ClosedFamilyLabel({
    required this.familyName,
    required this.style,
    required this.active,
  });

  final String familyName;
  final TextStyle style;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) => _ClosedFamilyBody(
          familyName: familyName,
          style: style,
          active: active,
          inner: constraints.maxWidth,
        ),
      ),
    );
  }
}

class _ClosedFamilyBody extends StatelessWidget {
  const _ClosedFamilyBody({
    required this.familyName,
    required this.style,
    required this.active,
    required this.inner,
  });

  static const _iconGap = 4.0;
  static const _iconSize = 18.0;

  final String familyName;
  final TextStyle style;
  final bool active;
  final double inner;

  @override
  Widget build(BuildContext context) {
    final bounded = inner.isFinite;
    final showIcon = !bounded || inner >= _iconGap + _iconSize;
    final room = !bounded
        ? double.infinity
        : (showIcon ? inner - _iconGap - _iconSize : inner);
    final textMax = room > 0 ? room : 0.0;
    final painter = TextPainter(
      text: TextSpan(text: familyName, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: textMax);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomLeft,
      children: [
        _ClosedFamilyRow(
          familyName: familyName,
          style: style,
          textMax: textMax,
          showIcon: showIcon,
        ),
        Positioned(
          left: 12,
          bottom: -8,
          child: _Underline(
            underlineKey: const Key('header-underline-family'),
            width: painter.width,
            active: active,
          ),
        ),
      ],
    );
  }
}

class _ClosedFamilyRow extends StatelessWidget {
  const _ClosedFamilyRow({
    required this.familyName,
    required this.style,
    required this.textMax,
    required this.showIcon,
  });

  final String familyName;
  final TextStyle style;
  final double textMax;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: textMax),
          child: Semantics(
            label: familyName,
            excludeSemantics: true,
            child: Text(
              familyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ),
        if (showIcon) ...[
          const SizedBox(width: _ClosedFamilyBody._iconGap),
          Icon(
            Icons.expand_more,
            size: _ClosedFamilyBody._iconSize,
            color: albumInk.withValues(alpha: 0.7),
          ),
        ],
      ],
    );
  }
}
