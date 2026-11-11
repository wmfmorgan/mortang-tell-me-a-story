import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_chrome.dart';
import 'package:tell_me_a_story/core/widgets/dialogs/family_blur_dialog.dart';
import 'package:tell_me_a_story/features/people/presentation/people_providers.dart';

/// People added from this modal, and whether the caller chose "Send invite".
class AddPersonResult {
  const AddPersonResult({required this.people, required this.sendInvite});

  final List<Person> people;
  final bool sendInvite;

  Person get person => people.first;
}

/// Add Person modal. Create writes profile fields. Relationship is not collected.
///
/// With a non-empty [storyId], each chosen person is linked to that story.
class AddPersonModal extends ConsumerStatefulWidget {
  const AddPersonModal({
    super.key,
    required this.familyId,
    this.pickImageBytes,
    this.storyId,
    this.linkedPersonIds = const {},
  });

  final String familyId;
  final Future<Uint8List?> Function()? pickImageBytes;
  final String? storyId;
  final Set<String> linkedPersonIds;

  static Future<AddPersonResult?> show(
    BuildContext context, {
    required String familyId,
    Future<Uint8List?> Function()? pickImageBytes,
    String? storyId,
    Set<String> linkedPersonIds = const {},
  }) {
    return showAlbumDialog<AddPersonResult>(
      context: context,
      // Errors keep the modal open; show them above its blur (UX-13).
      scopedMessages: true,
      maxWidth: 580,
      builder: (ctx) => AddPersonModal(
        familyId: familyId,
        pickImageBytes: pickImageBytes,
        storyId: storyId,
        linkedPersonIds: linkedPersonIds,
      ),
    );
  }

  @override
  ConsumerState<AddPersonModal> createState() => _AddPersonModalState();
}

enum _AddStep { pick, form }

