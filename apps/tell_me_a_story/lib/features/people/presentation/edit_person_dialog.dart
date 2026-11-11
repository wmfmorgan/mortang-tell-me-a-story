import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_chrome.dart';
import 'package:tell_me_a_story/core/widgets/dialogs/family_blur_dialog.dart';

/// Edit person. The gate is [Person.userId] from the people row.
Future<Person?> showEditPersonDialog(
  BuildContext context, {
  required Person person,
  String? signedInUserId,
  Future<Uint8List?> Function()? pickImageBytes,
}) {
  if (person.userId != null) return Future.value();
  return showAlbumDialog<Person>(
    context: context,
    maxWidth: 560,
    builder: (ctx) => EditPersonDialog(
      person: person,
      signedInUserId: signedInUserId,
      pickImageBytes: pickImageBytes,
    ),
  );
}

class EditPersonDialog extends ConsumerStatefulWidget {
  const EditPersonDialog({
    super.key,
    required this.person,
    this.signedInUserId,
    this.pickImageBytes,
  });

  final Person person;
  final String? signedInUserId;
  final Future<Uint8List?> Function()? pickImageBytes;

  @override
  ConsumerState<EditPersonDialog> createState() => _EditPersonDialogState();
}

class _EditPersonDialogState extends ConsumerState<EditPersonDialog> {
  late final TextEditingController _name;
  late final TextEditingController _about;
  late final TextEditingController _email;
  late bool _passedAway;
  Uint8List? _picture;
  Uint8List? _existingBytes;
  var _removed = false;
  var _busy = false;
  String? _aboutError;

  @override
  void initState() {
    super.initState();
    final person = widget.person;
    _name = TextEditingController(text: person.name);
    _about = TextEditingController(text: person.about ?? '');
    _email = TextEditingController(text: person.email ?? '');
    _passedAway = person.passedAway;
    final path = person.avatarPath;
    if (path != null && path.isNotEmpty) {
      _loadExisting(path);
    }
  }

  Future<void> _loadExisting(String path) async {
    try {
      final bytes = await ref
          .read(peopleRepositoryProvider)
          .pictureBytes(personId: widget.person.id, path: path);
      if (!mounted || _removed || _picture != null) return;
      setState(() => _existingBytes = bytes);
    } catch (error) {
      // An unreadable picture keeps the empty mark; Replace still works.
      return;
    }
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
      _existingBytes = null;
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
    if (about.length > 500) {
      setState(() => _aboutError = 'About must be 500 characters or fewer.');
      return;
    }
    final email = _email.text.trim();
    final emailChanged =
        !_passedAway &&
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
      final person = await _write(name, about, email);
      if (sendInvite) await _invite(person, email);
      if (!mounted) return;
      Navigator.of(context).pop(person);
    } catch (error) {
      // Every save failure shows the save sentence.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save person. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Person> _write(String name, String about, String email) {
    return ref
        .read(peopleRepositoryProvider)
        .updatePerson(
          personId: widget.person.id,
          name: name,
          passedAway: _passedAway,
          writePassedAway: true,
          about: about,
          writeAbout: true,
          email: email,
          writeEmail: true,
          pictureBytes: _picture,
          clearPicture: _removed && _picture == null,
        );
  }

  Future<void> _invite(Person person, String email) async {
    final invites = ref.read(inviteRepositoryProvider);
    final created = await invites.createInvite(
      familyId: person.familyId,
      email: email,
      personId: person.id,
    );
    await invites.sendInviteEmail(
      inviteId: created.inviteId,
      token: created.token,
    );
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? close = _busy
        ? null
        : () => Navigator.of(context).pop();
    return _EditScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EditHeader(onClose: close),
          const SizedBox(height: 12),
          Divider(color: albumSage.withValues(alpha: 0.28), height: 1),
          const SizedBox(height: 16),
          _PictureRow(
            canRemove: _canRemove,
            onPick: _busy ? null : _pick,
            onRemove: _busy ? null : _remove,
            avatar: _AvatarImage(
              picture: _picture,
              existing: _removed ? null : _existingBytes,
            ),
          ),
          const SizedBox(height: 20),
          _EditFields(
            name: _name,
            about: _about,
            email: _email,
            aboutError: _aboutError,
            passedAway: _passedAway,
            onPassedAway: _busy
                ? null
                : (value) => setState(() => _passedAway = value),
          ),
          const SizedBox(height: 20),
          _EditActions(onCancel: close, onSave: _busy ? null : _save),
        ],
      ),
    );
  }
}

class _EditScroll extends StatelessWidget {
  const _EditScroll({required this.child});

  final Widget child;

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
        child: child,
      ),
    );
  }
}

