import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/display_name.dart';
import 'package:tell_me_a_story/core/domain/family_person.dart';
import 'package:tell_me_a_story/core/domain/manage_families_repository.dart';
import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/widgets/story/story_title.dart';
import 'package:tell_me_a_story/core/widgets/dialogs/family_blur_dialog.dart';
import 'package:tell_me_a_story/features/family/presentation/family_providers.dart';

class StartTimelineResult {
  const StartTimelineResult({required this.familyId, required this.name});

  final String familyId;
  final String name;
}

/// Picker, then the create form. A fixed origin skips the picker.
/// Returns null when the user cancels. The caller stays on the parent.
Future<StartTimelineResult?> showStartTimelineDialog(
  BuildContext context, {
  required String parentId,
  required String parentName,
  required List<Story> stories,
  required String currentUserId,
  Story? origin,
  bool allowChange = true,
  VoidCallback? onWriteStory,
}) {
  return showGeneralDialog<StartTimelineResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    pageBuilder: (context, animation, secondaryAnimation) {
      return _StartTimelineDialog(
        parentId: parentId,
        parentName: parentName,
        stories: stories,
        currentUserId: currentUserId,
        origin: origin,
        allowChange: allowChange,
        onWriteStory: onWriteStory,
      );
    },
  );
}

class _StartTimelineDialog extends ConsumerStatefulWidget {
  const _StartTimelineDialog({
    required this.parentId,
    required this.parentName,
    required this.stories,
    required this.currentUserId,
    required this.origin,
    required this.allowChange,
    required this.onWriteStory,
  });

  final String parentId;
  final String parentName;
  final List<Story> stories;
  final String currentUserId;
  final Story? origin;
  final bool allowChange;
  final VoidCallback? onWriteStory;

  @override
  ConsumerState<_StartTimelineDialog> createState() =>
      _StartTimelineDialogState();
}

