import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/album_chrome.dart';
import '../../core/theme/album_theme.dart';
import '../../data/invite_api.dart';
import '../../data/people_api.dart';
import '../family/family_blur_dialog.dart';
import '../stories/story_date.dart';
import 'person_date_field.dart';

/// Created person, and whether the caller chose "Send invite".
class AddPersonResult {
  const AddPersonResult({required this.person, required this.sendInvite});

  final Person person;
  final bool sendInvite;
}

enum _AddPersonMode { chooseExisting, createNew }

/// Add Person modal — pick an existing family person or create one.
/// Create writes profile fields. Relationship is not collected.
class AddPersonModal extends StatefulWidget {
  const AddPersonModal({
    super.key,
    required this.familyId,
    required this.api,
    this.invites,
    this.pickImageBytes,
  });

  final String familyId;
  final PeopleGateway api;
  final InviteGateway? invites;
  final Future<Uint8List?> Function()? pickImageBytes;

  static Future<AddPersonResult?> show(
    BuildContext context, {
    required String familyId,
    required PeopleGateway api,
    InviteGateway? invites,
    Future<Uint8List?> Function()? pickImageBytes,
  }) {
    return showAlbumDialog<AddPersonResult>(
      context: context,
      maxWidth: 580,
      builder: (ctx) => AddPersonModal(
        familyId: familyId,
        api: api,
        invites: invites,
        pickImageBytes: pickImageBytes,
      ),
    );
  }

  @override
  State<AddPersonModal> createState() => _AddPersonModalState();
}

class _AddPersonModalState extends State<AddPersonModal> {
  _AddPersonMode _mode = _AddPersonMode.chooseExisting;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _aboutController = TextEditingController();
  final _searchController = TextEditingController();
  Person? _selectedPerson;
  StoryDate? _birth;
  StoryDate? _passing;
  Uint8List? _picture;

  List<Person>? _people;
  Object? _loadError;
  var _busy = false;
  String? _nameError;
  String? _aboutError;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _aboutController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    setState(() {
      _loadError = null;
      _people = null;
    });
    try {
      final people = await widget.api.listPeople(widget.familyId);
      if (!mounted) return;
      setState(() => _people = people);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  bool get _passingSet => _passing != null;

  Future<void> _pickPicture() async {
    final picker = widget.pickImageBytes ?? _pickFromGallery;
    final bytes = await picker();
    if (bytes == null || !mounted) return;
    setState(() => _picture = bytes);
  }

  Future<Uint8List?> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return file.readAsBytes();
  }

