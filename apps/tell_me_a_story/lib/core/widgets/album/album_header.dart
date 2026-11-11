import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/app_session_provider.dart';
import 'package:tell_me_a_story/core/session/family_membership.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/session/profile_session.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_chrome.dart';
import 'package:tell_me_a_story/core/widgets/avatar/profile_avatar.dart';
import 'package:tell_me_a_story/core/widgets/family/family_role.dart';
import 'package:tell_me_a_story/core/widgets/family/family_tree_order.dart';
import 'package:tell_me_a_story/core/widgets/navigation/unsaved_guard.dart';

part 'album_header_avatar.dart';
part 'album_header_bar.dart';
part 'album_header_family_menu.dart';
part 'album_header_metrics.dart';
part 'album_header_nav.dart';

/// Which signed-in screen is showing the shared bar.
enum AlbumHeaderPage {
  timeline,
  drafts,
  capture,
  settings,
  manageFamilies,
  familyLanding,
  allStories,
  familyTree,
}

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
    this.onInvite,
    this.onSaveDraft,
    this.onPublish,
    this.captureStatus,
    this.captureSecondaryLabel = 'Save draft',
    this.capturePrimaryLabel = 'Publish story',
    this.onLogout,
    this.onStartTimeline,
    this.onShowDecades,
  });

  final AlbumHeaderPage page;
  final String familyName;
  final List<MemberFamily> families;
  final String? currentFamilyId;
  final ValueChanged<String> onFamilySelected;
  final List<StewardFamily> stewarded;
  final List<TreeFamily> relatedFamilies;
  final bool canWrite;
  final VoidCallback? onInvite;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onPublish;
  final String? captureStatus;
  final String captureSecondaryLabel;
  final String capturePrimaryLabel;
  final Future<void> Function()? onLogout;

  /// Null hides the branch row. Hosts set this only when the current
  /// family is in the caller's membership list.
  final VoidCallback? onStartTimeline;

  /// Timeline hosts set this so the Timeline item returns to Decades
  /// when the route is already the timeline.
  final VoidCallback? onShowDecades;

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
          builder: (context, constraints) =>
              _HeaderLayout(header: this, width: constraints.maxWidth),
        ),
      ),
    );
  }

  void _openHome(BuildContext context) {
    if (page == AlbumHeaderPage.familyLanding) return;
    GoRouter.maybeOf(context)?.go(AppRoutes.familyLanding);
  }

  void _openDecades(BuildContext context) {
    if (page == AlbumHeaderPage.timeline) onShowDecades?.call();
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final uri = router.state.uri;
    if (uri.path == AppRoutes.timeline &&
        uri.queryParameters['view'] == 'decades') {
      return;
    }
    router.go('${AppRoutes.timeline}?view=decades');
  }

  void _openTimeline(BuildContext context) {
    if (page == AlbumHeaderPage.allStories) return;
    final familyId = currentFamilyId;
    if (familyId == null) {
      GoRouter.of(context).go(AppRoutes.timeline);
      return;
    }
    GoRouter.of(context).go(AppRoutes.allStoriesPath(familyId));
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

/// Measures the bar for [width] and scales it below its floor.
class _HeaderLayout extends StatelessWidget {
  const _HeaderLayout({required this.header, required this.width});

  final AlbumHeader header;
  final double width;

  @override
  Widget build(BuildContext context) {
    final natural = _HeaderMetrics.of(
      page: header.page,
      familyName: header.familyName,
      captureStatus: header.captureStatus,
      gaps: _HeaderBar.barGaps,
    );
    // Nav labels and actions cannot shrink. Below their floor the
    // whole bar scales, the same way a 320px window does.
    final scaleDown =
        width <= AlbumHeader._scaleAt || width < natural.inflexibleFloor;
    final bar = _HeaderBar(
      header: header,
      onHome: () => header._openHome(context),
      onTimeline: () => header._openDecades(context),
      onStories: () => header._openTimeline(context),
      onDrafts: () {
        unawaited(header._openDrafts(context));
      },
      onNewStory: () => header._openNewStory(context),
      metrics: scaleDown ? natural : natural.fit(width),
    );
    if (scaleDown) {
      return SizedBox(
        width: width,
        height: AlbumHeader.height,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: bar,
        ),
      );
    }
    return SizedBox(width: width, height: AlbumHeader.height, child: bar);
  }
}
