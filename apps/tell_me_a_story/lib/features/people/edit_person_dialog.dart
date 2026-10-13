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

/// Edit person. The gate is [Person.userId] from the people row.
Future<Person?> showEditPersonDialog(
  BuildContext context, {
  required Person person,
  required PeopleGateway people,
  InviteGateway? invites,
  String? signedInUserId,
  Future<Uint8List?> Function()? pickImageBytes,
}) {
  final userId = person.userId;
  if (userId != null && userId != signedInUserId) return Future.value();
  return showAlbumDialog<Person>(
    context: context,
    maxWidth: 560,
    builder: (ctx) => EditPersonDialog(
      person: person,
      people: people,
      invites: invites,
      signedInUserId: signedInUserId,
      pickImageBytes: pickImageBytes,
    ),
  );
}

class EditPersonDialog extends StatefulWidget {
  const EditPersonDialog({
    super.key,
    required this.person,
    required this.people,
    this.invites,
    this.signedInUserId,
    this.pickImageBytes,
  });

  final Person person;
  final PeopleGateway people;
  final InviteGateway? invites;
  final String? signedInUserId;
  final Future<Uint8List?> Function()? pickImageBytes;

  @override
  State<EditPersonDialog> createState() => _EditPersonDialogState();
}

class _EditPersonDialogState extends State<EditPersonDialog> {
  late final TextEditingController _name;
  late final TextEditingController _about;
  late final TextEditingController _email;
  StoryDate? _birth;
  StoryDate? _passing;
  Uint8List? _picture;
  var _busy = false;
  String? _aboutError;

  bool get _self =>
      widget.person.userId != null &&
      widget.person.userId == widget.signedInUserId;

  bool get _passingSet => _passing != null;

  @override
  void initState() {
    super.initState();
    final person = widget.person;
    _name = TextEditingController(text: person.name);
    _about = TextEditingController(text: person.about ?? '');
    _email = TextEditingController(text: person.email ?? '');
    _birth = storyDateFromPerson(person.birthDate, person.birthPrecision);
    _passing = storyDateFromPerson(person.passingDate, person.passingPrecision);
  }

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
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

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final about = _about.text;
    if (!_self && about.length > 500) {
      setState(() => _aboutError = 'About must be 500 characters or fewer.');
      return;
    }
    final email = _email.text.trim();
    final emailChanged =
        !_self && !_passingSet && email.isNotEmpty && email != (widget.person.email ?? '');
    var sendInvite = false;
    if (emailChanged) {
      final confirmed = await showFamilyBlurDialog(
        context,
        dialogKey: const Key('send-invite-confirm'),
        title: 'Send invite to $name?',
        confirmLabel: 'Send invite',
        confirmKey: const Key('send-invite-confirm-yes'),
        confirmColor: albumTerracotta,
        cancelLabel: 'Not now',
        cancelKey: const Key('send-invite-confirm-no'),
      );
      if (!mounted) return;
      sendInvite = confirmed;
    }
    setState(() => _busy = true);
    try {
      final birth = _self ? null : _stored(_birth);
      final passing = _stored(_passing);
      final person = await widget.people.updatePerson(
        personId: widget.person.id,
        name: name,
        birthDate: birth?.date,
        birthPrecision: birth?.precision,
        writeBirth: !_self,
        passingDate: passing?.date,
        passingPrecision: passing?.precision,
        writePassing: true,
        about: _self ? null : about,
        writeAbout: !_self,
        email: _passingSet ? null : email,
        writeEmail: !_self && !_passingSet,
        pictureBytes: _self ? null : _picture,
      );
      if (sendInvite) {
        final invites = widget.invites;
        if (invites != null) {
          final created = await invites.createInvite(
            familyId: person.familyId,
            email: email,
            personId: person.id,
          );
          await invites.sendInviteEmail(inviteId: created.inviteId);
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(person);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save person. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('edit-person-dialog'),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const Text('Name'),
            const SizedBox(height: 8),
            TextField(
              key: const Key('edit-person-name'),
              controller: _name,
              decoration: const InputDecoration(hintText: 'Name'),
            ),
            if (!_self) ...[
              const SizedBox(height: 16),
              PersonDateField(
                key: const Key('edit-person-birth'),
                label: 'Date of birth',
                initial: _birth,
                onChanged: (date) => _birth = date,
              ),
            ],
            const SizedBox(height: 16),
            PersonDateField(
              key: const Key('edit-person-passing'),
              label: 'Date of passing',
              initial: _passing,
              onChanged: (date) => setState(() => _passing = date),
            ),
            if (!_self) ...[
              const SizedBox(height: 16),
              const Text('Picture'),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: const Key('edit-person-picture'),
                  onPressed: _busy ? null : _pick,
                  child: const Text('Picture'),
                ),
              ),
              const SizedBox(height: 16),
              const Text('About'),
              const SizedBox(height: 8),
              TextField(
                key: const Key('edit-person-about'),
                controller: _about,
                maxLines: 4,
                decoration: InputDecoration(errorText: _aboutError),
              ),
            ],
            if (!_passingSet) ...[
              const SizedBox(height: 16),
              const Text('Email'),
              const SizedBox(height: 8),
              TextField(
                key: const Key('edit-person-email'),
                controller: _email,
                readOnly: _self,
                keyboardType: TextInputType.emailAddress,
              ),
            ],
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('edit-person-save'),
                onPressed: _busy ? null : _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

({DateTime date, String precision})? _stored(StoryDate? date) {
  if (date == null || date.legacyDecade) return null;
  return storedPersonDate(year: date.year, month: date.month, day: date.day);
}
