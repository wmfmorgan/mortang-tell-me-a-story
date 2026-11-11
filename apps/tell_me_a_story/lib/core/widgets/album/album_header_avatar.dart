part of 'album_header.dart';

class _HeaderAvatar extends ConsumerStatefulWidget {
  const _HeaderAvatar({required this.page, required this.onLogout});

  final AlbumHeaderPage page;
  final Future<void> Function()? onLogout;

  @override
  ConsumerState<_HeaderAvatar> createState() => _HeaderAvatarState();
}

class _HeaderAvatarState extends ConsumerState<_HeaderAvatar> {
  @override
  void initState() {
    super.initState();
    // Providers must not change while the tree builds, so the load starts
    // right after this frame's build.
    unawaited(
      Future.microtask(() async {
        if (!mounted) return;
        await ref.read(profileSessionProvider.notifier).ensureLoaded();
      }),
    );
  }

  Future<void> _logout() async {
    final callback = widget.onLogout;
    if (callback != null) {
      await callback();
      return;
    }
    await ref.read(appSessionProvider).signOut();
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
    final profile = ref.watch(profileSessionProvider);
    return PopupMenuButton<String>(
      key: const Key('header-avatar'),
      padding: EdgeInsets.zero,
      offset: const Offset(0, 40),
      constraints: const BoxConstraints(minWidth: 224, maxWidth: 280),
      color: albumMenuSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: albumModalBorder),
      ),
      onSelected: (value) {
        unawaited(_onAvatarSelected(context, value));
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          key: Key('header-menu-settings'),
          value: 'settings',
          child: _AvatarMenuRow(icon: Icons.settings, label: 'Settings'),
        ),
        PopupMenuItem<String>(
          key: Key('header-menu-logout'),
          value: 'logout',
          child: _AvatarMenuRow(icon: Icons.logout, label: 'Logout'),
        ),
      ],
      child: ProfileAvatar(
        size: 32,
        displayName: profile.displayName,
        bytes: profile.avatarBytes,
      ),
    );
  }
}

/// Stitch avatar menu `6b07fcdcaa204d028e79ab4494ca975a`: outlined 19px.
class _AvatarMenuRow extends StatelessWidget {
  const _AvatarMenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: albumSage),
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
}
