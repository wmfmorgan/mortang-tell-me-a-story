import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/navigation/unsaved_guard.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/album_chrome.dart';
import '../../core/theme/album_header.dart';
import '../../core/theme/album_theme.dart';
import '../../core/theme/profile_avatar.dart';
import '../../core/theme/profile_initials.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/invite_api.dart';
import '../../data/manage_families_api.dart';
import '../../data/people_api.dart';
import '../../data/profile_api.dart';
import '../../data/stories_api.dart';
import '../../data/profile_session.dart';
import '../family/start_timeline_dialog.dart';
import '../invites/invite_modal.dart';
import '../people/person_date_field.dart';
import '../stories/story_date.dart';

/// Signed-in profile at `/settings`. Name, email, a picture, and one Save.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.profileApi,
    this.familiesApi,
    this.inviteApi,
    this.peopleApi,
    this.onLogout,
    this.pickImageBytes,
  });

  final ProfileGateway? profileApi;
  final FamiliesGateway? familiesApi;
  final InviteGateway? inviteApi;
  final PeopleGateway? peopleApi;
  final Future<void> Function()? onLogout;
  final Future<Uint8List?> Function()? pickImageBytes;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final ProfileGateway _profile;
  late final InviteGateway _invite;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _about = TextEditingController();
  StoryDate? _birth;
  BirthVisibility _visibility = BirthVisibility.hidden;

  var _loading = true;
  var _saving = false;
  var _savedNotice = false;
  var _birthEpoch = 0;
  String? _storedEmail;
  String? _familyId;
  String? _displayName;
  Uint8List? _savedBytes;
  Uint8List? _pending;
  String _loadedName = '';
  String _loadedEmail = '';
  String _loadedAbout = '';
  StoryDate? _loadedBirth;
  BirthVisibility _loadedVisibility = BirthVisibility.hidden;
  Uint8List? _loadedBytes;
  List<MemberFamily> _families = const [];
  List<StewardFamily> _stewarded = const [];
  Set<String> _memberIds = const {};
  late final UnsavedGuard _guard;
  ValueKey<String>? _pageKey;

  @override
  void initState() {
    super.initState();
    _profile = widget.profileApi ?? ProfileApi();
    _invite = widget.inviteApi ?? InviteApi();
    _guard = UnsavedGuard(
      exitPrompts: false,
      isDirty: _isDirty,
      save: _save,
      discard: _cancel,
    );
    _about.addListener(_onAbout);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (GoRouter.maybeOf(context) == null) return;
    final key = GoRouterState.of(context).pageKey;
    if (_pageKey == key) return;
    if (_pageKey != null) UnsavedGuards.unregister(_pageKey!, _guard);
    _pageKey = key;
    UnsavedGuards.register(key, _guard);
  }

  void _onAbout() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_pageKey != null) UnsavedGuards.unregister(_pageKey!, _guard);
    _guard.dispose();
    _about.removeListener(_onAbout);
    _name.dispose();
    _email.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await _profile.loadOwn();
      if (!mounted) return;
      final email = profile?.email ?? '';
      _name.text = profile?.displayName ?? '';
      _email.text = email;
      _about.text = profile?.about ?? '';
      _birth = storyDateFromPerson(profile?.birthDate, profile?.birthPrecision);
      _visibility = profile?.birthVisibility ?? BirthVisibility.hidden;
      Uint8List? bytes;
      final path = profile?.avatarPath;
      if (path != null) {
        bytes = await _profile.downloadAvatar(path);
      }
      if (!mounted) return;
      setState(() {
        _storedEmail = email;
        _displayName = profile?.displayName;
        _savedBytes = bytes;
        _loading = false;
        _rememberLoaded();
      });
      ProfileSession.instance.apply(
        displayName: profile?.displayName,
        email: profile?.email,
        avatarBytes: bytes,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
    await _loadFamilies();
  }

  Future<void> _loadFamilies() async {
    List<MemberFamily> rows = const [];
    List<StewardFamily> stewarded = const [];
    var memberIds = <String>{};
    try {
      _familyId ??= await _invite.currentFamilyId();
      if (widget.familiesApi != null) {
        rows = await widget.familiesApi!.listMine();
        stewarded = await widget.familiesApi!.listStewarded();
        memberIds = rows.map((row) => row.id).toSet();
      } else if (widget.inviteApi != null) {
        final id = _familyId;
        if (id != null) {
          rows = [
            MemberFamily(id: id, name: 'Family', createdAt: DateTime.utc(2020)),
          ];
        }
      } else {
        final live = FamiliesApi();
        rows = await live.listMine();
        stewarded = await live.listStewarded();
        memberIds = rows.map((row) => row.id).toSet();
      }
    } catch (_) {
      rows = const [];
      stewarded = const [];
      memberIds = {};
    }
    if (!mounted) return;
    setState(() {
      _families = rows;
      _stewarded = stewarded;
      _memberIds = memberIds;
    });
  }

  bool get _currentFamilyIsMember {
    final id = _familyId;
    return id != null && _memberIds.contains(id);
  }

  String? _sessionUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _startTimeline() async {
    final id = _familyId;
    if (id == null || !_memberIds.contains(id) || !mounted) return;
    final userId = _sessionUserId();
    if (userId == null) return;
    final published = await StoriesApi().listPublished(id);
    if (!mounted) return;
    final created = await showStartTimelineDialog(
      context,
      parentId: id,
      parentName: _familyName,
      stories: [
        for (final story in published)
          if (story.status == StoryStatus.published) story,
      ],
      familiesApi: widget.familiesApi ?? FamiliesApi(),
      peopleApi: widget.peopleApi ?? PeopleApi(),
      manageApi: ManageFamiliesApi(),
      currentUserId: userId,
      onWriteStory: () {
        if (!mounted) return;
        GoRouter.of(context).push('${AppRoutes.newStory}?newTimelineFrom=$id');
      },
    );
    if (created == null || !mounted) return;
    await _loadFamilies();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${created.name} timeline created')));
  }

  void _selectFamily(String id) {
    FamilySelection.remember(id);
    setState(() => _familyId = id);
  }

  String get _familyName {
    for (final family in _families) {
      if (family.id == _familyId) return family.name;
    }
    return 'Family';
  }

  Future<void> _openInvite() async {
    var familyId = _familyId ?? await _invite.currentFamilyId();
    if (familyId == null) return;
    if (!mounted) return;
    await InviteModal.show(
      context,
      familyId: familyId,
      familyName: _familyName,
      api: _invite,
      people: widget.peopleApi,
    );
  }

  void _rememberLoaded() {
    _loadedName = _name.text;
    _loadedEmail = _email.text;
    _loadedAbout = _about.text;
    _loadedBirth = _birth;
    _loadedVisibility = _visibility;
    _loadedBytes = _savedBytes;
  }

  void _cancel() {
    _name.text = _loadedName;
    _email.text = _loadedEmail;
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

  Uint8List? get _preview => _pending ?? _savedBytes;

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
        _email.text != _loadedEmail ||
        _about.text != _loadedAbout ||
        birthDiffers ||
        _visibility != _loadedVisibility ||
        _pending != null;
  }

  Future<bool> _save() async {
    if (_saving) return false;
    final name = _name.text.trim();
    if (name.isEmpty) return false;
    if (_about.text.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('About must be 500 characters or fewer.')),
      );
      return false;
    }
    setState(() => _saving = true);
    var nameSaved = false;
    try {
      final birth = _storedBirth(_birth);
      final about = _about.text.trim();
      await _profile.saveAccount(
        displayName: name,
        birthDate: birth?.date,
        birthPrecision: birth?.precision,
        birthVisibility: _visibility,
        about: about.isEmpty ? null : about,
      );
      nameSaved = true;
      _displayName = name;
      ProfileSession.instance.apply(
        displayName: name,
        email: _storedEmail,
        avatarBytes: _pending ?? _savedBytes,
      );
      if (_pending != null) {
        await _profile.saveAvatar(_pending!);
        _savedBytes = _pending;
        _pending = null;
      }
      _savedNotice = true;
      final typed = _email.text.trim();
      final stored = _storedEmail ?? '';
      if (typed.isEmpty) {
        _email.text = stored;
      } else if (typed != stored) {
        await _profile.updateEmail(typed);
        _email.text = stored;
      }
      _rememberLoaded();
      if (!mounted) return true;
      setState(() {});
      return true;
    } catch (_) {
      if (!mounted) return false;
      if (!nameSaved) {
        ProfileSession.instance.apply(
          displayName: _displayName,
          email: _storedEmail,
          avatarBytes: _savedBytes,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save your profile. Try again.')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final aboutCount = _about.text.length;
    return UnsavedGuardScope(
      guard: _guard,
      child: Scaffold(
        backgroundColor: albumParchment,
        appBar: AlbumHeader(
          page: AlbumHeaderPage.settings,
          familyName: _familyName,
          families: _families,
          currentFamilyId: _familyId,
          onFamilySelected: _selectFamily,
          stewarded: _stewarded,
          canWrite: _currentFamilyIsMember,
          onInvite: _currentFamilyIsMember ? _openInvite : null,
          onStartTimeline: _currentFamilyIsMember ? _startTimeline : null,
          onLogout: widget.onLogout,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : AlbumColumn(
                  maxWidth: 720,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                    children: [
                      _breadcrumb(context),
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
                      _tabs(),
                      const SizedBox(height: 22),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFDF9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE8DFD5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _cardHeading(),
                              const SizedBox(height: 22),
                              const Divider(
                                height: 1,
                                color: Color(0xFFE8DFD5),
                              ),
                              const SizedBox(height: 24),
                              Text('PROFILE PHOTO', style: _kicker),
                              const SizedBox(height: 10),
                              _photoRow(preview),
                              const SizedBox(height: 28),
                              _nameBlock(),
                              const SizedBox(height: 22),
                              const Divider(
                                height: 1,
                                color: Color(0xB3E8DFD5),
                              ),
                              const SizedBox(height: 22),
                              _birthBlock(),
                              const SizedBox(height: 22),
                              const Divider(
                                height: 1,
                                color: Color(0xB3E8DFD5),
                              ),
                              const SizedBox(height: 22),
                              _aboutBlock(aboutCount),
                              const SizedBox(height: 22),
                              const Divider(
                                height: 1,
                                color: Color(0xB3E8DFD5),
                              ),
                              const SizedBox(height: 22),
                              _emailBlock(),
                              const SizedBox(height: 22),
                              const Divider(
                                height: 1,
                                color: Color(0xFFE8DFD5),
                              ),
                              const SizedBox(height: 16),
                              _actions(),
                            ],
                          ),
                        ),
                      ),
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
                ),
        ),
      ),
    );
  }

  Widget _breadcrumb(BuildContext context) {
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

  Widget _tabs() {
    return Row(
      children: [
        _tab('Your profile', Icons.person_outline, selected: true),
        const SizedBox(width: 22),
        _tab(_familyName, Icons.family_restroom_outlined),
        const SizedBox(width: 22),
        _tab('Notifications', Icons.notifications_none),
      ],
    );
  }

  Widget _tab(String label, IconData icon, {bool selected = false}) {
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

  Widget _cardHeading() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF5DED6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.badge_outlined,
            size: 18,
            color: albumTerracotta,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your profile',
                style: GoogleFonts.newsreader(
                  color: albumInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _photoRow(Uint8List? preview) {
    final initials = profileInitials(_displayName);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 104,
          height: 104,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFAF2EB),
                  border: Border.all(color: const Color(0xFFD8C7B8), width: 2),
                ),
                child: ProfileAvatar(
                  size: 86,
                  displayName: _displayName,
                  bytes: preview,
                ),
              ),
              if (preview != null && initials.isNotEmpty)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: albumTerracotta,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      initials,
                      style: GoogleFonts.sourceSans3(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const Key('settings-upload'),
                    onPressed: _saving ? null : _pick,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: albumTerracotta,
                      backgroundColor: const Color(0x80F5DED6),
                      side: BorderSide(
                        color: albumTerracotta.withValues(alpha: 0.2),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.photo_camera_outlined, size: 14),
                    label: const Text(
                      'Replace photo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _nameBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('NAME', style: _kicker),
            Text(
              ' *',
              style: _kicker.copyWith(color: albumTerracotta, letterSpacing: 0),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('settings-name'),
          controller: _name,
          style: _field,
          decoration: _decoration,
        ),
      ],
    );
  }

  Widget _birthBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 16,
                  color: albumTerracotta,
                ),
                const SizedBox(width: 6),
                Text('DATE OF BIRTH', style: _kicker),
                const SizedBox(width: 6),
                Text('(optional)', style: _hint),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        PersonDateField(
          key: ValueKey('settings-birth-$_birthEpoch'),
          label: 'Date of birth',
          showLabel: false,
          initial: _birth,
          onChanged: (date) => _birth = date,
        ),
        const SizedBox(height: 12),
        Text('Who can see it', style: _kicker),
        const SizedBox(height: 6),
        Wrap(
          key: const Key('settings-birth-visibility'),
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in const [
              (BirthVisibility.hidden, 'Hidden'),
              (BirthVisibility.year, 'Year only'),
              (BirthVisibility.yearMonth, 'Year and month'),
              (BirthVisibility.full, 'Full date'),
            ])
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: _visibility == option.$1
                      ? albumTerracotta
                      : albumInk,
                  backgroundColor: _visibility == option.$1
                      ? albumSage.withValues(alpha: 0.25)
                      : albumParchment,
                ),
                onPressed: _saving
                    ? null
                    : () => setState(() => _visibility = option.$1),
                child: Text(option.$2),
              ),
          ],
        ),
      ],
    );
  }

  Widget _aboutBlock(int count) {
    final over = count > 500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ABOUT', style: _kicker),
                const SizedBox(width: 6),
                Text('(optional)', style: _hint),
              ],
            ),
            Text(
              'Short memory or role in the family',
              style: _hint.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('settings-about'),
          controller: _about,
          minLines: 4,
          maxLines: 4,
          style: _field.copyWith(fontSize: 14, height: 1.45),
          decoration: _decoration,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                'Helps grandchildren and future generations know your voice.',
                style: _hint,
              ),
            ),
            Text(
              '$count / 500',
              style: _hint.copyWith(color: over ? albumTerracotta : null),
            ),
          ],
        ),
      ],
    );
  }

  Widget _emailBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ACCOUNT EMAIL', style: _kicker),
        const SizedBox(height: 6),
        TextField(
          key: const Key('settings-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.sourceSans3(
            color: const Color(0xFF58504D),
            fontSize: 14,
          ),
          decoration: _decoration.copyWith(
            fillColor: const Color(0xFFF0EAE2),
            suffixIcon: const Icon(Icons.lock_outline, size: 18),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Used for family invitations and memory updates.',
          style: _hint.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _actions() {
    return Row(
      children: [
        if (_savedNotice)
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: albumSage,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'All changes saved to album cloud',
                    style: GoogleFonts.sourceSans3(
                      color: const Color(0xFF665D5A),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          const Spacer(),
        TextButton(
          onPressed: _saving ? null : _cancel,
          child: Text(
            'Cancel',
            style: GoogleFonts.sourceSans3(
              color: const Color(0xFF665D5A),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          key: const Key('settings-save'),
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: albumTerracotta,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          ),
          icon: Icon(
            _saving ? Icons.hourglass_top : Icons.save_outlined,
            size: 16,
          ),
          label: Text(
            _saving ? 'Saving...' : 'Save',
            style: GoogleFonts.sourceSans3(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

({DateTime date, String precision})? _storedBirth(StoryDate? date) {
  if (date == null || date.legacyDecade) return null;
  return storedPersonDate(year: date.year, month: date.month, day: date.day);
}

final _kicker = GoogleFonts.sourceSans3(
  color: const Color(0xFF655E5B),
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.1,
);

final _hint = GoogleFonts.sourceSans3(
  color: const Color(0xFF655E5B),
  fontSize: 11,
);

final _field = GoogleFonts.literata(color: albumInk, fontSize: 16);

const _decoration = InputDecoration(
  filled: true,
  fillColor: albumParchment,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Color(0xFFE4D9C6)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Color(0xFFE4D9C6)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: albumTerracotta),
  ),
);
