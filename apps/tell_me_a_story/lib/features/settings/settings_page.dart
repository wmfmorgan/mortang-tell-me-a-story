import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/album_chrome.dart';
import '../../core/theme/album_header.dart';
import '../../core/theme/album_theme.dart';
import '../../core/theme/profile_avatar.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/invite_api.dart';
import '../../data/profile_api.dart';
import '../../data/profile_session.dart';
import '../invites/invite_modal.dart';

/// Signed-in profile at `/settings`. Name, email, a picture, and one Save.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.profileApi,
    this.familiesApi,
    this.inviteApi,
    this.onLogout,
    this.pickImageBytes,
  });

  final ProfileGateway? profileApi;
  final FamiliesGateway? familiesApi;
  final InviteGateway? inviteApi;
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

  var _loading = true;
  var _saving = false;
  String? _storedEmail;
  String? _familyId;
  String? _displayName;
  Uint8List? _savedBytes;
  Uint8List? _pending;
  List<MemberFamily> _families = const [];
  List<StewardFamily> _stewarded = const [];

  @override
  void initState() {
    super.initState();
    _profile = widget.profileApi ?? ProfileApi();
    _invite = widget.inviteApi ?? InviteApi();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await _profile.loadOwn();
      if (!mounted) return;
      final email = profile?.email ?? '';
      _name.text = profile?.displayName ?? '';
      _email.text = email;
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
    try {
      _familyId ??= await _invite.currentFamilyId();
      if (widget.familiesApi != null) {
        rows = await widget.familiesApi!.listMine();
        stewarded = await widget.familiesApi!.listStewarded();
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
      }
    } catch (_) {
      rows = const [];
      stewarded = const [];
    }
    if (!mounted) return;
    setState(() {
      _families = rows;
      _stewarded = stewarded;
    });
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
    );
  }

  Future<void> _pick() async {
    final picker = widget.pickImageBytes ?? _pickFromGallery;
    final bytes = await picker();
    if (bytes == null || !mounted) return;
    setState(() => _pending = bytes);
  }

  Future<Uint8List?> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return file.readAsBytes();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    var nameSaved = false;
    try {
      await _profile.saveName(name);
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
      final typed = _email.text.trim();
      final stored = _storedEmail ?? '';
      if (typed.isEmpty) {
        _email.text = stored;
      } else if (typed != stored) {
        await _profile.updateEmail(typed);
        _email.text = stored;
      }
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _pending ?? _savedBytes;
    return Scaffold(
      backgroundColor: albumParchment,
      appBar: AlbumHeader(
        page: AlbumHeaderPage.settings,
        familyName: _familyName,
        families: _families,
        currentFamilyId: _familyId,
        onFamilySelected: _selectFamily,
        stewarded: _stewarded,
        onInvite: _openInvite,
        onLogout: widget.onLogout,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : AlbumColumn(
                maxWidth: 672,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                  children: [
                    Text('Name', style: _label),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('settings-name'),
                      controller: _name,
                      style: _field,
                      decoration: _decoration,
                    ),
                    const SizedBox(height: 24),
                    Text('Email', style: _label),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('settings-email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: _field,
                      decoration: _decoration,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        ProfileAvatar(
                          size: 80,
                          displayName: _displayName,
                          bytes: preview,
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          key: const Key('settings-upload'),
                          onPressed: _pick,
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 18,
                          ),
                          label: const Text('Upload picture'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        key: const Key('settings-save'),
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: albumTerracotta,
                          foregroundColor: albumParchment,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          'Save',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
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

final _label = GoogleFonts.sourceSans3(
  color: albumInk,
  fontSize: 12,
  fontWeight: FontWeight.w600,
);

final _field = GoogleFonts.sourceSans3(color: albumInk, fontSize: 16);

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
