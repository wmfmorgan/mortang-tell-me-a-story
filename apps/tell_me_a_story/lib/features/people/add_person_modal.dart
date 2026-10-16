import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/album_chrome.dart';
import '../../core/theme/album_theme.dart';
import '../../data/invite_api.dart';
import '../../data/people_api.dart';
import '../../data/rpc_error.dart';
import '../family/family_blur_dialog.dart';

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

enum _AddStep { pick, form }

class _AddPersonModalState extends State<AddPersonModal> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _aboutController = TextEditingController();
  final _searchController = TextEditingController();
  var _passedAway = false;
  Uint8List? _picture;
  List<Person>? _people;
  var _step = _AddStep.pick;
  Person? _created;
  var _sendInvite = false;
  var _inviteSent = false;

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
    try {
      final people = await widget.api.listTreePeople(widget.familyId);
      if (!mounted) return;
      setState(() => _people = people);
    } catch (error) {
      if (!mounted) return;
      setState(() => _people = const []);
      _showSaveError(error);
    }
  }

  void _showSaveError(Object error) {
    final message = mapRpcError(error) ?? 'Couldn’t save person. Try again.';
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

  Future<void> _saveCreate() async {
    if (_created == null) {
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
      final email = _emailController.text.trim();
      if (email.isNotEmpty && !_passedAway) {
        final confirmed = await showSendInviteConfirm(
          context,
          name: name,
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
      final email = _emailController.text.trim();
      final person = _created ??= await widget.api.createPerson(
        familyId: widget.familyId,
        name: _nameController.text.trim(),
        about: _aboutController.text,
        email: email,
        passedAway: _passedAway,
        pictureBytes: _picture,
      );
      if (_sendInvite && !_inviteSent) {
        final invites = widget.invites;
        if (invites != null) {
          final created = await invites.createInvite(
            familyId: widget.familyId,
            email: email,
            personId: person.id,
          );
          await invites.sendInviteEmail(inviteId: created.inviteId);
        }
        _inviteSent = true;
      }
      if (!mounted) return;
      final result = await _linkThenPop(person, sendInvite: _sendInvite);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      _showSaveError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPerson(Person person) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await _linkThenPop(person, sendInvite: false);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      _showSaveError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<AddPersonResult> _linkThenPop(
    Person person, {
    required bool sendInvite,
  }) async {
    final storyId = widget.storyId;
    final link = widget.linkPerson;
    if (storyId != null && storyId.isNotEmpty && link != null) {
      await link(storyId: storyId, personId: person.id);
    }
    return AddPersonResult(person: person, sendInvite: sendInvite);
  }

  void _openCreate() {
    _nameController.text = _searchController.text;
    _nameController.selection = TextSelection.collapsed(
      offset: _nameController.text.length,
    );
    setState(() {
      _step = _AddStep.form;
      _nameError = null;
    });
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
            if (_step == _AddStep.pick) _picker() else _buildCreateForm(),
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
        if (_step == _AddStep.form)
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
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: albumParchment,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _picker() {
    final people = _visiblePeople();
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
          controller: _searchController,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, color: albumInk),
            filled: true,
            fillColor: albumParchment,
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (_people == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (people.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _pickerListMaxHeight),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: people.length,
              itemBuilder: (context, index) => _personRow(people[index]),
            ),
          ),
        _createRow(),
      ],
    );
  }

  List<Person> _visiblePeople() {
    final people = _people;
    if (people == null) return const [];
    final query = _searchController.text.trim().toLowerCase();
    final linked = widget.linkedPersonIds;
    final rows = [
      for (final person in people)
        if (!linked.contains(person.id) &&
            (query.isEmpty || person.name.toLowerCase().contains(query)))
          person,
    ];
    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return rows;
  }

  Widget _personRow(Person person) {
    final years = _yearSpan(person);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: albumParchment,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: albumSage.withValues(alpha: 0.45)),
        ),
        child: InkWell(
          key: Key('add-person-pick-${person.id}'),
          hoverColor: albumSage.withValues(alpha: 0.12),
          onTap: _busy ? null : () => _pickPerson(person),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: albumSage.withValues(alpha: 0.18),
                  foregroundColor: albumInk,
                  child: Text(
                    _initials(person.name),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: albumInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    person.name,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontSize: 16),
                  ),
                ),
                if (years.isNotEmpty)
                  Text(
                    years,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: albumInk.withValues(alpha: 0.55)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _createRow() {
    return CustomPaint(
      painter: const _DashedOutlinePainter(_DashShape.rrect),
      child: InkWell(
        key: const Key('add-person-create'),
        onTap: _busy ? null : _openCreate,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text('Create new person'),
        ),
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('PICTURE', style: kicker),
        const SizedBox(height: 6),
        _pictureRow(),
        const SizedBox(height: 16),
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
          enabled: !_formLocked,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Thomas Jenkins or Aunt Clara',
            errorText: _nameError,
          ),
        ),
        const SizedBox(height: 16),
        Text('ABOUT', style: kicker),
        const SizedBox(height: 6),
        _AddAboutField(
          controller: _aboutController,
          enabled: !_formLocked,
          errorText: _aboutError,
        ),
        const SizedBox(height: 16),
        Text('EMAIL', style: kicker),
        const SizedBox(height: 6),
        TextField(
          key: const Key('add-person-email'),
          controller: _emailController,
          enabled: !_formLocked,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'name@example.com'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text('Passed away', style: kicker),
            ),
            Switch(
              key: const Key('add-person-passed-away'),
              value: _passedAway,
              onChanged: _formLocked
                  ? null
                  : (value) => setState(() => _passedAway = value),
            ),
          ],
        ),
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
                    onPressed: _formLocked ? null : _pickPicture,
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
