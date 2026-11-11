part of 'album_header.dart';

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

class _HomeNav extends StatelessWidget {
  const _HomeNav({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('header-nav-home'),
      tooltip: 'Home',
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: _homeHit,
        height: _homeHit,
      ),
      style: IconButton.styleFrom(
        foregroundColor: albumTerracotta,
        fixedSize: const Size(_homeHit, _homeHit),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(
        Icons.home,
        color: albumTerracotta,
        size: _homeIconSize,
        semanticLabel: 'Home',
      ),
    );
  }
}

/// 2px rule under an active nav label or family name. Clear when inactive.
class _Underline extends StatelessWidget {
  const _Underline({
    required this.underlineKey,
    required this.width,
    required this.active,
  });

  final Key underlineKey;
  final double width;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: active ? underlineKey : null,
      width: width,
      height: 2,
      decoration: BoxDecoration(
        color: active ? albumInk : albumBackdropClear,
        borderRadius: BorderRadius.circular(999),
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _navPadH, vertical: 4),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Text(label, style: style),
            Positioned(
              bottom: -8,
              child: _Underline(
                underlineKey: underlineKey,
                width: _textWidth(label, style),
                active: active,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('timeline-search'),
      onPressed: () {
        unawaited(_openSearch(context));
      },
      icon: const Icon(Icons.search, color: albumInk, size: 22),
      color: albumInk,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      style: IconButton.styleFrom(
        foregroundColor: albumInk,
        fixedSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