class _AddPersonModalState extends ConsumerState<AddPersonModal> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _aboutController = TextEditingController();
  final _searchController = TextEditingController();
  var _passedAway = false;
  Uint8List? _picture;
  var _step = _AddStep.pick;
  Person? _created;
  var _sendInvite = false;
  var _inviteSent = false;

  var _busy = false;
  final Set<String> _selectedIds = <String>{};
  final List<Person> _saved = [];
  String? _nameError;
  String? _aboutError;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<List<Person>>>(
      treePeopleProvider(widget.familyId),
      (previous, next) {
        if (next case AsyncError(:final error)) _showSaveError(error);
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _aboutController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  static const _saveFailed = 'Couldn’t save person. Try again.';

  void _showSaveError(Object error) {
    _snack(appErrorMessage(error) ?? _saveFailed);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _formLocked => _busy || _created != null;

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

  /// False when the form is invalid; sets the field errors.
  bool _validate() {
    final about = _aboutController.text;
    final nameError = _nameController.text.trim().isEmpty
        ? 'Name is required'
        : null;
    final aboutError = about.length > 500
        ? 'About must be 500 characters or fewer.'
        : null;
    if (nameError == null && aboutError == null) return true;
    setState(() {
      _nameError = nameError;
      _aboutError = aboutError;
    });
    return false;
  }

  Future<void> _saveCreate() async {
    if (_created == null) {
      if (!_validate()) return;
      final email = _emailController.text.trim();
      if (email.isNotEmpty && !_passedAway) {
        final confirmed = await showSendInviteConfirm(
          context,
          name: _nameController.text.trim(),
          email: email,
        );
        if (!mounted) return;
        _sendInvite = confirmed;
      }
    }
    setState(() {
      _busy = true;
      _nameError = null;
      _aboutError = null;
    });
    try {
      await _createAndFinish();
    } catch (error) {
      if (!mounted) return;
      _showSaveError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createAndFinish() async {
    final email = _emailController.text.trim();
    final person = _created ??= await ref
        .read(peopleRepositoryProvider)
        .createPerson(
          familyId: widget.familyId,
          name: _nameController.text.trim(),
          about: _aboutController.text,
          email: email,
          passedAway: _passedAway,
          pictureBytes: _picture,
        );
    if (_sendInvite && !_inviteSent) {
      if (!await _invite(email, person)) return;
      _inviteSent = true;
    }
    if (!mounted) return;
    final linkError = await _linkEach([person]);
    if (!mounted) return;
    if (linkError != null) {
      _showSaveError(linkError);
      return;
    }
    Navigator.of(context).pop(
      AddPersonResult(people: [..._saved, person], sendInvite: _sendInvite),
    );
  }

  /// Sends the invite for [person]. False when it failed (already shown).
  Future<bool> _invite(String email, Person person) async {
    final invites = ref.read(inviteRepositoryProvider);
    try {
      final created = await invites.createInvite(
        familyId: widget.familyId,
        email: email,
        personId: person.id,
      );
      await invites.sendInviteEmail(
        inviteId: created.inviteId,
        token: created.token,
      );
      return true;
    } on AppException {
      // The person row is saved; invite failures keep the save sentence.
      if (mounted) _snack(_saveFailed);
      return false;
    }
  }

  void _toggle(Person person) {
    if (_busy) return;
    setState(() {
      if (!_selectedIds.add(person.id)) {
        _selectedIds.remove(person.id);
      }
    });
  }

  Future<Object?> _linkEach(List<Person> people) async {
    Object? firstError;
    final storyId = widget.storyId;
    final canWrite = storyId != null && storyId.isNotEmpty;
    final stories = ref.read(storiesRepositoryProvider);
    for (final person in people) {
      if (widget.linkedPersonIds.contains(person.id)) continue;
      if (_saved.any((saved) => saved.id == person.id)) continue;
      final selected = _selectedIds.contains(person.id);
      try {
        if (canWrite) {
          await stories.linkPerson(storyId: storyId, personId: person.id);
        }
        if (selected) {
          _saved.add(person);
          _selectedIds.remove(person.id);
        }
      } catch (error) {
        // Reported once by the caller through _showSaveError.
        firstError ??= error;
      }
    }
    if (mounted) setState(() {});
    return firstError;
  }

  Future<void> _addSelected() async {
    if (_busy || _selectedIds.isEmpty) return;
    setState(() => _busy = true);
    try {
      final people =
          ref.read(treePeopleProvider(widget.familyId)).value ??
          const <Person>[];
      final byId = {for (final person in people) person.id: person};
      final selected = <Person>[for (final id in _selectedIds) ?byId[id]];
      final error = await _linkEach(selected);
      if (!mounted) return;
      if (error != null) {
        _showSaveError(error);
        return;
      }
      Navigator.of(context)
          .pop(AddPersonResult(people: List.of(_saved), sendInvite: false));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _close() {
    if (_saved.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context)
        .pop(AddPersonResult(people: List.of(_saved), sendInvite: false));
  }

  void _openCreate() {
    _nameController.text = _searchController.text;
    _nameController.selection = TextSelection.collapsed(
      offset: _nameController.text.length,
    );
    setState(() {
      _step = _AddStep.form;
      _nameError = null;
      _selectedIds.clear();
    });
  }

  /// Null while loading; empty after a failed load (the error is shown).
  List<Person>? _loadedPeople() {
    return switch (ref.watch(treePeopleProvider(widget.familyId))) {
      AsyncData(:final value) => value,
      AsyncError() => const [],
      AsyncLoading() => null,
    };
  }

  List<Person> _visiblePeople(List<Person>? people) {
    if (people == null) return const [];
    final query = _searchController.text.trim().toLowerCase();
    final linked = widget.linkedPersonIds;
    final savedIds = {for (final person in _saved) person.id};
    final rows = [
      for (final person in people)
        if (!linked.contains(person.id) &&
            !savedIds.contains(person.id) &&
            (query.isEmpty || person.name.toLowerCase().contains(query)))
          person,
    ];
    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onClose = _busy ? null : _close;
    if (_step == _AddStep.form) {
      return _ModalFrame(
        busy: _busy,
        onClose: onClose,
        onPrimary: _busy ? null : _saveCreate,
        body: _CreateForm(
          nameController: _nameController,
          aboutController: _aboutController,
          emailController: _emailController,
          locked: _formLocked,
          nameError: _nameError,
          aboutError: _aboutError,
          passedAway: _passedAway,
          picture: _picture,
          onPickPicture: _pickPicture,
          onPassedAway: (value) => setState(() => _passedAway = value),
        ),
      );
    }
    final loaded = _loadedPeople();
    return _ModalFrame(
      busy: _busy,
      onClose: onClose,
      onPrimary: _busy || _selectedIds.isEmpty ? null : _addSelected,
      body: _Picker(
        searchController: _searchController,
        busy: _busy,
        loading: loaded == null,
        people: _visiblePeople(loaded),
        selectedIds: _selectedIds,
        onSearchChanged: () => setState(() {}),
        onToggle: _toggle,
        onCreate: _openCreate,
      ),
    );
  }
}

class _ModalFrame extends StatelessWidget {
  const _ModalFrame({
    required this.busy,
    required this.onClose,
    required this.onPrimary,
    required this.body,
  });

  final bool busy;
  final VoidCallback? onClose;
  final VoidCallback? onPrimary;
  final Widget body;

  @override
  Widget build(BuildContext context) {
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
            _Header(onClose: onClose),
            const SizedBox(height: 12),
            Divider(color: albumSage.withValues(alpha: 0.28), height: 1),
            const SizedBox(height: 16),
            body,
            const SizedBox(height: 16),
            Divider(height: 1, color: albumSage.withValues(alpha: 0.45)),
            const SizedBox(height: 12),
            _Footer(busy: busy, onClose: onClose, onPrimary: onPrimary),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HeaderMark(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add person',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          visualDensity: VisualDensity.compact,
          onPressed: onClose,
          icon: const Icon(Icons.close, size: 20),
        ),
      ],
    );
  }
}

class _HeaderMark extends StatelessWidget {
  const _HeaderMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: albumSage.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: albumSage.withValues(alpha: 0.35)),
      ),
      child: const Icon(Icons.person_add, size: 18, color: albumSage),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.busy,
    required this.onClose,
    required this.onPrimary,
  });

  final bool busy;
  final VoidCallback? onClose;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton(
          onPressed: onClose,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            foregroundColor: albumInk.withValues(alpha: 0.7),
            side: BorderSide(color: albumSage.withValues(alpha: 0.45)),
            shape: _footerButtonShape,
          ),
          child: const Text('Cancel'),
        ),
        const Spacer(),
        _PrimaryButton(busy: busy, onPressed: onPrimary),
      ],
    );
  }
}

