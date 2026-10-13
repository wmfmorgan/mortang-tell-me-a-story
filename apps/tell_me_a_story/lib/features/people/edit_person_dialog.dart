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
  String? _existingUrl;
  var _removed = false;
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
    final path = person.avatarPath;
    if (path != null && path.isNotEmpty) {
      _loadExisting(path);
    }
  }

  Future<void> _loadExisting(String path) async {
    try {
      final url = await widget.people.signedPictureUrl(
        personId: widget.person.id,
        path: path,
      );
      if (!mounted || _removed || _picture != null) return;
      setState(() => _existingUrl = url);
    } catch (_) {}
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
    setState(() {
      _picture = bytes;
      _removed = false;
    });
  }

  void _remove() {
    setState(() {
      _picture = null;
      _existingUrl = null;
      _removed = true;
    });
  }

  bool get _canRemove =>
      _picture != null ||
      (!_removed && (widget.person.avatarPath ?? '').isNotEmpty);

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
        !_self &&
        !_passingSet &&
        email.isNotEmpty &&
        email != (widget.person.email ?? '');
    var sendInvite = false;
    if (emailChanged) {
      final confirmed = await showSendInviteConfirm(
        context,
        name: name,
        email: email,
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
        clearPicture: !_self && _removed && _picture == null,
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
            Row(
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
                  child: const Icon(Icons.person, size: 18, color: albumSage),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Edit person',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  key: const Key('edit-person-close'),
                  tooltip: 'Close',
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: albumSage.withValues(alpha: 0.28), height: 1),
            if (!_self) ...[const SizedBox(height: 16), _pictureRow(context)],
            const SizedBox(height: 20),
            const Text('Name'),
            const SizedBox(height: 8),
            TextField(
              key: const Key('edit-person-name'),
              controller: _name,
              decoration: const InputDecoration(hintText: 'Name'),
            ),
            if (!_self) ...[
              const SizedBox(height: 20),
              PersonDateField(
                key: const Key('edit-person-birth'),
                label: 'Date of birth',
                initial: _birth,
                onChanged: (date) => _birth = date,
              ),
            ],
            const SizedBox(height: 20),
            PersonDateField(
              key: const Key('edit-person-passing'),
              label: 'Date of passing',
              initial: _passing,
              onChanged: (date) => setState(() => _passing = date),
            ),
            if (!_self) ...[
              const SizedBox(height: 20),
              const Text('About'),
              const SizedBox(height: 8),
              _AboutField(controller: _about, errorText: _aboutError),
            ],
            if (!_passingSet) ...[
              const SizedBox(height: 20),
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
            Row(
              children: [
                TextButton(
                  key: const Key('edit-person-cancel'),
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('edit-person-save'),
                  onPressed: _busy ? null : _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pictureRow(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      letterSpacing: 1.1,
      fontWeight: FontWeight.w700,
      color: albumInk.withValues(alpha: 0.55),
    );
    final actionStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: albumTerracotta,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: albumTerracotta,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDE6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCD3C4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _avatar(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Picture', style: labelStyle),
                  const SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      TextButton(
                        key: const Key('edit-person-picture'),
                        onPressed: _busy ? null : _pick,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _canRemove ? 'Replace photo' : 'Add photo',
                          style: actionStyle,
                        ),
                      ),
                      if (_canRemove) ...[
                        Text(
                          '•',
                          style: TextStyle(
                            color: albumInk.withValues(alpha: 0.35),
                          ),
                        ),
                        TextButton(
                          key: const Key('edit-person-picture-remove'),
                          onPressed: _busy ? null : _remove,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Remove',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: albumInk.withValues(alpha: 0.55),
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: albumTerracotta.withValues(alpha: 0.45),
                width: 2,
              ),
            ),
            child: ClipOval(child: _avatarImage()),
          ),
          Positioned(
            left: 42,
            top: 42,
            child: IgnorePointer(
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: albumTerracotta,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_camera,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarImage() {
    final bytes = _picture;
    if (bytes != null) {
      return Image.memory(
        bytes,
        key: const Key('edit-person-picture-preview'),
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          key: Key('edit-person-picture-preview'),
          color: Color(0xFFE7D5C8),
        ),
      );
    }
    final url = _existingUrl;
    if (!_removed && url != null && url.isNotEmpty) {
      return Image.network(
        url,
        key: const Key('edit-person-picture-preview'),
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          key: Key('edit-person-picture-empty'),
          color: Color(0xFFF3EDE6),
        ),
      );
    }
    return const ColoredBox(
      key: Key('edit-person-picture-empty'),
      color: Colors.white,
    );
  }
}

/// Two-line About field. The corner grip changes the height.
class _AboutField extends StatefulWidget {
  const _AboutField({required this.controller, this.errorText});

  final TextEditingController controller;
  final String? errorText;

  @override
  State<_AboutField> createState() => _AboutFieldState();
}

class _AboutFieldState extends State<_AboutField> {
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
          key: const Key('edit-person-about-box'),
          height: height,
          child: Stack(
            children: [
              TextField(
                key: const Key('edit-person-about'),
                controller: widget.controller,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: style,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.fromLTRB(12, 10, 22, 14),
                ),
              ),
              Positioned(
                right: 1,
                bottom: 1,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpLeftDownRight,
                  child: GestureDetector(
                    key: const Key('edit-person-about-resize'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        _height = (height + details.delta.dy).clamp(min, 360);
                      });
                    },
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CustomPaint(painter: _ResizeGripPainter()),
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

class _ResizeGripPainter extends CustomPainter {
  const _ResizeGripPainter();

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

({DateTime date, String precision})? _stored(StoryDate? date) {
  if (date == null || date.legacyDecade) return null;
  return storedPersonDate(year: date.year, month: date.month, day: date.day);
}
