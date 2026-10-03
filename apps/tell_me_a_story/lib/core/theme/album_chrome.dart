import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'album_theme.dart';

/// Centered Stitch content column. The scaffold behind it stays parchment.
const albumColumnWidth = 800.0;

class AlbumColumn extends StatelessWidget {
  const AlbumColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: albumColumnWidth),
        child: child,
      ),
    );
  }
}

/// Wordmark plus the controls that already exist. No extra nav destinations.
class AlbumTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AlbumTopBar({
    super.key,
    this.screenLabel,
    this.leading,
    this.actions = const [],
  });

  final String? screenLabel;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final label = screenLabel;
    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Tell Me a Story',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.newsreader(
                      color: albumInk,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (leading != null) leading!,
                if (label != null && label.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: GoogleFonts.sourceSans3(
                        color: albumInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
          ),
        ],
      ),
    );
  }
}

/// Warm card for one existing form section.
class AlbumPanel extends StatelessWidget {
  const AlbumPanel({super.key, this.title, this.trailing, required this.child});

  final String? title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F6),
        borderRadius: BorderRadius.circular(albumCardRadius),
        border: Border.all(color: albumSage.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: GoogleFonts.sourceSans3(
                      color: albumInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (trailing != null)
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailing!,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

/// Centered parchment dialog. Callers keep their existing [show] signatures.
Future<T?> showAlbumDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 640,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: const Color(0x992C2416),
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height;
      return Dialog(
        backgroundColor: albumParchment,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: albumSage.withValues(alpha: 0.35)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: height * 0.9,
          ),
          child: builder(ctx),
        ),
      );
    },
  );
}
