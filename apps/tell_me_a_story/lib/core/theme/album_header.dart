import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/manage_families_api.dart';
import '../../data/profile_session.dart';
import '../../features/family/family_role.dart';
import '../../features/family/start_family_dialog.dart';
import '../router/app_router.dart';
import 'album_theme.dart';
import 'profile_avatar.dart';

/// Which signed-in screen is showing the shared bar.
enum AlbumHeaderPage { timeline, drafts, capture, settings, manageFamilies }

/// Stitch screen `703158c2c064414883d9d1c1dff8902a` header only.
class AlbumHeader extends StatelessWidget implements PreferredSizeWidget {
  const AlbumHeader({
    super.key,
    required this.page,
    required this.familyName,
    required this.families,
    required this.currentFamilyId,
    required this.onFamilySelected,
    this.stewarded = const [],
    this.manageApi,
    this.onInvite,
    this.onSaveDraft,
    this.onPublish,
    this.onLogout,
  });

  final AlbumHeaderPage page;
  final String familyName;
  final List<MemberFamily> families;
  final String? currentFamilyId;
  final ValueChanged<String> onFamilySelected;
  final List<StewardFamily> stewarded;
  final ManageFamiliesGateway? manageApi;
  final VoidCallback? onInvite;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onPublish;
  final Future<void> Function()? onLogout;

  static const height = 72.0;

  /// Viewports this narrow scale the whole bar. Wider ones use the real width.
  static const _scaleAt = 320.0;

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
            final width = constraints.maxWidth;
            final natural = _HeaderMetrics.of(
              page: page,
              familyName: familyName,
            );
            final bar = _HeaderBar(
              page: page,
              familyName: familyName,
              families: families,
              currentFamilyId: currentFamilyId,
              onFamilySelected: onFamilySelected,
              stewarded: stewarded,
              manageApi: manageApi,
              onInvite: onInvite,
              onSaveDraft: onSaveDraft,
              onPublish: onPublish,
              onLogout: onLogout,
              onTimeline: () => _openTimeline(context),
              onDrafts: () => _openDrafts(context),
              onNewStory: () => _openNewStory(context),
              metrics: width <= _scaleAt ? natural : natural.fit(width),
            );
            if (width <= _scaleAt) {
              return SizedBox(
                width: width,
                height: height,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: bar,
                ),
              );
            }
            return SizedBox(width: width, height: height, child: bar);
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

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.page,
    required this.familyName,
    required this.families,
    required this.currentFamilyId,
    required this.onFamilySelected,
    required this.stewarded,
    required this.manageApi,
    required this.onInvite,
    required this.onSaveDraft,
    required this.onPublish,
    required this.onLogout,
    required this.onTimeline,
    required this.onDrafts,
    required this.onNewStory,
    required this.metrics,
  });

  final AlbumHeaderPage page;
  final String familyName;
  final List<MemberFamily> families;
  final String? currentFamilyId;
  final ValueChanged<String> onFamilySelected;
  final List<StewardFamily> stewarded;
  final ManageFamiliesGateway? manageApi;
  final VoidCallback? onInvite;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onPublish;
  final Future<void> Function()? onLogout;
  final VoidCallback onTimeline;
  final VoidCallback onDrafts;
  final VoidCallback onNewStory;
  final _HeaderMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.pad),
      child: Row(
        mainAxisSize: metrics.loose ? MainAxisSize.min : MainAxisSize.max,
        children: [
          SizedBox(width: metrics.word, child: const _Wordmark()),
          SizedBox(width: metrics.gaps[0]),
          Container(
            width: 1,
            height: 20,
            color: albumInk.withValues(alpha: 0.15),
          ),
          SizedBox(width: metrics.gaps[1]),
          SizedBox(
            width: metrics.family,
            child: _FamilyMenu(
              familyName: familyName,
              families: families,
              currentFamilyId: currentFamilyId,
              onSelected: onFamilySelected,
              showManage: stewarded.any((family) => family.countsForManage()),
              manageApi: manageApi,
              active: page == AlbumHeaderPage.manageFamilies,
            ),
          ),
          SizedBox(width: metrics.gaps[2]),
          _NavItem(
            key: const Key('timeline-nav'),
            label: 'Timeline',
            active: page == AlbumHeaderPage.timeline,
            underlineKey: const Key('header-underline-timeline'),
            onTap: onTimeline,
          ),
          SizedBox(width: metrics.gaps[3]),
          _NavItem(
            key: const Key('drafts-nav'),
            label: 'Drafts',
            active: page == AlbumHeaderPage.drafts,
            underlineKey: const Key('header-underline-drafts'),
            onTap: onDrafts,
          ),
          SizedBox(width: metrics.gaps[4]),
          SizedBox(width: metrics.search, child: const _SearchChip()),
          if (!metrics.loose) const Spacer(),
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
              onPressed: () => onNewStory(),
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
          const SizedBox(width: 12),
          _HeaderAvatar(page: page, onLogout: onLogout),
        ],
      ),
    );
  }
}

