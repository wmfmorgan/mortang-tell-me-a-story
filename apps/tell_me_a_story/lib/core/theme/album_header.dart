import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/families_api.dart';
import '../../data/manage_families_api.dart';
import '../../data/profile_session.dart';
import '../../features/family/family_role.dart';
import '../../features/family/family_tree_order.dart';
import '../navigation/unsaved_guard.dart';
import '../router/app_router.dart';
import 'album_chrome.dart';
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
    this.relatedFamilies = const [],
    this.canWrite = true,
    this.manageApi,
    this.onInvite,
    this.onSaveDraft,
    this.onPublish,
    this.captureStatus,
    this.captureSecondaryLabel = 'Save draft',
    this.capturePrimaryLabel = 'Publish story',
    this.onLogout,
    this.onStartTimeline,
  });

  final AlbumHeaderPage page;
  final String familyName;
  final List<MemberFamily> families;
  final String? currentFamilyId;
  final ValueChanged<String> onFamilySelected;
  final List<StewardFamily> stewarded;
  final List<TreeFamily> relatedFamilies;
  final bool canWrite;
  final ManageFamiliesGateway? manageApi;
  final VoidCallback? onInvite;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onPublish;
  final String? captureStatus;
  final String captureSecondaryLabel;
  final String capturePrimaryLabel;
  final Future<void> Function()? onLogout;

  /// Timeline page only. Null hides the timeline branch row.
  final VoidCallback? onStartTimeline;

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
              captureStatus: captureStatus,
            );
            final bar = _HeaderBar(
              page: page,
              familyName: familyName,
              families: families,
              currentFamilyId: currentFamilyId,
              onFamilySelected: onFamilySelected,
              canWrite: canWrite,
              onInvite: onInvite,
              onSaveDraft: onSaveDraft,
              onPublish: onPublish,
              captureStatus: captureStatus,
              captureSecondaryLabel: captureSecondaryLabel,
              capturePrimaryLabel: capturePrimaryLabel,
              onLogout: onLogout,
              onStartTimeline: onStartTimeline,
              onTimeline: () => _openTimeline(context),
              onDrafts: () {
                unawaited(_openDrafts(context));
              },
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

  Future<void> _openDrafts(BuildContext context) async {
    if (page == AlbumHeaderPage.drafts) return;
    if (!await _confirmStoryExit(context) || !context.mounted) return;
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
    required this.canWrite,
    required this.onInvite,
    required this.onSaveDraft,
    required this.onPublish,
    required this.captureStatus,
    required this.captureSecondaryLabel,
    required this.capturePrimaryLabel,
    required this.onLogout,
    required this.onStartTimeline,
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
  final bool canWrite;
  final VoidCallback? onInvite;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onPublish;
  final String? captureStatus;
  final String captureSecondaryLabel;
  final String capturePrimaryLabel;
  final Future<void> Function()? onLogout;
  final VoidCallback? onStartTimeline;
  final VoidCallback onTimeline;
  final VoidCallback onDrafts;
  final VoidCallback onNewStory;
  final _HeaderMetrics metrics;

  Widget _captureActions() {
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (captureStatus != null) ...[
          Text(
            captureStatus!,
            style: GoogleFonts.sourceSans3(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: albumInk.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 12),
        ],
        TextButton(
          onPressed: onSaveDraft,
          style: TextButton.styleFrom(
            foregroundColor: albumInk,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            side: BorderSide(color: albumInk.withValues(alpha: 0.3)),
            shape: const StadiumBorder(),
            textStyle: GoogleFonts.sourceSans3(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(captureSecondaryLabel),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: onPublish,
          style: FilledButton.styleFrom(
            backgroundColor: albumTerracotta,
            foregroundColor: const Color(0xFFFFF6F3),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: const StadiumBorder(),
            textStyle: GoogleFonts.sourceSans3(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(capturePrimaryLabel),
        ),
      ],
    );
    if (metrics.loose) return actions;
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
              page: page,
              familyName: familyName,
              families: families,
              currentFamilyId: currentFamilyId,
              onSelected: onFamilySelected,
              onStartTimeline: onStartTimeline,
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
          if (!metrics.loose && page != AlbumHeaderPage.capture) const Spacer(),
          if (page == AlbumHeaderPage.capture)
            _captureActions()
          else if (canWrite) ...[
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
            FilledButton(
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
              child: PlusLabel(
                label: 'New story',
                onTerracotta: true,
                style: GoogleFonts.sourceSans3(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: albumParchment,
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
    this.captureStatus,
  });

  final AlbumHeaderPage page;
  final double pad;
  final double word;
  final double family;
  final double search;
  final List<double> gaps;
  final bool loose;
  final String? captureStatus;

  static const _searchMax = 224.0;
  static const _searchMin = 54.0;
  static const _familyChrome = 47.5;
  static const _familyMin = 46.0;
  static const _padMax = 32.0;

  static _HeaderMetrics of({
    required AlbumHeaderPage page,
    required String familyName,
    String? captureStatus,
  }) {
    return _HeaderMetrics(
      page: page,
      pad: _padMax,
      word: _textWidth('Tell Me a Story', _wordStyle),
      family: _textWidth(familyName, _familyStyle) + _familyChrome,
      search: _searchMax,
      gaps: const [16, 12, 20, 18, 16],
      loose: true,
      captureStatus: captureStatus,
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
      captureStatus: captureStatus,
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
      final status = captureStatus;
      final statusWidth = status == null
          ? 0.0
          : _textWidth(
                  status,
                  GoogleFonts.sourceSans3(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ) +
                12;
      return statusWidth +
          _textWidth(
            'Save draft',
            GoogleFonts.sourceSans3(fontSize: 14, fontWeight: FontWeight.w600),
          ) +
          40 +
          12 +
          _textWidth(
            'Publish story',
            GoogleFonts.sourceSans3(fontSize: 14, fontWeight: FontWeight.w600),
          ) +
          40 +
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

Future<bool> _confirmStoryExit(BuildContext context) async {
  final guard = UnsavedGuardScope.maybeOf(context);
  if (guard == null || !guard.exitPrompts) return true;
  return guard.confirmLeave(context);
}

Future<bool> _confirmFamilySwitch(BuildContext context, String? name) async {
  final guard = UnsavedGuardScope.maybeOf(context);
  if (guard == null) return true;
  return guard.confirmLeave(context, switchToFamilyName: name);
}

Future<void> _openSearch(BuildContext context) async {
  if (!await _confirmStoryExit(context) || !context.mounted) return;
  GoRouter.of(context).push(AppRoutes.search);
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
    required this.page,
    required this.familyName,
    required this.families,
    required this.currentFamilyId,
    required this.onSelected,
    required this.onStartTimeline,
    required this.active,
  });

  static const _timelineValue = 'start-timeline';
  static const _manageValue = 'manage-families';

  final AlbumHeaderPage page;
  final String familyName;
  final List<MemberFamily> families;
  final String? currentFamilyId;
  final ValueChanged<String> onSelected;
  final VoidCallback? onStartTimeline;
  final bool active;

  String? _nameFor(String id) {
    for (final family in families) {
      if (family.id == id) return family.name;
    }
    return null;
  }

  Future<void> _pickFamily(BuildContext context, String value) async {
    if (value == currentFamilyId) return;
    final leave = await _confirmFamilySwitch(context, _nameFor(value));
    if (!leave || !context.mounted) return;
    onSelected(value);
    if (page == AlbumHeaderPage.timeline) return;
    GoRouter.maybeOf(context)?.go(AppRoutes.timeline);
  }

  Widget _familyActionRow(IconData icon, String label) {
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
    final width = MediaQuery.sizeOf(context).width;
    final menuConstraints = width < 640
        ? BoxConstraints.tightFor(width: width - 32)
        : const BoxConstraints(maxWidth: 320);
    return PopupMenuButton<String>(
      key: const Key('family-menu'),
      tooltip: familyName,
      padding: EdgeInsets.zero,
      color: albumDialogSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE6DCD1)),
      ),
      constraints: menuConstraints,
      onSelected: (value) {
        if (value == _timelineValue) {
          onStartTimeline?.call();
          return;
        }
        if (value == _manageValue) {
          GoRouter.of(context).go(AppRoutes.manageFamilies);
          return;
        }
        unawaited(_pickFamily(context, value));
      },
      itemBuilder: (context) {
        final rows = nestFamilies(families);
        final branchLabel = 'Add a timeline branch to $familyName';
        return [
          for (final row in rows)
            PopupMenuItem<String>(
              key: Key('family-menu-item-${row.family.id}'),
              value: row.family.id,
              child: Row(
                children: [
                  FamilyIndentGuide(depth: row.depth, height: 48),
                  SizedBox(
                    width: 24,
                    child: row.family.id == currentFamilyId
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: albumTerracotta,
                          )
                        : null,
                  ),
                  FamilyMonogram(
                    key: Key('family-monogram-${row.family.id}'),
                    name: row.family.name,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      row.family.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: row.family.id == currentFamilyId
                          ? const TextStyle(fontWeight: FontWeight.w500)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          PopupMenuDivider(
            key: const Key('family-menu-divider'),
            height: 1,
            thickness: 1,
            color: albumSage.withValues(alpha: 0.3),
          ),
          if (onStartTimeline != null)
            PopupMenuItem<String>(
              key: const Key('family-menu-start-timeline'),
              value: _timelineValue,
              child: Tooltip(
                message: branchLabel,
                child: _familyActionRow(
                  Icons.account_tree_outlined,
                  branchLabel,
                ),
              ),
            ),
          PopupMenuItem<String>(
            key: const Key('family-menu-manage'),
            value: _manageValue,
            child: _familyActionRow(Icons.group_outlined, 'Manage families'),
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
        onTap: () {
          unawaited(_openSearch(context));
        },
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
  static const _menuIcon = albumSage;

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

  Future<void> _onAvatarSelected(BuildContext context, String value) async {
    if (value == 'settings') {
      if (widget.page == AlbumHeaderPage.settings) return;
      if (!await _confirmStoryExit(context) || !context.mounted) return;
      GoRouter.of(context).push(AppRoutes.settings);
      return;
    }
    if (!await _confirmStoryExit(context) || !context.mounted) return;
    await _logout();
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
      onSelected: (value) {
        unawaited(_onAvatarSelected(context, value));
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