final _footerButtonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(12),
);

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: albumTerracotta,
        foregroundColor: albumParchment,
        disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.35),
        shape: _footerButtonShape,
        padding: const EdgeInsets.symmetric(horizontal: 28),
      ),
      child: PlusLabel(
        label: busy ? 'Adding…' : 'Add person',
        onTerracotta: true,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: albumParchment, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.searchController,
    required this.busy,
    required this.loading,
    required this.people,
    required this.selectedIds,
    required this.onSearchChanged,
    required this.onToggle,
    required this.onCreate,
  });

  final TextEditingController searchController;
  final bool busy;
  final bool loading;
  final List<Person> people;
  final Set<String> selectedIds;
  final VoidCallback onSearchChanged;
  final ValueChanged<Person> onToggle;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('add-person-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Search people in this family',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('add-person-search'),
          controller: searchController,
          enabled: !busy,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, color: albumInk),
            filled: true,
            fillColor: albumParchment,
            isDense: true,
          ),
          onChanged: (_) => onSearchChanged(),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (people.isNotEmpty)
          _PickerList(
            people: people,
            selectedIds: selectedIds,
            onToggle: busy ? null : onToggle,
          ),
        _CreateRow(onTap: busy ? null : onCreate),
      ],
    );
  }
}

class _PickerList extends StatelessWidget {
  const _PickerList({
    required this.people,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<Person> people;
  final Set<String> selectedIds;

  /// Null while busy, which disables every row.
  final ValueChanged<Person>? onToggle;

  @override
  Widget build(BuildContext context) {
    final toggle = onToggle;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _pickerListMaxHeight),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: people.length,
        itemBuilder: (context, index) => _PersonRow(
          person: people[index],
          selected: selectedIds.contains(people[index].id),
          onTap: toggle == null ? null : () => toggle(people[index]),
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final Person person;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected ? albumSage.withValues(alpha: 0.18) : albumParchment,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? albumSage : albumSage.withValues(alpha: 0.45),
            ),
          ),
          child: InkWell(
            key: Key('add-person-pick-${person.id}'),
            hoverColor: albumSage.withValues(alpha: 0.12),
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: _PersonRowContent(person: person, selected: selected),
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonRowContent extends StatelessWidget {
  const _PersonRowContent({required this.person, required this.selected});

  final Person person;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final years = _yearSpan(person);
    final theme = Theme.of(context).textTheme;
    return Row(
      children: [
        _PersonMark(name: person.name, selected: selected),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            person.name,
            style: theme.titleMedium?.copyWith(fontSize: 16),
          ),
        ),
        if (years.isNotEmpty)
          Text(
            years,
            style: theme.labelSmall?.copyWith(
              color: albumInk.withValues(alpha: 0.55),
            ),
          ),
      ],
    );
  }
}

