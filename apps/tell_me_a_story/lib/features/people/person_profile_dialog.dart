import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/album_theme.dart';
import '../../data/invite_api.dart';
import '../../data/people_api.dart';
import '../family/family_blur_dialog.dart';
import '../stories/story_date.dart';
import 'edit_person_dialog.dart';
import 'person_date_field.dart';

/// Name pill. A tap opens the person profile. An empty id does not.
class PersonNamePill extends StatelessWidget {
  const PersonNamePill({
    super.key,
    required this.personId,
    required this.name,
    required this.child,
    this.people,
    this.signedInUserId,
    this.invites,
  });

  final String personId;
  final String name;
  final Widget child;
  final PeopleGateway? people;
  final String? signedInUserId;
  final InviteGateway? invites;

  @override
  Widget build(BuildContext context) {
    if (personId.isEmpty) return child;
    return GestureDetector(
      key: Key('person-pill-$personId'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showPersonProfile(
        context,
        personId: personId,
        name: name,
        people: people,
        signedInUserId: signedInUserId,
        invites: invites,
      ),
      child: child,
    );
  }
}

Future<void> showPersonProfile(
  BuildContext context, {
  required String personId,
  required String name,
  PeopleGateway? people,
  String? signedInUserId,
  InviteGateway? invites,
}) {
  return showBlurredCard<void>(
    context: context,
    builder: (ctx) => PersonProfileDialog(
      personId: personId,
      fallbackName: name,
      people: people ?? PeopleApi(),
      signedInUserId: signedInUserId ?? _sessionUserId(),
      invites: invites,
    ),
  );
}

String? _sessionUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null;
  }
}

class PersonProfileDialog extends StatefulWidget {
  const PersonProfileDialog({
    super.key,
    required this.personId,
    required this.fallbackName,
    required this.people,
    this.signedInUserId,
    this.invites,
  });

  final String personId;
  final String fallbackName;
  final PeopleGateway people;
  final String? signedInUserId;
  final InviteGateway? invites;

  @override
  State<PersonProfileDialog> createState() => _PersonProfileDialogState();
}

class _PersonProfileDialogState extends State<PersonProfileDialog> {
  PersonProfile? _profile;
  Person? _editor;
  var _missing = false;
  var _loading = true;
  String? _pictureUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    PersonProfile? profile;
    var missing = false;
    try {
      profile = await widget.people.personProfile(widget.personId);
      if (profile == null) missing = true;
    } on PersonProfileNotFound {
      missing = true;
    } catch (_) {
      missing = true;
    }
    Person? editor;
    String? pictureUrl;
    if (profile != null && !missing) {
      try {
        editor = await widget.people.personForEdit(widget.personId);
      } catch (_) {
        editor = null;
      }
      try {
        pictureUrl = await widget.people.signedPictureUrl(
          personId: widget.personId,
          path: profile.avatarPath,
        );
      } catch (_) {
        pictureUrl = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _editor = editor;
      _missing = missing || profile == null;
      _pictureUrl = pictureUrl;
      _loading = false;
    });
  }

  bool get _showEdit {
    final profile = _profile;
    if (profile == null || _missing) return false;
    final userId = _editor?.userId;
    if (!profile.isLinked || userId == null) return true;
    return userId == widget.signedInUserId;
  }

  Future<void> _edit() async {
    final editor = _editor;
    final profile = _profile;
    if (editor == null || profile == null) return;
    final saved = await showEditPersonDialog(
      context,
      person: editor,
      people: widget.people,
      invites: widget.invites,
      signedInUserId: widget.signedInUserId,
    );
    if (saved == null || !mounted) return;
    setState(() => _loading = true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final name = _missing || profile == null
        ? widget.fallbackName
        : profile.name;
    return ConstrainedBox(
      key: const Key('person-profile-dialog'),
      constraints: BoxConstraints(
        maxWidth: 480,
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Material(
        color: albumParchment,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Name',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(name, key: const Key('person-profile-name')),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!_missing && profile != null) ...[
                const SizedBox(height: 16),
                _picture(profile),
                if (profile.birthDate != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Shows as ${storyDateLabel(storyDateFromPerson(profile.birthDate, profile.birthPrecision)!)}',
                    key: const Key('person-profile-birth'),
                  ),
                ],
                if (profile.passingDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Date of passing',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    'Shows as ${storyDateLabel(storyDateFromPerson(profile.passingDate, profile.passingPrecision)!)}',
                    key: const Key('person-profile-passing'),
                  ),
                ],
                if ((profile.about ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('About', style: Theme.of(context).textTheme.labelLarge),
                  Text(profile.about!, key: const Key('person-profile-about')),
                ],
                if (_showEdit) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      key: const Key('person-profile-edit'),
                      onPressed: _edit,
                      child: const Text('Edit'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _picture(PersonProfile profile) {
    final url = _pictureUrl;
    if (profile.avatarPath == null || url == null || url.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          key: Key('person-avatar-empty'),
          width: 72,
          height: 72,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF3EDE6),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipOval(
        child: Image.network(
          url,
          key: const Key('person-avatar-image'),
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox(
            key: Key('person-avatar-empty'),
            width: 72,
            height: 72,
          ),
        ),
      ),
    );
  }
}
