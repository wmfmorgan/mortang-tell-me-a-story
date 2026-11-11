import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/server/app_session.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/data/invite_repository.dart';
import 'package:tell_me_a_story/core/data/people_repository.dart';
import 'package:tell_me_a_story/core/data/stories_repository.dart';
import 'package:tell_me_a_story/core/widgets/dialogs/family_blur_dialog.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date.dart';
import 'package:tell_me_a_story/features/people/presentation/edit_person_dialog.dart';
import 'package:tell_me_a_story/features/people/presentation/person_date_field.dart';

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
    this.loadStories,
  });

  final String personId;
  final String name;
  final Widget child;
  final PeopleRepository? people;
  final String? signedInUserId;
  final InviteRepository? invites;
  final Future<List<PersonStoryCard>> Function(String personId)? loadStories;

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
        loadStories: loadStories,
      ),
      child: child,
    );
  }
}

Future<void> showPersonProfile(
  BuildContext context, {
  required String personId,
  required String name,
  PeopleRepository? people,
  String? signedInUserId,
  InviteRepository? invites,
  Future<List<PersonStoryCard>> Function(String personId)? loadStories,
}) {
  return showBlurredCard<void>(
    context: context,
    builder: (ctx) => PersonProfileDialog(
      personId: personId,
      fallbackName: name,
      people: people ?? ServerPeopleRepository(),
      signedInUserId: signedInUserId ?? AppSession.instance.currentUserId,
      invites: invites,
      loadStories: loadStories,
    ),
  );
}

class PersonProfileDialog extends StatefulWidget {
  const PersonProfileDialog({
    super.key,
    required this.personId,
    required this.fallbackName,
    required this.people,
    this.signedInUserId,
    this.invites,
    this.loadStories,
  });

  final String personId;
  final String fallbackName;
  final PeopleRepository people;
  final String? signedInUserId;
  final InviteRepository? invites;
  final Future<List<PersonStoryCard>> Function(String personId)? loadStories;

  @override
  State<PersonProfileDialog> createState() => _PersonProfileDialogState();
}

