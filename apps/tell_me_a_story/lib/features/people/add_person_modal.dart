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
  Person? _selectedPerson;

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

  void _setMode(_AddPersonMode mode) {
    setState(() {
      _mode = mode;
      _nameError = null;
      _relationshipError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final choosing = _mode == _AddPersonMode.chooseExisting;
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add person',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add someone to this story or your family circle',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: albumInk.withValues(alpha: 0.62),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _modeToggle(),
            const SizedBox(height: 16),
            if (choosing) _buildPickList() else _buildCreateForm(),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFEAE1D3)),
            const SizedBox(height: 12),
            _footer(choosing),
          ],
        ),
      ),
    );
  }

  Widget _modeToggle() {
    final count = _people?.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDE6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7DECE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _modeButton(
              mode: _AddPersonMode.chooseExisting,
              icon: Icons.group_outlined,
              label: 'Choose existing',
              badge: count == null ? null : '$count',
            ),
            _modeButton(
              mode: _AddPersonMode.createNew,
              icon: Icons.person_add_outlined,
              label: '+ Create new person',
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeButton({
    required _AddPersonMode mode,
    required IconData icon,
    required String label,
    String? badge,
  }) {
    final selected = _mode == mode;
    return Expanded(
      child: Material(
        color: selected ? const Color(0xFFFAF5EE) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? const Color(0xFFE8DFC8) : Colors.transparent,
          ),
        ),
        child: InkWell(
          onTap: _busy ? null : () => _setMode(mode),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? albumTerracotta
                      : albumInk.withValues(alpha: 0.62),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: albumTerracotta.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      child: Text(
                        badge,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: albumTerracotta,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer(bool choosing) {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return Row(
      children: [
        OutlinedButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: albumInk,
            side: const BorderSide(color: Color(0xFFDCD3C4)),
            shape: buttonShape,
          ),
          child: const Text('Cancel'),
        ),
        const Spacer(),
        if (choosing)
          FilledButton.icon(
            onPressed: _busy || _selectedPerson == null
                ? null
                : () => Navigator.of(context).pop(_selectedPerson),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: albumTerracotta,
              foregroundColor: Colors.white,
              disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.35),
              shape: buttonShape,
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Add to story'),
          )
        else
          FilledButton(
            onPressed: _busy ? null : _saveCreate,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: albumTerracotta,
              foregroundColor: Colors.white,
              shape: buttonShape,
            ),
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
      ],
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
        Row(
          children: [
            Text(
              'SELECT FAMILY MEMBER',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(letterSpacing: 0.6, fontWeight: FontWeight.w600),
            ),
            Text(
              ' *',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: albumTerracotta,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              'Choose one to tag',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: albumInk.withValues(alpha: 0.55)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          enabled: !_busy,
          decoration: InputDecoration(
            hintText: 'Search family members…',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: _fieldBorder(),
            enabledBorder: _fieldBorder(),
            focusedBorder: _fieldBorder(color: albumTerracotta, width: 1.5),
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
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: shown.length,
              itemBuilder: (context, index) {
                final person = shown[index];
                final selected = _selectedPerson?.id == person.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selected ? const Color(0xFFFAF5EE) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: selected
                            ? albumTerracotta
                            : const Color(0xFFE7DECE),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: selected
                            ? albumTerracotta
                            : const Color(0xFFF3EDE6),
                        foregroundColor: selected
                            ? Colors.white
                            : const Color(0xFF554942),
                        child: Text(
                          _initials(person.name),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF554942),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      title: Text(
                        person.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 16),
                      ),
                      subtitle: Text(
                        person.relationship,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: albumInk.withValues(alpha: 0.55)),
                      ),
                      trailing: selected
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: albumTerracotta,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Selected',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: albumTerracotta,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            )
                          : Text(
                              'Select',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: albumInk.withValues(alpha: 0.55),
                                  ),
                            ),
                      onTap: _busy
                          ? null
                          : () => setState(() => _selectedPerson = person),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  OutlineInputBorder _fieldBorder({
    Color color = const Color(0xFFDCD3C4),
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
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
          decoration: InputDecoration(
            labelText: 'Name',
            errorText: _nameError,
            filled: true,
            fillColor: Colors.white,
            border: _fieldBorder(),
            enabledBorder: _fieldBorder(),
            focusedBorder: _fieldBorder(color: albumTerracotta, width: 1.5),
          ),
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
          decoration: InputDecoration(
            labelText: 'Email (optional)',
            filled: true,
            fillColor: Colors.white,
            border: _fieldBorder(),
            enabledBorder: _fieldBorder(),
            focusedBorder: _fieldBorder(color: albumTerracotta, width: 1.5),
          ),
        ),
      ],
    );
  }
}
