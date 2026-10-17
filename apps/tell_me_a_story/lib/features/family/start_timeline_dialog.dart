import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';
import '../../data/comments_api.dart';
import '../../data/families_api.dart';
import '../../data/manage_families_api.dart';
import '../../data/people_api.dart';
import '../../data/stories_api.dart';
import '../timeline/timeline_zoom.dart';
import 'family_blur_dialog.dart';

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
  required FamiliesGateway familiesApi,
  required PeopleGateway peopleApi,
  required ManageFamiliesGateway manageApi,
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
        familiesApi: familiesApi,
        peopleApi: peopleApi,
        manageApi: manageApi,
        currentUserId: currentUserId,
        origin: origin,
        allowChange: allowChange,
        onWriteStory: onWriteStory,
      );
    },
  );
}

class _StartTimelineDialog extends StatefulWidget {
  const _StartTimelineDialog({
    required this.parentId,
    required this.parentName,
    required this.stories,
    required this.familiesApi,
    required this.peopleApi,
    required this.manageApi,
    required this.currentUserId,
    required this.origin,
    required this.allowChange,
    required this.onWriteStory,
  });

  final String parentId;
  final String parentName;
  final List<Story> stories;
  final FamiliesGateway familiesApi;
  final PeopleGateway peopleApi;
  final ManageFamiliesGateway manageApi;
  final String currentUserId;
  final Story? origin;
  final bool allowChange;
  final VoidCallback? onWriteStory;

  @override
  State<_StartTimelineDialog> createState() => _StartTimelineDialogState();
}

