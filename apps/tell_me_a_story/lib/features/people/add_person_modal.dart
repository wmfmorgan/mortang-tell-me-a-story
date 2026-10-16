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

/// Inserts one `story_people` row for a person the picker just chose.
typedef LinkStoryPerson = Future<void> Function({
  required String storyId,
  required String personId,
});

/// Add Person modal. Create writes profile fields. Relationship is not collected.
class AddPersonModal extends StatefulWidget {
  const AddPersonModal({
    super.key,
    required this.familyId,
    required this.api,
    this.invites,
    this.pickImageBytes,
    this.storyId,
    this.linkedPersonIds = const {},
    this.linkPerson,
  });

  final String familyId;
  final PeopleGateway api;
  final InviteGateway? invites;
  final Future<Uint8List?> Function()? pickImageBytes;
  final String? storyId;
  final Set<String> linkedPersonIds;
  final LinkStoryPerson? linkPerson;

  static Future<AddPersonResult?> show(
    BuildContext context, {
    required String familyId,
    required PeopleGateway api,
    InviteGateway? invites,
    Future<Uint8List?> Function()? pickImageBytes,
    String? storyId,
    Set<String> linkedPersonIds = const {},
    LinkStoryPerson? linkPerson,
  }) {
    return showAlbumDialog<AddPersonResult>(
      context: context,
      maxWidth: 580,
      builder: (ctx) => AddPersonModal(
        familyId: familyId,
        api: api,
        invites: invites,
        pickImageBytes: pickImageBytes,
        storyId: storyId,
        linkedPersonIds: linkedPersonIds,
        linkPerson: linkPerson,
      ),
    );
  }

  @override
  State<AddPersonModal> createState() => _AddPersonModalState();
}

class _AddPersonModalState extends State<AddPersonModal> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _aboutController = TextEditingController();
  StoryDate? _birth;
  StoryDate? _passing;
  Uint8List? _picture;

  var _busy = false;
  String? _nameError;
  String? _aboutError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _aboutController.dispose();
    super.dispose();
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
            _buildCreateForm(),
            const SizedBox(height: 16),
            Divider(height: 1, color: albumSage.withValues(alpha: 0.45)),
            const SizedBox(height: 12),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return Row(
      children: [
        OutlinedButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            foregroundColor: albumInk.withValues(alpha: 0.7),
            side: BorderSide(color: albumSage.withValues(alpha: 0.45)),
            shape: buttonShape,
          ),
          child: const Text('Cancel'),
        ),
        const Spacer(),
        FilledButton(
          onPressed: _busy ? null : _saveCreate,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: albumTerracotta,
            foregroundColor: albumParchment,
            disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.35),
            shape: buttonShape,
            padding: const EdgeInsets.symmetric(horizontal: 28),
          ),
          child: PlusLabel(
            label: _busy ? 'Adding…' : 'Add person',
            onTerracotta: true,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: albumParchment, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
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
        Text('ABOUT', style: kicker),
        const SizedBox(height: 6),
        _AddAboutField(
          controller: _aboutController,
          enabled: !_busy,
          errorText: _aboutError,
        ),
        if (!_passingSet) ...[
          const SizedBox(height: 16),
          Text('EMAIL', style: kicker),
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
        color: albumParchment,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: albumSage.withValues(alpha: 0.45)),
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
                      backgroundColor: albumParchment,
                      side: BorderSide(
                        color: albumSage.withValues(alpha: 0.45),
                      ),
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
                color: albumParchment,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: bytes == null
                    ? Icon(
                        Icons.account_circle,
                        size: 28,
                        color: albumTerracotta.withValues(alpha: 0.70),
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
                child: const Icon(Icons.add, size: 11, color: albumParchment),
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