class _EditHeader extends StatelessWidget {
  const _EditHeader({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: albumSage.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: albumSage.withValues(alpha: 0.35)),
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
          onPressed: onClose,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _EditFields extends StatelessWidget {
  const _EditFields({
    required this.name,
    required this.about,
    required this.email,
    required this.aboutError,
    required this.passedAway,
    required this.onPassedAway,
  });

  final TextEditingController name;
  final TextEditingController about;
  final TextEditingController email;
  final String? aboutError;
  final bool passedAway;
  final ValueChanged<bool>? onPassedAway;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Name'),
        const SizedBox(height: 8),
        TextField(
          key: const Key('edit-person-name'),
          controller: name,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        const SizedBox(height: 20),
        const Text('About'),
        const SizedBox(height: 8),
        _AboutField(controller: about, errorText: aboutError),
        const SizedBox(height: 20),
        const Text('Email'),
        const SizedBox(height: 8),
        TextField(
          key: const Key('edit-person-email'),
          controller: email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _PassedAwayRow(value: passedAway, onChanged: onPassedAway),
      ],
    );
  }
}

class _PassedAwayRow extends StatelessWidget {
  const _PassedAwayRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Text('Passed away')),
        Switch(
          key: const Key('edit-person-passed-away'),
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _EditActions extends StatelessWidget {
  const _EditActions({required this.onCancel, required this.onSave});

  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(
          key: const Key('edit-person-cancel'),
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
        const Spacer(),
        FilledButton(
          key: const Key('edit-person-save'),
          onPressed: onSave,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _PictureRow extends StatelessWidget {
  const _PictureRow({
    required this.canRemove,
    required this.onPick,
    required this.onRemove,
    required this.avatar,
  });

  final bool canRemove;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      letterSpacing: 1.1,
      fontWeight: FontWeight.w700,
      color: albumInk.withValues(alpha: 0.55),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumParchment,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: albumSage.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _Avatar(image: avatar),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Picture', style: labelStyle),
                  const SizedBox(height: 2),
                  _PictureActions(
                    canRemove: canRemove,
                    onPick: onPick,
                    onRemove: onRemove,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PictureActions extends StatelessWidget {
  const _PictureActions({
    required this.canRemove,
    required this.onPick,
    required this.onRemove,
  });

  final bool canRemove;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final actionStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: albumTerracotta,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: albumTerracotta,
    );
    final buttonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        TextButton(
          key: const Key('edit-person-picture'),
          onPressed: onPick,
          style: buttonStyle,
          child: Text(
            canRemove ? 'Replace photo' : 'Add photo',
            style: actionStyle,
          ),
        ),
        if (canRemove) ...[
          Text('•', style: TextStyle(color: albumInk.withValues(alpha: 0.35))),
          TextButton(
            key: const Key('edit-person-picture-remove'),
            onPressed: onRemove,
            style: buttonStyle,
            child: Text(
              'Remove',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: albumInk.withValues(alpha: 0.55)),
            ),
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.image});

  final Widget image;

  @override
  Widget build(BuildContext context) {
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
            child: ClipOval(child: image),
          ),
          const Positioned(left: 42, top: 42, child: _CameraBadge()),
        ],
      ),
    );
  }
}

class _CameraBadge extends StatelessWidget {
  const _CameraBadge();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: albumTerracotta,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.photo_camera, size: 13, color: albumParchment),
      ),
    );
  }
}

/// The new pick, else the stored picture ([existing] is null once removed).
class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.picture, required this.existing});

  final Uint8List? picture;
  final Uint8List? existing;

  @override
  Widget build(BuildContext context) {
    final picked = picture;
    if (picked != null) {
      return Image.memory(
        picked,
        key: const Key('edit-person-picture-preview'),
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          key: Key('edit-person-picture-preview'),
          color: albumTerracotta,
        ),
      );
    }
    final stored = existing;
    if (stored != null && stored.isNotEmpty) {
      return Image.memory(
        stored,
        key: const Key('edit-person-picture-preview'),
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          key: Key('edit-person-picture-empty'),
          color: albumParchment,
        ),
      );
    }
    return const ColoredBox(
      key: Key('edit-person-picture-empty'),
      color: albumParchment,
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
              _EditAboutTextField(controller: widget.controller, style: style),
              Positioned(
                right: 1,
                bottom: 1,
                child: _EditResizeGrip(
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

class _EditAboutTextField extends StatelessWidget {
  const _EditAboutTextField({required this.controller, required this.style});

  final TextEditingController controller;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('edit-person-about'),
      controller: controller,
      expands: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      style: style,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.fromLTRB(12, 10, 22, 14),
      ),
    );
  }
}

class _EditResizeGrip extends StatelessWidget {
  const _EditResizeGrip({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpLeftDownRight,
      child: GestureDetector(
        key: const Key('edit-person-about-resize'),
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CustomPaint(painter: _ResizeGripPainter()),
        ),
      ),
    );
  }
}

class _ResizeGripPainter extends CustomPainter {
  const _ResizeGripPainter();

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