/// Widths for one bar. [loose] is the unscaled row that [FittedBox] shrinks.
class _HeaderMetrics {
  const _HeaderMetrics({
    required this.page,
    required this.pad,
    required this.word,
    required this.family,
    required this.search,
    required this.gaps,
    required this.loose,
  });

  final AlbumHeaderPage page;
  final double pad;
  final double word;
  final double family;
  final double search;
  final List<double> gaps;
  final bool loose;

  static const _searchMax = 224.0;
  static const _searchMin = 54.0;
  static const _familyChrome = 47.5;
  static const _familyMin = 46.0;
  static const _padMax = 32.0;

  static _HeaderMetrics of({
    required AlbumHeaderPage page,
    required String familyName,
  }) {
    return _HeaderMetrics(
      page: page,
      pad: _padMax,
      word: _textWidth('Tell Me a Story', _wordStyle),
      family: _textWidth(familyName, _familyStyle) + _familyChrome,
      search: _searchMax,
      gaps: const [16, 12, 20, 18, 16],
      loose: true,
    );
  }

  /// Fits [viewport] by shrinking the search chip, then ellipsizing the
  /// wordmark, then the family name, then padding and gaps.
  _HeaderMetrics fit(double viewport) {
    var pad = this.pad;
    var word = this.word;
    var family = this.family;
    var search = this.search;
    var gaps = [...this.gaps];
    // Button chrome is a pixel or two wider than the text-plus-padding
    // estimate. Keep that slack in the budget so the row does not overflow.
    final rigid = _rigidWidth() + 4;

    double used() =>
        pad * 2 +
        word +
        family +
        search +
        rigid +
        gaps.fold(0, (a, b) => a + b);

    var overflow = used() - viewport;
    if (overflow > 0) {
      final cut = overflow < search - _searchMin
          ? overflow
          : search - _searchMin;
      if (cut > 0) {
        search -= cut;
        overflow -= cut;
      }
    }
    if (overflow > 0) {
      final cut = overflow < word ? overflow : word;
      word -= cut;
      overflow -= cut;
    }
    if (overflow > 0) {
      final room = family - _familyMin;
      final cut = overflow < room ? overflow : room;
      if (cut > 0) {
        family -= cut;
        overflow -= cut;
      }
    }
    if (overflow > 0 && pad > 0) {
      final cut = overflow / 2 < pad ? overflow / 2 : pad;
      pad -= cut;
      overflow -= cut * 2;
    }
    if (overflow > 0) {
      final sum = gaps.fold<double>(0, (a, b) => a + b);
      if (sum > 0) {
        final factor = sum > overflow ? (sum - overflow) / sum : 0.0;
        gaps = [for (final gap in gaps) gap * factor];
      }
    }
    return _HeaderMetrics(
      page: page,
      pad: pad,
      word: word,
      family: family,
      search: search,
      gaps: gaps,
      loose: false,
    );
  }

  double _rigidWidth() {
    // Hairline plus both nav labels and the action buttons. Those stay put
    // while the chip, wordmark, and family name absorb a narrow window.
    final timeline = _textWidth('Timeline', _navStyle) + 4;
    final drafts = _textWidth('Drafts', _navStyle) + 4;
    return 1 + timeline + drafts + _actionsWidth();
  }

  double _actionsWidth() {
    const between = 8.0;
    if (page == AlbumHeaderPage.capture) {
      // Keep this in sync with the capture buttons in [_HeaderBar].
      return _textWidth(
            'Save draft',
            GoogleFonts.sourceSans3(fontSize: 15, fontWeight: FontWeight.w500),
          ) +
          24 +
          between +
          _textWidth(
            'Publish story',
            GoogleFonts.sourceSans3(fontWeight: FontWeight.w600),
          ) +
          48 +
          _avatarSlot;
    }
    return _textWidth(
          'Invite',
          GoogleFonts.sourceSans3(fontSize: 15, fontWeight: FontWeight.w500),
        ) +
        24 +
        between +
        _textWidth(
          'New story',
          GoogleFonts.sourceSans3(fontSize: 14, fontWeight: FontWeight.w500),
        ) +
        57 +
        _avatarSlot;
  }