class _PersonMark extends StatelessWidget {
  const _PersonMark({required this.name, required this.selected});

  final String name;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: albumSage.withValues(alpha: 0.18),
      foregroundColor: albumInk,
      child: selected
          ? const Icon(Icons.check, size: 18, color: albumInk)
          : Text(
              _initials(name),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: albumInk, fontWeight: FontWeight.w700),
            ),
    );
  }
}

class _CreateRow extends StatelessWidget {
  const _CreateRow({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedOutlinePainter(_DashShape.rrect),
      child: InkWell(
        key: const Key('add-person-create'),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text('Create new person'),
        ),
      ),
    );
  }
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

class _CreateForm extends StatelessWidget {
  const _CreateForm({
    required this.nameController,
    required this.aboutController,
    required this.emailController,
    required this.locked,
    required this.nameError,
    required this.aboutError,
    required this.passedAway,
    required this.picture,
    required this.onPickPicture,
    required this.onPassedAway,
  });

  final TextEditingController nameController;
  final TextEditingController aboutController;
  final TextEditingController emailController;
  final bool locked;
  final String? nameError;
  final String? aboutError;
  final bool passedAway;
  final Uint8List? picture;
  final VoidCallback onPickPicture;
  final ValueChanged<bool> onPassedAway;

  @override
  Widget build(BuildContext context) {
    final kicker = _kicker(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('PICTURE', style: kicker),
        const SizedBox(height: 6),
        _PictureRow(picture: picture, onPick: locked ? null : onPickPicture),
        const SizedBox(height: 16),
        _RequiredKicker(label: 'NAME', style: kicker),
        const SizedBox(height: 6),
        TextField(
          key: const Key('add-person-name'),
          controller: nameController,
          enabled: !locked,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Thomas Jenkins or Aunt Clara',
            errorText: nameError,
          ),
        ),
        const SizedBox(height: 16),
        Text('ABOUT', style: kicker),
        const SizedBox(height: 6),
        _AddAboutField(
          controller: aboutController,
          enabled: !locked,
          errorText: aboutError,
        ),
        const SizedBox(height: 16),
        _EmailAndPassedAway(
          emailController: emailController,
          locked: locked,
          passedAway: passedAway,
          onPassedAway: onPassedAway,
        ),
      ],
    );
  }
}

class _EmailAndPassedAway extends StatelessWidget {
  const _EmailAndPassedAway({
    required this.emailController,
    required this.locked,
    required this.passedAway,
    required this.onPassedAway,
  });

  final TextEditingController emailController;
  final bool locked;
  final bool passedAway;
  final ValueChanged<bool> onPassedAway;

  @override
  Widget build(BuildContext context) {
    final kicker = _kicker(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('EMAIL', style: kicker),
        const SizedBox(height: 6),
        TextField(
          key: const Key('add-person-email'),
          controller: emailController,
          enabled: !locked,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'name@example.com'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Text('Passed away', style: kicker)),
            Switch(
              key: const Key('add-person-passed-away'),
              value: passedAway,
              onChanged: locked ? null : onPassedAway,
            ),
          ],
        ),
      ],
    );
  }
}

