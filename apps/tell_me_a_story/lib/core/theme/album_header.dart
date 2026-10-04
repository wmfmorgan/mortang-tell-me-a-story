import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/families_api.dart';
import '../router/app_router.dart';
import 'album_theme.dart';

/// Which signed-in screen is showing the shared bar.
enum AlbumHeaderPage { timeline, drafts, capture }

/// Stitch screen `703158c2c064414883d9d1c1dff8902a` header only.
class AlbumHeader extends StatelessWidget implements PreferredSizeWidget {
  const AlbumHeader({
    super.key,
    required this.page,
    required this.familyName,
    required this.families,
    required this.currentFamilyId,
    required this.onFamilySelected,
    this.onInvite,
    this.onSaveDraft,
    this.onPublish,
  });

  final AlbumHeaderPage page;
  final String familyName;
  final List<MemberFamily> families;
  final String? currentFamilyId;
  final ValueChanged<String> onFamilySelected;
  final VoidCallback? onInvite;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onPublish;

  static const height = 72.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: albumParchment,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: albumInk.withValues(alpha: 0.15)),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Wide enough for the unscaled controls, including the fallback
            // font tests use when Newsreader is not fetched. FittedBox scales
            // this down to the viewport.
            final width = constraints.maxWidth < 1800
                ? 1800.0
                : constraints.maxWidth;
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: width,
                height: height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      const _Wordmark(),
                      const SizedBox(width: 16),
                      Container(
                        width: 1,
                        height: 20,
                        color: albumInk.withValues(alpha: 0.15),
                      ),
                      const SizedBox(width: 12),
                      _FamilyMenu(
                        familyName: familyName,
                        families: families,
                        currentFamilyId: currentFamilyId,
                        onSelected: onFamilySelected,
                      ),
                      const SizedBox(width: 20),
                      _NavItem(
                        key: const Key('timeline-nav'),
                        label: 'Timeline',
                        active: page == AlbumHeaderPage.timeline,
                        underlineKey: const Key('header-underline-timeline'),
                        onTap: () => _openTimeline(context),
                      ),
                      const SizedBox(width: 18),
                      _NavItem(
                        key: const Key('drafts-nav'),
                        label: 'Drafts',
                        active: page == AlbumHeaderPage.drafts,
                        underlineKey: const Key('header-underline-drafts'),
                        onTap: () => _openDrafts(context),
                      ),
                      const SizedBox(width: 16),
                      const _SearchChip(),
                      const Spacer(),
                      if (page == AlbumHeaderPage.capture) ...[
                        TextButton(
                          onPressed: onSaveDraft,
                          child: Text(
                            'Save draft',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: onPublish,
                          style: FilledButton.styleFrom(
                            backgroundColor: albumTerracotta,
                            foregroundColor: albumParchment,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Publish story'),
                        ),
                      ] else ...[
                        TextButton(
                          key: const Key('header-invite'),
                          onPressed: onInvite,
                          style: TextButton.styleFrom(
                            foregroundColor: albumInk.withValues(alpha: 0.8),
                            textStyle: GoogleFonts.sourceSans3(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: const Text('Invite'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _openNewStory(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: albumTerracotta,
                            foregroundColor: albumParchment,
                            elevation: 1,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 17),
                          label: Text(
                            'New story',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openTimeline(BuildContext context) {
    if (page == AlbumHeaderPage.timeline) return;
    GoRouter.of(context).go(AppRoutes.timeline);
  }

  void _openDrafts(BuildContext context) {
    if (page == AlbumHeaderPage.drafts) return;
    GoRouter.of(context).push(AppRoutes.drafts);
  }

  void _openNewStory(BuildContext context) {
    GoRouter.of(context).push(AppRoutes.newStory);
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Tell Me a Story',
      style: GoogleFonts.newsreader(
        color: albumInk,
        fontSize: 24,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _FamilyMenu extends StatelessWidget {
  const _FamilyMenu({
    required this.familyName,
    required this.families,
    required this.currentFamilyId,
    required this.onSelected,
  });

  final String familyName;
  final List<MemberFamily> families;
  final String? currentFamilyId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('family-menu'),
      tooltip: familyName,
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (context) {
        return [
          for (final family in families)
            PopupMenuItem<String>(
              value: family.id,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: family.id == currentFamilyId
                        ? const Icon(Icons.check, size: 16)
                        : null,
                  ),
                  Flexible(child: Text(family.name)),
                ],
              ),
            ),
        ];
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              familyName,
              style: GoogleFonts.newsreader(
                color: albumInk,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 18,
              color: albumInk.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.label,
    required this.active,
    required this.underlineKey,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Key underlineKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.sourceSans3(
      color: albumInk.withValues(alpha: active ? 1 : 0.7),
      fontSize: 15,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
    );
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: style),
            const SizedBox(height: 6),
            Container(
              key: active ? underlineKey : null,
              width: painter.width,
              height: 2,
              decoration: BoxDecoration(
                color: active ? albumInk : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchChip extends StatelessWidget {
  const _SearchChip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 224,
      child: Material(
        color: albumInk.withValues(alpha: 0.04),
        shape: StadiumBorder(
          side: BorderSide(color: albumInk.withValues(alpha: 0.10)),
        ),
        child: InkWell(
          key: const Key('timeline-search'),
          customBorder: const StadiumBorder(),
          onTap: () => GoRouter.of(context).push(AppRoutes.search),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 18,
                  color: albumInk.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search archive...',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sourceSans3(
                      color: albumInk.withValues(alpha: 0.5),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