class _StartTimelineDialogState extends State<_StartTimelineDialog> {
  late Story? _origin = widget.origin;
  late var _picking = widget.origin == null;
  final _search = TextEditingController();
  final _name = TextEditingController();
  late final TextEditingController _year;
  String? _ownerId;
  final _pickedPeople = <String>{};
  List<FamilyPerson> _members = const [];
  List<Person> _people = const [];
  var _busy = false;
  String? _error;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    _year = TextEditingController(text: _prefill(_origin));
    _name.addListener(_refresh);
    _year.addListener(_refresh);
    _search.addListener(_refresh);
    _loadRoster();
  }

  String _prefill(Story? story) {
    if (story == null) return '';
    return '${story.timeframeStart!.year}';
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRoster() async {
    try {
      final members = await widget.familiesApi.listMembers(widget.parentId);
      final people = await widget.peopleApi.listPeople(widget.parentId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _people = people;
        _ownerId ??= _defaultOwner(members);
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  String? _defaultOwner(List<FamilyPerson> members) {
    for (final person in members) {
      if (person.userId == widget.currentUserId) return person.userId;
    }
    if (members.isEmpty) return null;
    return members.first.userId;
  }

  String _ownerLabel(FamilyPerson person) {
    if (person.userId == widget.currentUserId) return 'You';
    return displayNameOrMember(person.displayName);
  }

  bool get _yearOk {
    final year = int.tryParse(_year.text.trim());
    return year != null && year >= 1000 && year <= 9999;
  }

  bool get _canCreate =>
      !_busy &&
      _origin != null &&
      _name.text.trim().isNotEmpty &&
      _ownerId != null &&
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

  Future<void> _create() async {
    final origin = _origin;
    final owner = _ownerId;
    final year = int.tryParse(_year.text.trim());
    if (origin == null || owner == null || year == null || !_canCreate) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.manageApi.createBranchFamily(
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
    } on ManageFamiliesException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _inlineError(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "Try again";
      });
    }
  }

  String _inlineError(ManageFamiliesException error) {
    if (error.code == 'NOT_FOUND') {
      if (widget.allowChange) {
        return "That story isn't available anymore. Pick another one.";
      }
      return "That story isn't available anymore.";
    }
    if (error.code == 'FORBIDDEN') {
      return "You're not a member of ${widget.parentName} anymore.";
    }
    if (_isInternal(error.message)) return 'Try again';
    return error.message;
  }

  bool _isInternal(String message) {
    const hidden = {'create_branch_family returned no id', 'Request failed'};
    return hidden.contains(message.trim());
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
    return familyBlurShell(
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
                  child: _picking ? _picker() : _form(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _picker() {
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
          'Published stories from ${widget.parentName}',
          style: GoogleFonts.literata(color: albumInk, fontSize: 14),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('start-timeline-search'),
          controller: _search,
          decoration: const InputDecoration(
            hintText: 'Search stories',
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final story in _visible)
                ListTile(
                  key: Key('start-timeline-story-${story.id}'),
                  title: Text(storyTitle(story)),
                  subtitle: Text('${story.timeframeStart!.year}'),
                  onTap: () {
                    setState(() {
                      _origin = story;
                      _year.text = _prefill(story);
                      _picking = false;
                      _error = null;
                    });
                  },
                ),
            ],
          ),
        ),
        TextButton(
          key: const Key('start-timeline-write'),
          onPressed: () {
            Navigator.pop(context);
            widget.onWriteStory?.call();
          },
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

  Widget _form() {
    final origin = _origin;
    return SingleChildScrollView(
      child: Column(
        key: const Key('start-timeline-dialog'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Start a new timeline',
            style: GoogleFonts.newsreader(
              color: albumInk,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (origin != null) ...[
            const SizedBox(height: 12),
            DecoratedBox(
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
                            '${storyTitle(origin)} · ${origin.timeframeStart!.year}',
                            style: GoogleFonts.literata(
                              color: albumInk,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.allowChange)
                      TextButton(
                        key: const Key('start-timeline-change'),
                        onPressed: () => setState(() => _picking = true),
                        child: const Text('Change'),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Timeline name',
            style: GoogleFonts.sourceSans3(fontSize: 14, color: albumInk),
          ),
          const SizedBox(height: 4),
          TextField(
            key: const Key('start-timeline-name'),
            controller: _name,
            decoration: const InputDecoration(
              hintText: 'e.g. The Morgan-Reyes',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('start-timeline-owner'),
            initialValue: _ownerId,
            decoration: const InputDecoration(
              labelText: 'Owner',
              filled: true,
              fillColor: Colors.white,
            ),
            items: [
              for (final person in _members)
                DropdownMenuItem(
                  value: person.userId,
                  child: Text(_ownerLabel(person)),
                ),
            ],
            onChanged: _loaded
                ? (value) => setState(() => _ownerId = value)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            'Members',
            style: GoogleFonts.sourceSans3(fontSize: 14, color: albumInk),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final person in _people)
                FilterChip(
                  key: Key('start-timeline-member-${person.id}'),
                  showCheckmark: false,
                  label: Text(
                    displayNameOrMember(person.name),
                    style: GoogleFonts.sourceSans3(
                      color: _pickedPeople.contains(person.id)
                          ? Colors.white
                          : albumInk,
                      fontSize: 14,
                    ),
                  ),
                  selected: _pickedPeople.contains(person.id),
                  selectedColor: albumSage,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: _pickedPeople.contains(person.id)
                        ? albumSage
                        : albumInk.withValues(alpha: 0.3),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _pickedPeople.add(person.id);
                      } else {
                        _pickedPeople.remove(person.id);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Attaches in *', style: GoogleFonts.sourceSans3(fontSize: 14)),
          TextField(
            key: const Key('start-timeline-year'),
            controller: _year,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text("You'll stay in ${widget.parentName}."),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('start-timeline-error'),
              style: GoogleFonts.sourceSans3(
                color: albumTerracotta,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 16),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 12,
            children: [
              OutlinedButton(
                key: const Key('start-timeline-cancel'),
                onPressed: _busy ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: albumInk,
                  side: const BorderSide(color: albumInk),
                ),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('start-timeline-create'),
                onPressed: _canCreate ? _create : null,
                style: FilledButton.styleFrom(
                  backgroundColor: albumTerracotta,
                  disabledBackgroundColor: albumTerracotta.withValues(
                    alpha: 0.4,
                  ),
                ),
                child: const Text('Create timeline'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
