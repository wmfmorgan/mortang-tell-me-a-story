import 'package:flutter/material.dart';

import '../../core/theme/album_chrome.dart';
import '../../core/theme/album_theme.dart';
import '../../data/people_api.dart';

enum _AddPersonMode { chooseExisting, createNew }

/// Paint-only labels. Each chip writes this string to [PeopleGateway.createPerson].
const _relationshipChoices = [
  'Father',
  'Mother',
  'Grandparent',
  'Sibling',
  'Aunt/Uncle',
  'Cousin',
  'Spouse',
  'Family friend',
  'Other',
];

/// Add Person modal — pick existing family person or create new.
/// Create requires name + relationship; email optional (future invite).
class AddPersonModal extends StatefulWidget {
  const AddPersonModal({super.key, required this.familyId, required this.api});

  final String familyId;
  final PeopleGateway api;

  static Future<Person?> show(
    BuildContext context, {
    required String familyId,
    required PeopleGateway api,
  }) {
    return showAlbumDialog<Person>(
      context: context,
      maxWidth: 560,
      builder: (ctx) => AddPersonModal(familyId: familyId, api: api),
    );
  }

  @override
  State<AddPersonModal> createState() => _AddPersonModalState();
}

class _AddPersonModalState extends State<AddPersonModal> {
  _AddPersonMode _mode = _AddPersonMode.chooseExisting;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _searchController = TextEditingController();
  String? _relationship;

  List<Person>? _people;
  Object? _loadError;
  var _busy = false;
  String? _nameError;
  String? _relationshipError;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    setState(() {
      _loadError = null;
      _people = null;
    });
    try {
      final people = await widget.api.listPeople(widget.familyId);
      if (!mounted) return;
      setState(() => _people = people);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  Future<void> _saveCreate() async {
    final name = _nameController.text.trim();
    final relationship = _relationship?.trim() ?? '';
    final nameError = name.isEmpty ? 'Name is required' : null;
    final relationshipError = relationship.isEmpty
        ? 'Relationship is required'
        : null;
    if (nameError != null || relationshipError != null) {
      setState(() {
        _nameError = nameError;
        _relationshipError = relationshipError;
      });
      return;
    }
    setState(() {
      _busy = true;
      _nameError = null;
      _relationshipError = null;
    });
    try {
      final person = await widget.api.createPerson(
        familyId: widget.familyId,
        name: name,
        relationship: relationship,
        email: _emailController.text,
      );
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
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add person',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose or create',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<_AddPersonMode>(
              segments: const [
                ButtonSegment(
                  value: _AddPersonMode.chooseExisting,
                  label: Text('Choose existing'),
                ),
                ButtonSegment(
                  value: _AddPersonMode.createNew,
                  label: Text('Create new'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _busy
                  ? null
                  : (next) {
                      setState(() {
                        _mode = next.first;
                        _nameError = null;
                        _relationshipError = null;
                      });
                    },
            ),
            const SizedBox(height: 8),
            if (_mode == _AddPersonMode.chooseExisting)
              _buildPickList()
            else
              _buildCreateForm(),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickList() {
    if (_loadError != null) {
      return Column(
        children: [
          const Text('Couldn’t load people. Try again.'),
          TextButton(onPressed: _loadPeople, child: const Text('Try again')),
        ],
      );
    }
    final people = _people;
    if (people == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (people.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No people yet. Create a new person.'),
      );
    }
    final query = _searchController.text.trim().toLowerCase();
    final shown = query.isEmpty
        ? people
        : people
              .where(
                (person) =>
                    person.name.toLowerCase().contains(query) ||
                    person.relationship.toLowerCase().contains(query),
              )
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Search people',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No people match that search.'),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: shown.length,
              itemBuilder: (context, index) {
                final person = shown[index];
                return ListTile(
                  title: Text(person.name),
                  subtitle: Text(person.relationship),
                  onTap: () => Navigator.of(context).pop(person),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _relationshipChip(String choice) {
    final selected = _relationship == choice;
    return ChoiceChip(
      label: Text(choice),
      selected: selected,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: albumTerracotta,
      labelStyle: TextStyle(color: selected ? albumParchment : albumInk),
      onSelected: _busy
          ? null
          : (next) {
              setState(() {
                _relationship = next ? choice : null;
                _relationshipError = null;
              });
            },
    );
  }

  Widget _relationshipChips() {
    final chips = [
      for (final choice in _relationshipChoices) _relationshipChip(choice),
    ];
    if (MediaQuery.sizeOf(context).height >= 760) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final chip in chips)
            Padding(padding: const EdgeInsets.only(right: 8), child: chip),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Name', errorText: _nameError),
          onChanged: (_) {
            if (_nameError != null) {
              setState(() => _nameError = null);
            }
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Relationship', style: Theme.of(context).textTheme.titleSmall),
            if (_relationshipError != null) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  _relationshipError!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: albumTerracotta),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _relationshipChips(),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email (optional)'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _saveCreate,
          child: Text(_busy ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
