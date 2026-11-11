import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/domain/perspective.dart';
import 'package:tell_me_a_story/core/domain/perspectives_repository.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/session/profile_session.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_chrome.dart';

/// Words in [text], split on whitespace. Empty text is 0.
int perspectiveWordCount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).length;
}

final _letter = RegExp(r'[A-Za-z]');

/// Group 0 of a match is the whole match and is never null.
String _upperMatch(RegExpMatch match) => match.group(0)!.toUpperCase();

String _firstLetter(String part) {
  final match = _letter.firstMatch(part);
  return match == null ? '' : _upperMatch(match);
}

String _perspectiveInitials(String name) {
  final letters = name
      .trim()
      .split(RegExp(r'\s+'))
      .map(_firstLetter)
      .where((letter) => letter.isNotEmpty)
      .toList();
  if (letters.isEmpty) return '';
  if (letters.length == 1) {
    final chars = _letter.allMatches(name.trim()).map(_upperMatch).toList();
    if (chars.isEmpty) return '';
    return chars.length == 1 ? chars.first : chars.take(2).join();
  }
  return letters.first + letters[1];
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

const _muted = Color(0xFF6B5E55);
const _line = Color(0xFFE7DECE);
const _panel = Color(0xFFF3EDE6);
const _panelBorder = Color(0x4DE7DECE);
const _fieldLine = Color(0x66E7DECE);

/// Full-telling overlay at `/stories/:storyId/perspective`.
class AddPerspectivePage extends ConsumerStatefulWidget {
  const AddPerspectivePage({
    super.key,
    required this.storyId,
    this.familyId,
    this.asDialog = false,
    this.postingAs,
    this.storyAuthorId,
    this.currentUserId,
    this.existing,
  });

  final String storyId;

  /// When set (reader extra / tests), skips [StoriesRepository.getStory].
  final String? familyId;

  /// Reader opens this as a dialog. The route page stays for the existing URL.
  final bool asDialog;

  /// Signed-in display name. When null, the page loads the profile if it can.
  final String? postingAs;

  /// Story author, used only to show the Author chip next to [postingAs].
  final String? storyAuthorId;
  final String? currentUserId;

  /// When set, the dialog edits this row instead of creating one.
  final Perspective? existing;

  static Future<Perspective?> show(
    BuildContext context, {
    required String storyId,
    String? familyId,
    String? postingAs,
    String? storyAuthorId,
    String? currentUserId,
    Perspective? existing,
  }) {
    return showAlbumDialog<Perspective>(
      context: context,
      maxWidth: 576,
      builder: (ctx) => AddPerspectivePage(
        storyId: storyId,
        familyId: familyId,
        asDialog: true,
        postingAs: postingAs,
        storyAuthorId: storyAuthorId,
        currentUserId: currentUserId,
        existing: existing,
      ),
    );
  }

  @override
  ConsumerState<AddPerspectivePage> createState() => _AddPerspectivePageState();
}

class _AddPerspectivePageState extends ConsumerState<AddPerspectivePage> {
  final _body = TextEditingController();
  var _busy = false;

  bool get _canPublish => !_busy && _body.text.trim().isNotEmpty;

  bool get _showAuthorChip {
    final authorId = widget.storyAuthorId;
    final userId = widget.currentUserId;
    return authorId != null &&
        authorId.isNotEmpty &&
        userId != null &&
        userId == authorId;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) _body.text = existing.body;
    if (_nonEmpty(widget.postingAs) == null) {
      // After the first frame: loading may update the profile provider.
      Future.microtask(() {
        if (!mounted) return;
        unawaited(ref.read(profileSessionProvider.notifier).ensureLoaded());
      });
    }
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<Perspective> _save(String body) async {
    final perspectives = ref.read(perspectivesRepositoryProvider);
    final existing = widget.existing;
    if (existing != null) {
      await perspectives.update(id: existing.id, body: body);
      return existing.copyWith(body: body);
    }
    final familyId =
        widget.familyId ??
        (await ref.read(storiesRepositoryProvider).getStory(widget.storyId))
            .familyId;
    return perspectives.create(
      storyId: widget.storyId,
      familyId: familyId,
      body: body,
    );
  }

  Future<void> _publish() async {
    if (!_canPublish) return;
    final body = _body.text.trim();
    setState(() => _busy = true);
    try {
      final saved = await _save(body);
      if (!mounted) return;
      if (widget.asDialog) {
        Navigator.of(context).pop(saved);
      } else {
        context.pop(saved);
      }
    } catch (_) {
      // Boundary: any failure is shown as the existing Try again copy.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Try again')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cancel() {
    if (_busy) return;
    if (widget.asDialog) {
      Navigator.of(context).pop();
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final postingAs =
        _nonEmpty(widget.postingAs) ??
        _nonEmpty(ref.watch(profileSessionProvider).displayName);
    final form = _PerspectiveForm(
      body: _body,
      busy: _busy,
      editing: widget.existing != null,
      postingAs: postingAs,
      showAuthorChip: _showAuthorChip,
      onChanged: () => setState(() {}),
      onCancel: _cancel,
      onPublish: _canPublish ? _publish : null,
    );
    if (widget.asDialog) {
      return Material(
        key: const Key('add-perspective'),
        color: albumParchment,
        child: form,
      );
    }
    return Scaffold(
      key: const Key('add-perspective'),
      appBar: const AlbumTopBar(),
      body: SafeArea(child: form),
    );
  }
}

class _PerspectiveForm extends StatelessWidget {
  const _PerspectiveForm({
    required this.body,
    required this.busy,
    required this.editing,
    required this.postingAs,
    required this.showAuthorChip,
    required this.onChanged,
    required this.onCancel,
    required this.onPublish,
  });

  final TextEditingController body;
  final bool busy;
  final bool editing;
  final String? postingAs;
  final bool showAuthorChip;
  final VoidCallback onChanged;
  final VoidCallback onCancel;
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    final name = postingAs;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(editing: editing, onClose: busy ? null : onCancel),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _line),
          if (name != null) ...[
            const SizedBox(height: 16),
            _PostingAs(name: name, showAuthorChip: showAuthorChip),
          ],
          const SizedBox(height: 20),
          _WordCount(words: perspectiveWordCount(body.text)),
          const SizedBox(height: 8),
          _BodyField(body: body, enabled: !busy, onChanged: onChanged),
          const SizedBox(height: 16),
          const _EditNotice(),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _line),
          const SizedBox(height: 16),
          _Actions(
            editing: editing,
            onCancel: busy ? null : onCancel,
            onPublish: onPublish,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.editing, required this.onClose});

  final bool editing;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow(),
              const SizedBox(height: 6),
              Text(
                editing ? 'Edit your perspective' : 'Add your perspective',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Provide your perspective of this story, or add some missing pieces',
                style: theme.textTheme.bodyMedium?.copyWith(color: _muted),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close modal',
          onPressed: onClose,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.diversity_1, size: 18, color: albumTerracotta),
        const SizedBox(width: 8),
        Text(
          'PERSPECTIVE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: albumSage,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _PostingAs extends StatelessWidget {
  const _PostingAs({required this.name, required this.showAuthorChip});

  final String name;
  final bool showAuthorChip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            _Initials(name: name),
            const SizedBox(width: 10),
            Text(
              'Posting as',
              style: theme.textTheme.labelMedium?.copyWith(color: _muted),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (showAuthorChip) ...[
              const SizedBox(width: 8),
              const _AuthorChip(),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuthorChip extends StatelessWidget {
  const _AuthorChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumTerracotta.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          'Author',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: albumTerracotta,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFE7D5CC),
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: Text(
            _perspectiveInitials(name),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: albumTerracotta),
          ),
        ),
      ),
    );
  }
}

