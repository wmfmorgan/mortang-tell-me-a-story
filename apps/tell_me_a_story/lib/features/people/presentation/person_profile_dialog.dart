import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/person_profile.dart';
import 'package:tell_me_a_story/core/domain/person_story_card.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/app_session_provider.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/dialogs/family_blur_dialog.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date.dart';
import 'package:tell_me_a_story/features/people/presentation/edit_person_dialog.dart';
import 'package:tell_me_a_story/features/people/presentation/people_providers.dart';
import 'package:tell_me_a_story/features/people/presentation/person_date_field.dart';

/// Name pill. A tap opens the person profile. An empty id does not.
class PersonNamePill extends StatelessWidget {
  const PersonNamePill({
    super.key,
    required this.personId,
    required this.name,
    required this.child,
    this.signedInUserId,
  });

  final String personId;
  final String name;
  final Widget child;
  final String? signedInUserId;

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
        signedInUserId: signedInUserId,
      ),
      child: child,
    );
  }
}

Future<void> showPersonProfile(
  BuildContext context, {
  required String personId,
  required String name,
  String? signedInUserId,
}) {
  return showBlurredCard<void>(
    context: context,
    builder: (ctx) => PersonProfileDialog(
      personId: personId,
      fallbackName: name,
      signedInUserId:
          signedInUserId ??
          ProviderScope.containerOf(
            context,
            listen: false,
          ).read(appSessionProvider).currentUserId,
    ),
  );
}

class PersonProfileDialog extends ConsumerWidget {
  const PersonProfileDialog({
    super.key,
    required this.personId,
    required this.fallbackName,
    this.signedInUserId,
  });

  final String personId;
  final String fallbackName;
  final String? signedInUserId;

  PersonProfileViewProvider get _provider =>
      personProfileViewProvider(personId, signedInUserId);

  Future<void> _confirmMark(
    BuildContext context,
    WidgetRef ref,
    PersonProfile profile,
  ) async {
    final mark = !profile.passedAway;
    final yes = await showBlurredCard<bool>(
      context: context,
      builder: (context) => _MarkConfirm(mark: mark),
    );
    if (yes != true || !context.mounted) return;
    try {
      await ref
          .read(peopleRepositoryProvider)
          .markPassedAway(personId: profile.id, value: mark);
    } catch (error) {
      // Mapped and shown; the card stays as it was.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appErrorMessage(error) ?? 'Try again')),
      );
      return;
    }
    if (!context.mounted) return;
    ref.invalidate(_provider);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    PersonProfileView view,
  ) async {
    final editor = view.editor;
    if (editor == null || view.profile == null) return;
    final saved = await showEditPersonDialog(
      context,
      person: editor,
      signedInUserId: signedInUserId,
    );
    if (saved == null || !context.mounted) return;
    ref.invalidate(_provider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_provider);
    final view = async.value;
    final profile = view?.profile;
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
              child: _ProfileBody(
                name: profile?.name ?? fallbackName,
                loading: async.isLoading,
                view: view,
                onEdit: view == null ? null : () => _edit(context, ref, view),
                onMark: profile == null
                    ? null
                    : () => _confirmMark(context, ref, profile),
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
}

class _MarkConfirm extends StatelessWidget {
  const _MarkConfirm({required this.mark});

  final bool mark;

  @override
  Widget build(BuildContext context) {
    final title = mark ? 'Mark as passed away?' : 'Unmark passed away?';
    final action = mark ? 'Mark as passed away' : 'Unmark passed away';
    return Material(
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
    );
  }
}

TextStyle? _labelStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelSmall?.copyWith(
    letterSpacing: 1.2,
    fontWeight: FontWeight.w700,
    color: albumInk.withValues(alpha: 0.55),
  );
}

