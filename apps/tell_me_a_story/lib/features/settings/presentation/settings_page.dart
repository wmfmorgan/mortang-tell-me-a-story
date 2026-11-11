import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tell_me_a_story/core/domain/birth_visibility.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/domain/profile_repository.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/app_session_provider.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/session/profile_session.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_chrome.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/core/widgets/avatar/profile_avatar.dart';
import 'package:tell_me_a_story/core/widgets/avatar/profile_initials.dart';
import 'package:tell_me_a_story/core/widgets/navigation/unsaved_guard.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date.dart';
import 'package:tell_me_a_story/features/family/presentation/start_timeline_dialog.dart';
import 'package:tell_me_a_story/features/invites/presentation/invite_modal.dart';
import 'package:tell_me_a_story/features/people/presentation/person_date_field.dart';
import 'package:tell_me_a_story/features/settings/presentation/settings_providers.dart';

part 'settings_profile_card.dart';

const SettingsFamilies _noFamilies = (
  currentFamilyId: null,
  families: <MemberFamily>[],
  stewarded: [],
);

/// Signed-in profile at `/settings`. Name, email, a picture, and one Save.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.onLogout, this.pickImageBytes});

  final Future<void> Function()? onLogout;
  final Future<Uint8List?> Function()? pickImageBytes;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _about = TextEditingController();
  StoryDate? _birth;
  BirthVisibility _visibility = BirthVisibility.hidden;

  var _saving = false;
  var _savedNotice = false;
  var _birthEpoch = 0;
  String? _storedEmail;
  String? _selectedFamilyId;
  String? _displayName;
  Uint8List? _savedBytes;
  Uint8List? _pending;
  String _loadedName = '';
  String _loadedAbout = '';
  StoryDate? _loadedBirth;
  BirthVisibility _loadedVisibility = BirthVisibility.hidden;
  Uint8List? _loadedBytes;
  late final UnsavedGuard _guard;
  ValueKey<String>? _pageKey;

  @override
  void initState() {
    super.initState();
    _guard = UnsavedGuard(
      exitPrompts: false,
      isDirty: _isDirty,
      save: _save,
      discard: _cancel,
    );
    _about.addListener(_onAbout);
    ref.listenManual(settingsProfileProvider, _onProfile);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (GoRouter.maybeOf(context) == null) return;
    final key = GoRouterState.of(context).pageKey;
    final previous = _pageKey;
    if (previous == key) return;
    if (previous != null) UnsavedGuards.unregister(previous, _guard);
    _pageKey = key;
    UnsavedGuards.register(key, _guard);
  }

  void _onAbout() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final key = _pageKey;
    if (key != null) UnsavedGuards.unregister(key, _guard);
    _guard.dispose();
    _about.removeListener(_onAbout);
    _name.dispose();
    _email.dispose();
    _about.dispose();
    super.dispose();
  }

  void _onProfile(
    AsyncValue<SettingsProfile>? previous,
    AsyncValue<SettingsProfile> next,
  ) {
    if (next case AsyncData(:final value)) _seed(value);
  }

  void _seed(SettingsProfile loaded) {
    final profile = loaded.profile;
    final email = profile?.email ?? '';
    _name.text = profile?.displayName ?? '';
    _email.text = email;
    _about.text = profile?.about ?? '';
    _birth = storyDateFromPerson(profile?.birthDate, profile?.birthPrecision);
    _visibility = profile?.birthVisibility ?? BirthVisibility.hidden;
    setState(() {
      _storedEmail = email;
      _displayName = profile?.displayName;
      _savedBytes = loaded.avatar;
      _rememberLoaded();
    });
    ref
        .read(profileSessionProvider.notifier)
        .apply(
          displayName: profile?.displayName,
          email: profile?.email,
          avatarBytes: loaded.avatar,
        );
  }

  /// Failed family loads show no families, as before.
  SettingsFamilies get _families {
    final families = ref.read(settingsFamiliesProvider);
    if (families.hasError) return _noFamilies;
    return families.value ?? _noFamilies;
  }

  String? get _familyId => _selectedFamilyId ?? _families.currentFamilyId;

  bool _isMember(String? id) =>
      id != null && _families.families.any((row) => row.id == id);

  String? _sessionUserId() => ref.read(appSessionProvider).currentUserId;

  Future<void> _startTimeline() async {
    final id = _familyId;
    if (id == null || !_isMember(id) || !mounted) return;
    final userId = _sessionUserId();
    if (userId == null) return;
    final published = await ref
        .read(storiesRepositoryProvider)
        .listPublished(id);
    if (!mounted) return;
    final created = await showStartTimelineDialog(
      context,
      parentId: id,
      parentName: _familyName,
      stories: [
        for (final story in published)
          if (story.status == StoryStatus.published) story,
      ],
      currentUserId: userId,
      onWriteStory: () {
        if (!mounted) return;
        GoRouter.of(context).push('${AppRoutes.newStory}?newTimelineFrom=$id');
      },
    );
    if (created == null || !mounted) return;
    ref.invalidate(settingsFamiliesProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${created.name} timeline created')));
  }

  void _selectFamily(String id) {
    ref.read(familySelectionProvider.notifier).remember(id);
    setState(() => _selectedFamilyId = id);
  }

  String get _familyName {
    final id = _familyId;
    for (final family in _families.families) {
      if (family.id == id) return family.name;
    }
    return 'Family';
  }

  Future<void> _openInvite() async {
    final familyId =
        _familyId ?? await ref.read(inviteRepositoryProvider).currentFamilyId();
    if (familyId == null) return;
    if (!mounted) return;
    await InviteModal.show(
      context,
      familyId: familyId,
      familyName: _familyName,
    );
  }

  void _rememberLoaded() {
    _loadedName = _name.text;
    _loadedAbout = _about.text;
    _loadedBirth = _birth;
    _loadedVisibility = _visibility;
    _loadedBytes = _savedBytes;
  }

  void _cancel() {
    _name.text = _loadedName;
    _about.text = _loadedAbout;
    setState(() {
      _birth = _loadedBirth;
      _visibility = _loadedVisibility;
      _birthEpoch += 1;
      _pending = null;
      _savedBytes = _loadedBytes;
      _savedNotice = false;
    });
  }

  Future<void> _pick() async {
    final picker = widget.pickImageBytes ?? _pickFromGallery;
    final bytes = await picker();
    if (bytes == null || !mounted) return;
    setState(() {
      _pending = bytes;
      _savedNotice = false;
    });
  }

  Future<Uint8List?> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return file.readAsBytes();
  }

  bool _isDirty() {
    final birth = _storedBirth(_birth);
    final loadedBirth = _storedBirth(_loadedBirth);
    final birthDiffers =
        birth?.date != loadedBirth?.date ||
        birth?.precision != loadedBirth?.precision;
    return _name.text != _loadedName ||
        _about.text != _loadedAbout ||
        birthDiffers ||
        _visibility != _loadedVisibility ||
        _pending != null;
  }

  bool _canSave(String name) {
    if (_saving || name.isEmpty) return false;
    if (_about.text.length <= 500) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('About must be 500 characters or fewer.')),
    );
    return false;
  }

  Future<bool> _save() async {
    final name = _name.text.trim();
    if (!_canSave(name)) return false;
    setState(() => _saving = true);
    var nameSaved = false;
    try {
      await _saveAccount(name);
      nameSaved = true;
      await _saveAvatar();
      _savedNotice = true;
      _rememberLoaded();
      if (!mounted) return true;
      setState(() {});
      return true;
    } catch (_) {
      // Any failure is shown as the save snackbar; the session keeps the
      // last saved profile.
      if (!mounted) return false;
      if (!nameSaved) _applySession(_displayName, _savedBytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save your profile. Try again.')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAccount(String name) async {
    final birth = _storedBirth(_birth);
    final about = _about.text.trim();
    await ref
        .read(profileRepositoryProvider)
        .saveAccount(
          displayName: name,
          birthDate: birth?.date,
          birthPrecision: birth?.precision,
          birthVisibility: _visibility,
          about: about.isEmpty ? null : about,
        );
    _displayName = name;
    _applySession(name, _pending ?? _savedBytes);
  }

  Future<void> _saveAvatar() async {
    final pending = _pending;
    if (pending == null) return;
    await ref.read(profileRepositoryProvider).saveAvatar(pending);
    _savedBytes = pending;
    _pending = null;
  }

  void _applySession(String? displayName, Uint8List? avatarBytes) {
    ref
        .read(profileSessionProvider.notifier)
        .apply(
          displayName: displayName,
          email: _storedEmail,
          avatarBytes: avatarBytes,
        );
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(settingsProfileProvider).isLoading;
    ref.watch(settingsFamiliesProvider);
    final families = _families;
    final familyId = _familyId;
    final member = _isMember(familyId);
    return UnsavedGuardScope(
      guard: _guard,
      child: Scaffold(
        backgroundColor: albumParchment,
        appBar: AlbumHeader(
          page: AlbumHeaderPage.settings,
          familyName: _familyName,
          families: families.families,
          currentFamilyId: familyId,
          onFamilySelected: _selectFamily,
          stewarded: families.stewarded,
          canWrite: member,
          onInvite: member ? _openInvite : null,
          onStartTimeline: member ? _startTimeline : null,
          onLogout: widget.onLogout,
        ),
        body: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : _SettingsBody(familyName: _familyName, form: _form()),
        ),
      ),
    );
  }

  SettingsProfileForm _form() => SettingsProfileForm(
    name: _name,
    about: _about,
    email: _email,
    displayName: _displayName,
    preview: _pending ?? _savedBytes,
    birth: _birth,
    birthEpoch: _birthEpoch,
    visibility: _visibility,
    saving: _saving,
    savedNotice: _savedNotice,
    onPick: _pick,
    onBirthChanged: (date) => _birth = date,
    onVisibility: (value) => setState(() => _visibility = value),
    onCancel: _cancel,
    onSave: _save,
  );
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.familyName, required this.form});

  final String familyName;
  final SettingsProfileForm form;

  @override
  Widget build(BuildContext context) {
    return AlbumColumn(
      maxWidth: 720,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        children: [
          const _Breadcrumb(),
          const SizedBox(height: 28),
          Text(
            'Settings',
            style: GoogleFonts.newsreader(
              color: albumInk,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE8DFD5)),
          const SizedBox(height: 18),
          _Tabs(familyName: familyName),
          const SizedBox(height: 22),
          SettingsProfileCard(form: form),
          const SizedBox(height: 36),
          Text(
            '“Every family possesses a treasure chest of small tales that keep us anchored.”',
            textAlign: TextAlign.center,
            style: GoogleFonts.literata(
              color: const Color(0xCC665D5A),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb();

  @override
  Widget build(BuildContext context) {
    final muted = GoogleFonts.sourceSans3(
      color: const Color(0xFF655E5B),
      fontSize: 12,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        TextButton.icon(
          onPressed: () => context.go(AppRoutes.timeline),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF655E5B),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.arrow_back, size: 14),
          label: Text('Back to Timeline', style: muted),
        ),
        Text('/', style: muted),
        Text('Settings', style: muted),
        Text('/', style: muted),
        Text(
          'Your profile',
          style: GoogleFonts.sourceSans3(
            color: albumTerracotta,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.familyName});

  final String familyName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _Tab(
          label: 'Your profile',
          icon: Icons.person_outline,
          selected: true,
        ),
        const SizedBox(width: 22),
        _Tab(label: familyName, icon: Icons.family_restroom_outlined),
        const SizedBox(width: 22),
        const _Tab(label: 'Notifications', icon: Icons.notifications_none),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.icon, this.selected = false});

  final String label;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? albumTerracotta : const Color(0xFF655E5B);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? albumTerracotta : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.sourceSans3(
                color: color,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

({DateTime date, String precision})? _storedBirth(StoryDate? date) {
  if (date == null) return null;
  return storedPersonDate(year: date.year, month: date.month, day: date.day);
}