class _PersonProfileDialogState extends State<PersonProfileDialog> {
  PersonProfile? _profile;
  Person? _editor;
  var _missing = false;
  var _loading = true;
  var _steward = false;
  Uint8List? _pictureBytes;
  List<PersonStoryCard> _stories = const [];

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
    } catch (_) {
      missing = true;
    }
    Person? editor;
    Uint8List? picture;
    var stories = const <PersonStoryCard>[];
    if (profile != null && !missing) {
      try {
        editor = await widget.people.personForEdit(widget.personId);
      } catch (_) {
        editor = null;
      }
      try {
        picture = await widget.people.pictureBytes(
          personId: widget.personId,
          path: profile.avatarPath,
        );
      } catch (_) {
        picture = null;
      }
      try {
        final load = widget.loadStories ?? _defaultPersonStories;
        stories = await load(widget.personId);
      } catch (_) {
        stories = const [];
      }
    }
    var steward = false;
    final linkedId = editor?.userId;
    if (profile != null &&
        profile.isLinked &&
        linkedId != null &&
        linkedId != widget.signedInUserId) {
      steward = await widget.people.isHomeFamilySteward(profile.familyId);
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _steward = steward;
      _editor = editor;
      _missing = missing || profile == null;
      _pictureBytes = picture;
      _stories = stories;
      _loading = false;
    });
  }

  bool get _showEdit {
    if (_profile == null || _missing) return false;
    if (_profile!.isLinked) return false;
    return _editor?.userId == null;
  }

  Future<void> _confirmMark() async {
    final profile = _profile;
    if (profile == null) return;
    final mark = !profile.passedAway;
    final title = mark ? 'Mark as passed away?' : 'Unmark passed away?';
    final action = mark ? 'Mark as passed away' : 'Unmark passed away';
    final yes = await showBlurredCard<bool>(
      context: context,
      builder: (context) => Material(
        color: albumParchment,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('passed-away-confirm-yes'),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(action, textAlign: TextAlign.center),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await widget.people.markPassedAway(personId: profile.id, value: mark);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appErrorMessage(error) ?? 'Try again')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    await _load();
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
    final life = profile == null ? '' : _lifeLine(profile);
    final about = profile?.about?.trim() ?? '';
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      letterSpacing: 1.2,
      fontWeight: FontWeight.w700,
      color: albumInk.withValues(alpha: 0.55),
    );
    return ConstrainedBox(
      key: const Key('person-profile-dialog'),
      constraints: BoxConstraints(
        maxWidth: 512,
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Material(
        color: albumParchment,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_missing && profile != null) _picture(profile),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    key: const Key('person-profile-name'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!_missing && profile != null) ...[
                    if (life.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        life,
                        key: const Key('person-profile-dates'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: albumInk.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (_showEdit) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: OutlinedButton.icon(
                          key: const Key('person-profile-edit'),
                          onPressed: _edit,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                        ),
                      ),
                    ],
                    if (_steward) ...[
                      const SizedBox(height: 16),
                      Text('Family owners', style: labelStyle),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _confirmMark,
                          child: Text(
                            profile.passedAway
                                ? 'Unmark passed away'
                                : 'Mark as passed away',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Divider(height: 1, color: albumInk.withValues(alpha: 0.12)),
                    if (about.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('About', style: labelStyle),
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: albumParchment,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: albumInk.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            about,
                            key: const Key('person-profile-about'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _storiesSection(context, labelStyle),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storiesSection(BuildContext context, TextStyle? labelStyle) {
    final count = _stories.length;
    final countLabel = count == 1 ? '1 story' : '$count stories';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Stories', style: labelStyle),
            const Spacer(),
            DecoratedBox(
              decoration: BoxDecoration(
                color: albumSage.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  countLabel,
                  key: const Key('person-profile-story-count'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: albumInk.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final story in _stories) ...[
          _storyRow(context, story),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _storyRow(BuildContext context, PersonStoryCard story) {
    final bits = <String>[
      if (story.whenLabel.isNotEmpty) story.whenLabel,
      if ((story.place ?? '').isNotEmpty) story.place!,
    ];
    return Material(
      color: albumParchment,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('person-profile-story-${story.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final router = GoRouter.maybeOf(context);
          Navigator.of(context).pop();
          router?.push(AppRoutes.storyPath(story.id));
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: albumInk.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              _thumb(story),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (bits.isNotEmpty)
                      Text(
                        bits.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: albumInk.withValues(alpha: 0.6)),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: albumInk.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(PersonStoryCard story) {
    final bytes = story.thumbBytes;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: bytes == null || bytes.isEmpty
                ? const ColoredBox(
                    color: albumParchment,
                    child: SizedBox(width: 56, height: 56),
                  )
                : Image.memory(
                    bytes,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: albumParchment,
                      child: SizedBox(width: 56, height: 56),
                    ),
                  ),
          ),
          if (story.photoCount > 0)
            Positioned(
              right: 2,
              bottom: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: albumInk.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  child: Text(
                    '${story.photoCount}',
                    style: const TextStyle(
                      color: albumParchment,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _picture(PersonProfile profile) {
    final stored = _pictureBytes;
    final bytes = profile.avatarPath == null || stored == null || stored.isEmpty
        ? null
        : stored;
    return Center(
      child: SizedBox(
        width: 112,
        height: 112,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: albumParchment,
                border: Border.all(color: albumInk.withValues(alpha: 0.12)),
              ),
              child: ClipOval(
                child: bytes == null
                    ? const ColoredBox(
                        key: Key('person-avatar-empty'),
                        color: albumParchment,
                      )
                    : Image.memory(
                        bytes,
                        key: const Key('person-avatar-image'),
                        width: 112,
                        height: 112,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          key: Key('person-avatar-empty'),
                          color: albumParchment,
                        ),
                      ),
              ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: IgnorePointer(
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: albumTerracotta.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: albumParchment, width: 2),
                  ),
                  child: Icon(
                    Icons.face,
                    size: 14,
                    color: albumInk.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _lifeLine(PersonProfile profile) {
  final birth = storyDateFromPerson(profile.birthDate, profile.birthPrecision);
  if (birth == null) return '';
  return 'Born ${storyDateLabel(birth)}';
}

Future<List<PersonStoryCard>> _defaultPersonStories(String personId) async {
  try {
    return await ServerStoriesRepository().storiesForPerson(personId);
  } catch (_) {
    return const [];
  }
}