class _StartTimelineDialogState extends ConsumerState<_StartTimelineDialog> {
  late Story? _origin = widget.origin;
  late var _picking = widget.origin == null;
  final _search = TextEditingController();
  final _name = TextEditingController();
  late final TextEditingController _year;
  String? _ownerId;
  final _pickedPeople = <String>{};
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _year = TextEditingController(text: _prefill(_origin));
    _name.addListener(_refresh);
    _year.addListener(_refresh);
    _search.addListener(_refresh);
  }

  String _prefill(Story? story) {
    if (story == null) return '';
    return '${story.publishedStart.year}';
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String? _defaultOwner(List<FamilyPerson> members) {
    for (final person in members) {
      if (person.userId == widget.currentUserId) return person.userId;
    }
    if (members.isEmpty) return null;
    return members.first.userId;
  }

  bool get _yearOk {
    final year = int.tryParse(_year.text.trim());
    return year != null && year >= 1000 && year <= 9999;
  }

  bool _canCreate(String? owner) =>
      !_busy &&
      _origin != null &&
      _name.text.trim().isNotEmpty &&
      owner != null &&
      _yearOk;

  List<Story> get _visible {
    final query = _search.text.trim().toLowerCase();
    final published = [
      for (final story in widget.stories)
        if (story.status == StoryStatus.published &&
            story.familyId == widget.parentId)
          story,
    ];
    if (query.isEmpty) return published;
    return [
      for (final story in published)
        if (storyTitle(story).toLowerCase().contains(query)) story,
    ];
  }

  Future<void> _create(String? owner) async {
    final origin = _origin;
    final year = int.tryParse(_year.text.trim());
    if (origin == null || owner == null || year == null) return;
    if (!_canCreate(owner)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(manageFamiliesRepositoryProvider)
          .createBranchFamily(
            parentFamilyId: widget.parentId,
            originStoryId: origin.id,
            name: _name.text.trim(),
            branchYear: year,
            ownerUserId: owner,
            personIds: _pickedPeople.toList(),
          );
      if (!mounted) return;
      Navigator.pop(
        context,
        StartTimelineResult(familyId: id, name: _name.text.trim()),
      );
    } on AppException catch (error) {
      _fail(_inlineError(error));
    } catch (_) {
      // Non-app failures map to the generic inline copy.
      _fail('Try again');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  String _inlineError(AppException error) {
    if (error.code == AppErrorCode.notFound) {
      if (widget.allowChange) {
        return "That story isn't available anymore. Pick another one.";
      }
      return "That story isn't available anymore.";
    }
    if (error.code == AppErrorCode.forbidden) {
      return "You're not a member of ${widget.parentName} anymore.";
    }
    if (_isInternal(error.message)) return 'Try again';
    return error.message;
  }

  bool _isInternal(String message) {
    const hidden = {'create_branch_family returned no id', 'Request failed'};
    return hidden.contains(message.trim());
  }

  void _pick(Story story) {
    setState(() {
      _origin = story;
      _year.text = _prefill(story);
      _picking = false;
      _error = null;
    });
  }

  void _togglePerson(String id, bool selected) {
    setState(() {
      if (selected) {
        _pickedPeople.add(id);
      } else {
        _pickedPeople.remove(id);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watched from the first frame so the roster loads while picking.
    final roster = ref.watch(startTimelineRosterProvider(widget.parentId));
    return FamilyBlurShell(
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Material(
                color: const Color(0xFFFFF8F6),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: _picking ? _picker() : _form(roster),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _Picker _picker() {
    return _Picker(
      parentName: widget.parentName,
      search: _search,
      stories: _visible,
      onPick: _pick,
      onWriteStory: () {
        Navigator.pop(context);
        widget.onWriteStory?.call();
      },
    );
  }

  _Form _form(AsyncValue<StartTimelineRoster> roster) {
    // A roster that fails to load leaves the owner and member lists empty.
    final members = roster.value?.members ?? const <FamilyPerson>[];
    final owner = _ownerId ?? _defaultOwner(members);
    return _Form(
      parentName: widget.parentName,
      origin: _origin,
      onChange: widget.allowChange
          ? () => setState(() => _picking = true)
          : null,
      name: _name,
      year: _year,
      owner: _OwnerChoice(
        ownerId: owner,
        members: members,
        currentUserId: widget.currentUserId,
        onChanged: roster.isLoading
            ? null
            : (value) => setState(() => _ownerId = value),
      ),
      people: _PeopleChoice(
        people: roster.value?.people ?? const <Person>[],
        picked: _pickedPeople,
        onToggle: _togglePerson,
      ),
      error: _error,
      onCancel: _busy ? null : () => Navigator.pop(context),
      onCreate: _canCreate(owner) ? () => _create(owner) : null,
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.parentName,
    required this.search,
    required this.stories,
    required this.onPick,
    required this.onWriteStory,
  });

  final String parentName;
  final TextEditingController search;
  final List<Story> stories;
  final ValueChanged<Story> onPick;
  final VoidCallback onWriteStory;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('start-timeline-picker'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pick the origin story',
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Published stories from $parentName',
          style: GoogleFonts.literata(color: albumInk, fontSize: 14),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('start-timeline-search'),
          controller: search,
          decoration: const InputDecoration(
            hintText: 'Search stories',
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: _StoryList(stories: stories, onPick: onPick),
        ),
        TextButton(
          key: const Key('start-timeline-write'),
          onPressed: onWriteStory,
          child: const Text('Write a new story'),
        ),
        OutlinedButton(
          key: const Key('start-timeline-picker-cancel'),
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: albumInk,
            side: const BorderSide(color: albumInk),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _StoryList extends StatelessWidget {
  const _StoryList({required this.stories, required this.onPick});

  final List<Story> stories;
  final ValueChanged<Story> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        for (final story in stories)
          ListTile(
            key: Key('start-timeline-story-${story.id}'),
            title: Text(storyTitle(story)),
            subtitle: Text('${story.publishedStart.year}'),
            onTap: () => onPick(story),
          ),
      ],
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.parentName,
    required this.origin,
    required this.onChange,
    required this.name,
    required this.year,
    required this.owner,
    required this.people,
    required this.error,
    required this.onCancel,
    required this.onCreate,
  });

  final String parentName;
  final Story? origin;
  final VoidCallback? onChange;
  final TextEditingController name;
  final TextEditingController year;
  final Widget owner;
  final Widget people;
  final String? error;
  final VoidCallback? onCancel;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final origin = this.origin;
    final error = this.error;
    return SingleChildScrollView(
      child: Column(
        key: const Key('start-timeline-dialog'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FormTitle(parentName: parentName),
          if (origin != null) ...[
            const SizedBox(height: 12),
            _OriginCard(origin: origin, onChange: onChange),
          ],
          const SizedBox(height: 12),
          _NameField(controller: name),
          const SizedBox(height: 12),
          owner,
          const SizedBox(height: 12),
          people,
          const SizedBox(height: 12),
          _YearField(controller: year),
          const SizedBox(height: 12),
          Text("You'll stay in $parentName."),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error,
              key: const Key('start-timeline-error'),
              style: GoogleFonts.sourceSans3(
                color: albumTerracotta,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _FormActions(onCancel: onCancel, onCreate: onCreate),
        ],
      ),
    );
  }
}

class _FormTitle extends StatelessWidget {
  const _FormTitle({required this.parentName});

  final String parentName;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Add a family branch to $parentName',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.newsreader(
        color: albumInk,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _OriginCard extends StatelessWidget {
  const _OriginCard({required this.origin, required this.onChange});

  final Story origin;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final onChange = this.onChange;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: albumInk.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Origin story',
                    style: GoogleFonts.sourceSans3(
                      color: albumInk,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${storyTitle(origin)} · ${origin.publishedStart.year}',
                    style: GoogleFonts.literata(color: albumInk, fontSize: 16),
                  ),
                ],
              ),
            ),
            if (onChange != null)
              TextButton(
                key: const Key('start-timeline-change'),
                onPressed: onChange,
                child: const Text('Change'),
              ),
          ],
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Timeline name',
          style: GoogleFonts.sourceSans3(fontSize: 14, color: albumInk),
        ),
        const SizedBox(height: 4),
        TextField(
          key: const Key('start-timeline-name'),
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. The Morgan-Reyes',
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _OwnerChoice extends StatelessWidget {
  const _OwnerChoice({
    required this.ownerId,
    required this.members,
    required this.currentUserId,
    required this.onChanged,
  });

  final String? ownerId;
  final List<FamilyPerson> members;
  final String currentUserId;
  final ValueChanged<String?>? onChanged;

  String _label(FamilyPerson person) {
    if (person.userId == currentUserId) return 'You';
    return displayNameOrMember(person.displayName);
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: const Key('start-timeline-owner'),
      initialValue: ownerId,
      decoration: const InputDecoration(
        labelText: 'Owner',
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        for (final person in members)
          DropdownMenuItem(value: person.userId, child: Text(_label(person))),
      ],
      onChanged: onChanged,
    );
  }
}

class _PeopleChoice extends StatelessWidget {
  const _PeopleChoice({
    required this.people,
    required this.picked,
    required this.onToggle,
  });

  final List<Person> people;
  final Set<String> picked;
  final void Function(String id, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Members',
          style: GoogleFonts.sourceSans3(fontSize: 14, color: albumInk),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final person in people)
              _PersonChip(
                person: person,
                selected: picked.contains(person.id),
                onSelected: (selected) => onToggle(person.id, selected),
              ),
          ],
        ),
      ],
    );
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({
    required this.person,
    required this.selected,
    required this.onSelected,
  });

  final Person person;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      key: Key('start-timeline-member-${person.id}'),
      showCheckmark: false,
      label: Text(
        displayNameOrMember(person.name),
        style: GoogleFonts.sourceSans3(
          color: selected ? Colors.white : albumInk,
          fontSize: 14,
        ),
      ),
      selected: selected,
      selectedColor: albumSage,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? albumSage : albumInk.withValues(alpha: 0.3),
      ),
      onSelected: onSelected,
    );
  }
}

class _YearField extends StatelessWidget {
  const _YearField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Attaches in *', style: GoogleFonts.sourceSans3(fontSize: 14)),
        TextField(
          key: const Key('start-timeline-year'),
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _FormActions extends StatelessWidget {
  const _FormActions({required this.onCancel, required this.onCreate});

  final VoidCallback? onCancel;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return OverflowBar(
      alignment: MainAxisAlignment.end,
      spacing: 12,
      children: [
        OutlinedButton(
          key: const Key('start-timeline-cancel'),
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: albumInk,
            side: const BorderSide(color: albumInk),
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('start-timeline-create'),
          onPressed: onCreate,
          style: FilledButton.styleFrom(
            backgroundColor: albumTerracotta,
            disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.4),
          ),
          child: const Text('Create timeline'),
        ),
      ],
    );
  }
}