  Future<void> _saveCreate() async {
    final name = _nameController.text.trim();
    final about = _aboutController.text;
    final nameError = name.isEmpty ? 'Name is required' : null;
    final aboutError = about.length > 500
        ? 'About must be 500 characters or fewer.'
        : null;
    if (nameError != null || aboutError != null) {
      setState(() {
        _nameError = nameError;
        _aboutError = aboutError;
      });
      return;
    }
    final email = _passingSet ? '' : _emailController.text.trim();
    var sendInvite = false;
    if (email.isNotEmpty) {
      final confirmed = await showSendInviteConfirm(
        context,
        name: name,
        email: email,
      );
      if (!mounted) return;
      sendInvite = confirmed;
    }
    setState(() {
      _busy = true;
      _nameError = null;
      _aboutError = null;
    });
    try {
      final birth = _stored(_birth);
      final passing = _stored(_passing);
      final person = await widget.api.createPerson(
        familyId: widget.familyId,
        name: name,
        birthDate: birth?.date,
        birthPrecision: birth?.precision,
        passingDate: passing?.date,
        passingPrecision: passing?.precision,
        about: about,
        email: email,
        pictureBytes: _picture,
      );
      if (sendInvite) {
        final invites = widget.invites;
        if (invites != null) {
          final created = await invites.createInvite(
            familyId: widget.familyId,
            email: email,
            personId: person.id,
          );
          await invites.sendInviteEmail(inviteId: created.inviteId);
        }
      }
      if (!mounted) return;
      Navigator.of(context)
          .pop(AddPersonResult(person: person, sendInvite: sendInvite));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save person. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setMode(_AddPersonMode mode) {
    setState(() {
      _mode = mode;
      _nameError = null;
      _aboutError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final choosing = _mode == _AddPersonMode.chooseExisting;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: albumSage.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: albumSage.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.person_add,
                    size: 18,
                    color: albumSage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add person',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              height: 1.15,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add a family member to your shared archive and timeline',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: albumInk.withValues(alpha: 0.62),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  visualDensity: VisualDensity.compact,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: albumSage.withValues(alpha: 0.28), height: 1),
            const SizedBox(height: 16),
            _modeToggle(),
            const SizedBox(height: 16),
            if (choosing) _buildPickList() else _buildCreateForm(),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFEAE1D3)),
            const SizedBox(height: 12),
            _footer(choosing),
          ],
        ),
      ),
    );
  }

  Widget _modeToggle() {
    final count = _people?.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDE6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7DECE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _modeButton(
              mode: _AddPersonMode.chooseExisting,
              icon: Icons.group_outlined,
              label: 'Choose existing',
              badge: count == null ? null : '$count',
            ),
            _modeButton(
              mode: _AddPersonMode.createNew,
              icon: Icons.person_add,
              label: 'Create new person',
              solid: true,
              plus: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeButton({
    required _AddPersonMode mode,
    required IconData icon,
    required String label,
    String? badge,
    bool solid = false,
    bool plus = false,
  }) {
    final selected = _mode == mode;
    final Color background;
    final Color foreground;
    final Color iconColor;
    final BorderSide side;
    if (selected && solid) {
      background = albumTerracotta;
      foreground = Colors.white;
      iconColor = Colors.white;
      side = BorderSide.none;
    } else if (selected) {
      background = const Color(0xFFFAF5EE);
      foreground = const Color(0xFF37312F);
      iconColor = albumTerracotta;
      side = const BorderSide(color: Color(0xFFE8DFC8));
    } else {
      background = Colors.transparent;
      foreground = const Color(0xFF6B5E55);
      iconColor = const Color(0xFF6B5E55);
      side = BorderSide.none;
    }
    return Expanded(
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: side,
        ),
        child: InkWell(
          onTap: _busy ? null : () => _setMode(mode),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (plus)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: PlusLabel(
                        label: label,
                        size: 16,
                        onTerracotta: selected && solid,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 13,
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                else ...[
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 13,
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? albumTerracotta.withValues(alpha: 0.15)
                          : const Color(0x99D6D3D1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      child: Text(
                        badge,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected
                              ? albumTerracotta
                              : const Color(0xFF6B5E55),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer(bool choosing) {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final cancel = OutlinedButton(
      onPressed: _busy ? null : () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: albumInk.withValues(alpha: 0.7),
        side: const BorderSide(color: Color(0xFFDCD3C4)),
        shape: buttonShape,
      ),
      child: const Text('Cancel'),
    );
    return Row(
      children: [
        cancel,
        const Spacer(),
        if (choosing)
          FilledButton.icon(
            onPressed: _busy || _selectedPerson == null
                ? null
                : () => Navigator.of(context).pop(
                    AddPersonResult(
                      person: _selectedPerson!,
                      sendInvite: false,
                    ),
                  ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: albumTerracotta,
              foregroundColor: Colors.white,
              disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.35),
              shape: buttonShape,
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Add to story'),
          )
        else
          FilledButton(
            onPressed: _busy ? null : _saveCreate,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: albumTerracotta,
              foregroundColor: Colors.white,
              disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.35),
              shape: buttonShape,
              padding: const EdgeInsets.symmetric(horizontal: 28),
            ),
            child: PlusLabel(
              label: _busy ? 'Adding…' : 'Add person',
              onTerracotta: true,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _buildPickList() {
    if (_loadError != null) {
      return Column(
        children: [
          const Text('Couldn’t load people. Try again.'),
          TextButton(onPressed: _loadPeople, child: const Text('Try again')),
        ],
      );
    }
    final people = _people;
    if (people == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (people.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No people yet. Create a new person.'),
      );
    }
    final query = _searchController.text.trim().toLowerCase();
    final shown = query.isEmpty
        ? people
        : people
              .where(
                (person) =>
                    person.name.toLowerCase().contains(query) ||
                    (person.relationship ?? '').toLowerCase().contains(query),
              )
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'SELECT FAMILY MEMBER',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(letterSpacing: 0.6, fontWeight: FontWeight.w600),
            ),
            Text(
              ' *',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: albumTerracotta,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              'Choose one to tag',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: albumInk.withValues(alpha: 0.55)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          enabled: !_busy,
          decoration: InputDecoration(
            hintText: 'Search family members…',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: _fieldBorder(),
            enabledBorder: _fieldBorder(),
            focusedBorder: _fieldBorder(color: albumTerracotta, width: 1.5),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No people match that search.'),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: shown.length,
              itemBuilder: (context, index) {
                final person = shown[index];
                final selected = _selectedPerson?.id == person.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selected ? const Color(0xFFFAF5EE) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: selected
                            ? albumTerracotta
                            : const Color(0xFFE7DECE),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: selected
                            ? albumTerracotta
                            : const Color(0xFFF3EDE6),
                        foregroundColor: selected
                            ? Colors.white
                            : const Color(0xFF554942),
                        child: Text(
                          _initials(person.name),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF554942),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      title: Text(
                        person.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 16),
                      ),
                      subtitle: Text(
                        person.relationship ?? '',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: albumInk.withValues(alpha: 0.55)),
                      ),
                      trailing: selected
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: albumTerracotta,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Selected',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: albumTerracotta,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            )
                          : Text(
                              'Select',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: albumInk.withValues(alpha: 0.55),
                                  ),
                            ),
                      onTap: _busy
                          ? null
                          : () => setState(() => _selectedPerson = person),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  OutlineInputBorder _fieldBorder({
    Color color = const Color(0xFFDCD3C4),
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.map((part) => part[0].toUpperCase()).join();
  }

  TextStyle? _kicker(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
      letterSpacing: 1.1,
      fontWeight: FontWeight.w700,
      color: albumInk.withValues(alpha: 0.55),
    );
  }

  Widget _buildCreateForm() {
    final kicker = _kicker(context);
    final hint = albumInk.withValues(alpha: 0.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('NAME', style: kicker),
            Text(
              ' *',
              style: kicker?.copyWith(color: albumTerracotta, letterSpacing: 0),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('add-person-name'),
          controller: _nameController,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Thomas Jenkins or Aunt Clara',
            errorText: _nameError,
          ),
        ),
        const SizedBox(height: 16),
        PersonDateField(
          key: const Key('add-person-birth'),
          label: 'Date of birth',
          framed: true,
          icon: Icons.cake_outlined,
          iconColor: albumSage,
          onChanged: (date) => _birth = date,
        ),
        const SizedBox(height: 16),
        PersonDateField(
          key: const Key('add-person-passing'),
          label: 'Date of passing',
          framed: true,
          icon: Icons.hourglass_bottom_outlined,
          iconColor: albumInk.withValues(alpha: 0.45),
          onChanged: (date) => setState(() => _passing = date),
        ),
        const SizedBox(height: 16),
        Text('PICTURE', style: kicker),
        const SizedBox(height: 6),
        _pictureRow(),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('ABOUT', style: kicker),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Short memory or role in the family',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: hint,
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _AddAboutField(
          controller: _aboutController,
          enabled: !_busy,
          errorText: _aboutError,
        ),
        if (!_passingSet) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text('EMAIL', style: kicker),
              const SizedBox(width: 6),
              Text(
                '(optional)',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: hint, fontSize: 11, letterSpacing: 0),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            key: const Key('add-person-email'),
            controller: _emailController,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'name@example.com'),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 15, color: albumSage),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Email is hidden when Date of passing is set.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: albumSage,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _pictureRow() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1EA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7DECE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _pictureMark(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    key: const Key('add-person-picture'),
                    onPressed: _busy ? null : _pickPicture,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: albumInk,
                      backgroundColor: const Color(0xFFF3EDE6),
                      side: const BorderSide(color: Color(0xFFDCD3C4)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(
                      Icons.photo_camera_outlined,
                      size: 14,
                      color: albumTerracotta,
                    ),
                    label: const Text(
                      'Upload picture',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Square JPG, PNG, or HEIC portrait. Recommended 400×400px.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: albumInk.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pictureMark() {
    final bytes = _picture;
    return SizedBox(
      width: 52,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            painter: const _DashedCirclePainter(),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFF3EDE6),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: bytes == null
                    ? const Icon(
                        Icons.account_circle,
                        size: 28,
                        color: Color(0xB38B5E4B),
                      )
                    : Image.memory(
                        bytes,
                        key: const Key('add-person-picture-preview'),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: albumTerracotta,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 11, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-line About field. The corner grip changes the height.
class _AddAboutField extends StatefulWidget {
  const _AddAboutField({
    required this.controller,
    required this.enabled,
    this.errorText,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? errorText;

  @override
  State<_AddAboutField> createState() => _AddAboutFieldState();
}

class _AddAboutFieldState extends State<_AddAboutField> {
  double? _height;

  double _minHeight(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ay\nAy', style: style),
      textDirection: Directionality.of(context),
      maxLines: 2,
    )..layout();
    return painter.height + 28;
  }

  @override
  Widget build(BuildContext context) {
    final style =
        Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16, height: 1.4);
    final min = _minHeight(style);
    final height = _height ?? min;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const Key('add-person-about-box'),
          height: height,
          child: Stack(
            children: [
              TextField(
                key: const Key('add-person-about'),
                controller: widget.controller,
                enabled: widget.enabled,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: style,
                decoration: const InputDecoration(
                  hintText: 'Write a brief blurb about who they are, memories they are known for, or how they connect to the family...',
                  hintMaxLines: 2,
                  contentPadding: EdgeInsets.fromLTRB(12, 10, 22, 14),
                ),
              ),
              Positioned(
                right: 1,
                bottom: 1,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpLeftDownRight,
                  child: GestureDetector(
                    key: const Key('add-person-about-resize'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        _height = (height + details.delta.dy).clamp(min, 360);
                      });
                    },
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CustomPaint(painter: _AddResizeGripPainter()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _AddResizeGripPainter extends CustomPainter {
  const _AddResizeGripPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8A7E70)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final inset = 3.0 + i * 4;
      canvas.drawLine(
        Offset(size.width - 2, inset),
        Offset(inset, size.height - 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = albumTerracotta.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final oval = Path()..addOval(Rect.fromLTWH(1, 1, 46, 46));
    for (final metric in oval.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

({DateTime date, String precision})? _stored(StoryDate? date) {
  if (date == null || date.legacyDecade) return null;
  return storedPersonDate(year: date.year, month: date.month, day: date.day);
}