class _RequiredKicker extends StatelessWidget {
  const _RequiredKicker({required this.label, required this.style});

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: style),
        Text(
          ' *',
          style: style?.copyWith(color: albumTerracotta, letterSpacing: 0),
        ),
      ],
    );
  }
}

class _PictureRow extends StatelessWidget {
  const _PictureRow({required this.picture, required this.onPick});

  final Uint8List? picture;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumParchment,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: albumSage.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _PictureMark(bytes: picture),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_UploadButton(onPressed: onPick)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('add-person-picture'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: albumInk,
        backgroundColor: albumParchment,
        side: BorderSide(color: albumSage.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _PictureMark extends StatelessWidget {
  const _PictureMark({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final picture = bytes;
    return SizedBox(
      width: 52,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            painter: const _DashedOutlinePainter(_DashShape.circle),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: albumParchment,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: picture == null
                    ? Icon(
                        Icons.account_circle,
                        size: 28,
                        color: albumTerracotta.withValues(alpha: 0.70),
                      )
                    : Image.memory(
                        picture,
                        key: const Key('add-person-picture-preview'),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          const Positioned(right: 0, bottom: 0, child: _PlusBadge()),
        ],
      ),
    );
  }
}

class _PlusBadge extends StatelessWidget {
  const _PlusBadge();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 16,
        height: 16,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: albumTerracotta,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, size: 11, color: albumParchment),
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
              _AboutTextField(
                controller: widget.controller,
                enabled: widget.enabled,
                style: style,
              ),
              Positioned(
                right: 1,
                bottom: 1,
                child: _AboutResizeGrip(
                  onDrag: (dy) => setState(() {
                    _height = (height + dy).clamp(min, 360);
                  }),
                ),
              ),
            ],
          ),
        ),
        if (widget.errorText case final errorText?) ...[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _AboutTextField extends StatelessWidget {
  const _AboutTextField({
    required this.controller,
    required this.enabled,
    required this.style,
  });

  final TextEditingController controller;
  final bool enabled;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('add-person-about'),
      controller: controller,
      enabled: enabled,
      expands: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      style: style,
      decoration: const InputDecoration(
        hintText: 'Write a brief blurb about who they are, memories they are known for, or how they connect to the family...',
        hintMaxLines: 2,
        contentPadding: EdgeInsets.fromLTRB(12, 10, 22, 14),
      ),
    );
  }
}

class _AboutResizeGrip extends StatelessWidget {
  const _AboutResizeGrip({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpLeftDownRight,
      child: GestureDetector(
        key: const Key('add-person-about-resize'),
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CustomPaint(painter: _AddResizeGripPainter()),
        ),
      ),
    );
  }
}

class _AddResizeGripPainter extends CustomPainter {
  const _AddResizeGripPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = albumInk
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

const _pickerListMaxHeight = 220.0;

enum _DashShape { circle, rrect }

class _DashedOutlinePainter extends CustomPainter {
  const _DashedOutlinePainter(this.shape);

  final _DashShape shape;

  static const circleDash = 4.0;
  static const circleGap = 3.0;
  static const rrectDash = 5.0;
  static const rrectGap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final circle = shape == _DashShape.circle;
    final paint = Paint()
      ..color = circle ? albumTerracotta.withValues(alpha: 0.4) : albumSage
      ..style = PaintingStyle.stroke
      ..strokeWidth = circle ? 1.5 : 1.2;
    final path = Path();
    if (circle) {
      path.addOval(const Rect.fromLTWH(1, 1, 46, 46));
    } else {
      path.addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    }
    final dash = circle ? circleDash : rrectDash;
    final step = dash + (circle ? circleGap : rrectGap);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += step;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedOutlinePainter oldDelegate) =>
      oldDelegate.shape != shape;
}

String _yearSpan(Person person) {
  final birth = person.birthDate?.year;
  if (birth == null) return '';
  return '$birth';
}