/// Picture, name, then either the spinner or the loaded details.
class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.name,
    required this.loading,
    required this.view,
    required this.onEdit,
    required this.onMark,
  });

  final String name;
  final bool loading;
  final PersonProfileView? view;
  final VoidCallback? onEdit;
  final VoidCallback? onMark;

  @override
  Widget build(BuildContext context) {
    final loaded = view;
    final profile = loaded?.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loaded != null && profile != null)
          _Picture(profile: profile, stored: loaded.picture),
        const SizedBox(height: 14),
        Text(
          name,
          key: const Key('person-profile-name'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (loaded != null && profile != null)
          _ProfileDetails(
            view: loaded,
            profile: profile,
            onEdit: onEdit,
            onMark: onMark,
          ),
      ],
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({
    required this.view,
    required this.profile,
    required this.onEdit,
    required this.onMark,
  });

  final PersonProfileView view;
  final PersonProfile profile;
  final VoidCallback? onEdit;
  final VoidCallback? onMark;

  bool get _showEdit => !profile.isLinked && view.editor?.userId == null;

  @override
  Widget build(BuildContext context) {
    final life = _lifeLine(profile);
    final about = profile.about?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        if (_showEdit) _EditButton(onPressed: onEdit),
        if (view.steward)
          _StewardControls(passedAway: profile.passedAway, onMark: onMark),
        const SizedBox(height: 20),
        Divider(height: 1, color: albumInk.withValues(alpha: 0.12)),
        if (about.isNotEmpty) _AboutSection(about: about),
        const SizedBox(height: 20),
        _StoriesSection(stories: view.stories),
      ],
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: OutlinedButton.icon(
          key: const Key('person-profile-edit'),
          onPressed: onPressed,
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Edit'),
        ),
      ),
    );
  }
}

class _StewardControls extends StatelessWidget {
  const _StewardControls({required this.passedAway, required this.onMark});

  final bool passedAway;
  final VoidCallback? onMark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text('Family owners', style: _labelStyle(context)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onMark,
            child: Text(
              passedAway ? 'Unmark passed away' : 'Mark as passed away',
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.about});

  final String about;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text('About', style: _labelStyle(context)),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: albumParchment,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: albumInk.withValues(alpha: 0.08)),
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
    );
  }
}

class _StoriesSection extends StatelessWidget {
  const _StoriesSection({required this.stories});

  final List<PersonStoryCard> stories;

  @override
  Widget build(BuildContext context) {
    final count = stories.length;
    final countLabel = count == 1 ? '1 story' : '$count stories';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Stories', style: _labelStyle(context)),
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
        for (final story in stories) ...[
          _StoryRow(story: story),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({required this.story});

  final PersonStoryCard story;

  @override
  Widget build(BuildContext context) {
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
              _Thumb(story: story),
              const SizedBox(width: 14),
              Expanded(child: _StoryRowText(story: story)),
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
}

class _StoryRowText extends StatelessWidget {
  const _StoryRowText({required this.story});

  final PersonStoryCard story;

  @override
  Widget build(BuildContext context) {
    final place = story.place ?? '';
    final bits = <String>[
      if (story.whenLabel.isNotEmpty) story.whenLabel,
      if (place.isNotEmpty) place,
    ];
    return Column(
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
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.story});

  final PersonStoryCard story;

  @override
  Widget build(BuildContext context) {
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
              child: _PhotoCountBadge(count: story.photoCount),
            ),
        ],
      ),
    );
  }
}

class _PhotoCountBadge extends StatelessWidget {
  const _PhotoCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumInk.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          '$count',
          style: const TextStyle(
            color: albumParchment,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Picture extends StatelessWidget {
  const _Picture({required this.profile, required this.stored});

  final PersonProfile profile;
  final Uint8List? stored;

  @override
  Widget build(BuildContext context) {
    final stored = this.stored;
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
              child: ClipOval(child: _AvatarBytes(bytes: bytes)),
            ),
            const Positioned(right: 2, bottom: 2, child: _PictureBadge()),
          ],
        ),
      ),
    );
  }
}

class _AvatarBytes extends StatelessWidget {
  const _AvatarBytes({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final bytes = this.bytes;
    if (bytes == null) {
      return const ColoredBox(
        key: Key('person-avatar-empty'),
        color: albumParchment,
      );
    }
    return Image.memory(
      bytes,
      key: const Key('person-avatar-image'),
      width: 112,
      height: 112,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        key: Key('person-avatar-empty'),
        color: albumParchment,
      ),
    );
  }
}

class _PictureBadge extends StatelessWidget {
  const _PictureBadge();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
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
    );
  }
}

String _lifeLine(PersonProfile profile) {
  final birth = storyDateFromPerson(profile.birthDate, profile.birthPrecision);
  if (birth == null) return '';
  return 'Born ${storyDateLabel(birth)}';
}