  /// Gap plus the 32px circle. Both action clusters end with the avatar.
  static const _avatarSlot = 44.0;

  static final TextStyle _wordStyle = GoogleFonts.newsreader(
    fontSize: 24,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
  );
  static final TextStyle _familyStyle = GoogleFonts.newsreader(
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  static final TextStyle _navStyle = GoogleFonts.sourceSans3(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );
}

double _textWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Tell Me a Story',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
    required this.showManage,
    required this.manageApi,
    required this.active,
  });

  static const _startValue = 'start-family';
  static const _manageValue = 'manage-families';

  final String familyName;
  final List<MemberFamily> families;
  final String? currentFamilyId;
  final ValueChanged<String> onSelected;
  final bool showManage;
  final ManageFamiliesGateway? manageApi;
  final bool active;

  Future<void> _start(BuildContext context) async {
    final id = await showStartFamilyDialog(
      context,
      api: manageApi ?? ManageFamiliesApi(),
    );
    if (id == null || !context.mounted) return;
    FamilySelection.remember(id);
    GoRouter.of(context).go(AppRoutes.timeline);
  }

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.newsreader(
      color: albumInk,
      fontSize: 18,
      fontWeight: FontWeight.w500,
    );
    final painter = TextPainter(
      text: TextSpan(text: familyName, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return PopupMenuButton<String>(
      key: const Key('family-menu'),
      tooltip: familyName,
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == _startValue) {
          _start(context);
          return;
        }
        if (value == _manageValue) {
          GoRouter.of(context).go(AppRoutes.manageFamilies);
          return;
        }
        onSelected(value);
      },
      itemBuilder: (context) {
        return [
          for (final family in families)
            PopupMenuItem<String>(
              key: Key('family-menu-item-${family.id}'),
              value: family.id,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: family.id == currentFamilyId
                        ? const Icon(Icons.check, size: 16)
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
                    ),
                  ),
                ],
              ),
            ),
          const PopupMenuDivider(key: Key('family-menu-divider')),
          const PopupMenuItem<String>(
            key: Key('family-menu-start'),
            value: _startValue,
            child: Text('+ Start a family'),
          ),
          if (showManage)
            const PopupMenuItem<String>(
              key: Key('family-menu-manage'),
              value: _manageValue,
              child: Text('Manage families'),
            ),
        ];
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    familyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
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
            const SizedBox(height: 6),
            Container(
              key: active ? const Key('header-underline-family') : null,
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
    return Material(
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
                  maxLines: 1,
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
    );
  }
}

class _HeaderAvatar extends StatefulWidget {
  const _HeaderAvatar({required this.page, required this.onLogout});

  final AlbumHeaderPage page;
  final Future<void> Function()? onLogout;

  @override
  State<_HeaderAvatar> createState() => _HeaderAvatarState();
}

class _HeaderAvatarState extends State<_HeaderAvatar> {
  /// Stitch avatar menu `6b07fcdcaa204d028e79ab4494ca975a`: outlined 19px.
  static const _menuIcon = Color(0xFF817976);

  @override
  void initState() {
    super.initState();
    ProfileSession.instance.addListener(_onProfile);
    ProfileSession.instance.ensureLoaded();
  }

  @override
  void dispose() {
    ProfileSession.instance.removeListener(_onProfile);
    super.dispose();
  }

  void _onProfile() {
    if (mounted) setState(() {});
  }

  Widget _menuRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 19, color: _menuIcon),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.sourceSans3(
            color: albumInk,
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.15,
          ),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    final callback = widget.onLogout;
    if (callback != null) {
      await callback();
      return;
    }
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final session = ProfileSession.instance;
    return PopupMenuButton<String>(
      key: const Key('header-avatar'),
      padding: EdgeInsets.zero,
      offset: const Offset(0, 40),
      constraints: const BoxConstraints(minWidth: 224, maxWidth: 280),
      color: const Color(0xFFFCF9F5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE6DCD1)),
      ),
      onSelected: (value) async {
        if (value == 'settings') {
          if (widget.page == AlbumHeaderPage.settings) return;
          GoRouter.of(context).push(AppRoutes.settings);
          return;
        }
        await _logout();
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem<String>(
            key: const Key('header-menu-settings'),
            value: 'settings',
            child: _menuRow(Icons.settings, 'Settings'),
          ),
          PopupMenuItem<String>(
            key: const Key('header-menu-logout'),
            value: 'logout',
            child: _menuRow(Icons.logout, 'Logout'),
          ),
        ];
      },
      child: ProfileAvatar(
        size: 32,
        displayName: session.displayName,
        bytes: session.avatarBytes,
      ),
    );
  }
}