class _WordCount extends StatelessWidget {
  const _WordCount({required this.words});

  final int words;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        Text(
          words == 1 ? '1 word' : '$words words',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: _muted),
        ),
      ],
    );
  }
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: width),
  );
}

class _BodyField extends StatelessWidget {
  const _BodyField({
    required this.body,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController body;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      key: const Key('perspective-body'),
      controller: body,
      minLines: 6,
      maxLines: 8,
      enabled: enabled,
      cursorColor: albumTerracotta,
      onChanged: (_) => onChanged(),
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: 'What do you remember? Who was there, what was said…',
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: albumInk.withValues(alpha: 0.38),
        ),
        filled: true,
        fillColor: Colors.white,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.all(14),
        border: _fieldBorder(_fieldLine),
        enabledBorder: _fieldBorder(_fieldLine),
        focusedBorder: _fieldBorder(albumTerracotta, width: 2),
        disabledBorder: _fieldBorder(_fieldLine),
      ),
    );
  }
}

class _EditNotice extends StatelessWidget {
  const _EditNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorder),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 18, color: albumTerracotta),
            SizedBox(width: 10),
            Expanded(child: _EditNoticeText()),
          ],
        ),
      ),
    );
  }
}

class _EditNoticeText extends StatelessWidget {
  const _EditNoticeText();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        style: theme.textTheme.labelMedium?.copyWith(
          color: _muted,
          height: 1.4,
        ),
        children: [
          const TextSpan(
            text: 'Only you can edit this perspective later. Use ',
          ),
          TextSpan(
            text: 'Comments',
            style: theme.textTheme.labelMedium?.copyWith(
              color: albumInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const TextSpan(text: ' below for short reactions.'),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.editing,
    required this.onCancel,
    required this.onPublish,
  });

  final bool editing;
  final VoidCallback? onCancel;
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onPublish,
          icon: const Icon(Icons.history_edu, size: 18),
          label: Text(editing ? 'Save' : 'Publish perspective'),
        ),
      ],
    );
  }
}
