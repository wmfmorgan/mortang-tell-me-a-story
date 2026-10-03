import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/album_chrome.dart';
import '../../core/theme/album_theme.dart';
import '../../data/perspectives_api.dart';
import '../../data/stories_api.dart';

/// Words in [text], split on whitespace. Empty text is 0.
int perspectiveWordCount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).length;
}

String _firstLetter(String part) {
  final match = RegExp(r'[A-Za-z]').firstMatch(part);
  return match == null ? '' : match.group(0)!.toUpperCase();
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
    final word = name.trim();
    final chars = RegExp(r'[A-Za-z]')
        .allMatches(word)
        .map((match) => match.group(0)!.toUpperCase())
        .toList();
    if (chars.isEmpty) return '';
    return chars.length == 1 ? chars.first : chars.take(2).join();
  }
  return letters.first + letters[1];
}

/// Full-telling overlay at `/stories/:storyId/perspective`.
class AddPerspectivePage extends StatefulWidget {
  const AddPerspectivePage({
    super.key,
    required this.storyId,
    this.familyId,
    this.perspectivesApi,
    this.storiesApi,
    this.asDialog = false,
    this.postingAs,
    this.storyAuthorId,
    this.currentUserId,
  });

  final String storyId;

  /// When set (reader extra / tests), skips [StoriesGateway.getStory].
  final String? familyId;
  final PerspectivesGateway? perspectivesApi;
  final StoriesGateway? storiesApi;

  /// Reader opens this as a dialog. The route page stays for the existing URL.
  final bool asDialog;

  /// Signed-in display name. When null, the page loads the profile if it can.
  final String? postingAs;

  /// Story author, used only to show the Author chip next to [postingAs].
  final String? storyAuthorId;
  final String? currentUserId;

  static Future<Perspective?> show(
    BuildContext context, {
    required String storyId,
    String? familyId,
    PerspectivesGateway? perspectivesApi,
    StoriesGateway? storiesApi,
    String? postingAs,
    String? storyAuthorId,
    String? currentUserId,
  }) {
    return showAlbumDialog<Perspective>(
      context: context,
      maxWidth: 576,
      builder: (ctx) => AddPerspectivePage(
        storyId: storyId,
        familyId: familyId,
        perspectivesApi: perspectivesApi,
        storiesApi: storiesApi,
        asDialog: true,
        postingAs: postingAs,
        storyAuthorId: storyAuthorId,
        currentUserId: currentUserId,
      ),
    );
  }

  @override
  State<AddPerspectivePage> createState() => _AddPerspectivePageState();
}

class _AddPerspectivePageState extends State<AddPerspectivePage> {
  PerspectivesGateway? _perspectivesOverride;
  StoriesGateway? _storiesOverride;
  final _body = TextEditingController();
  var _busy = false;
  String? _postingAs;

  PerspectivesGateway get _perspectives =>
      widget.perspectivesApi ?? (_perspectivesOverride ??= PerspectivesApi());

  StoriesGateway get _stories =>
      widget.storiesApi ?? (_storiesOverride ??= StoriesApi());

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
    _postingAs = widget.postingAs?.trim();
    if (_postingAs == null || _postingAs!.isEmpty) {
      _postingAs = null;
      _loadPostingAs();
    }
  }

  Future<void> _loadPostingAs() async {
    try {
      final client = Supabase.instance.client;
      final id = client.auth.currentUser?.id;
      if (id == null) return;
      final row = await client
          .from('profiles')
          .select('display_name')
          .eq('id', id)
          .maybeSingle();
      final name = (row?['display_name'] as String?)?.trim() ?? '';
      if (!mounted || name.isEmpty) return;
      setState(() => _postingAs = name);
    } catch (_) {
      // Tests and signed-out sessions have no profile row to show.
    }
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_canPublish) return;
    final body = _body.text.trim();
    setState(() => _busy = true);
    try {
      final familyId =
          widget.familyId ?? (await _stories.getStory(widget.storyId)).familyId;
      final created = await _perspectives.create(
        storyId: widget.storyId,
        familyId: familyId,
        body: body,
      );
      if (!mounted) return;
      if (widget.asDialog) {
        Navigator.of(context).pop(created);
      } else {
        context.pop(created);
      }
    } catch (_) {
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
    final form = _form(context);
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

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final words = perspectiveWordCount(_body.text);
    final wordLabel = words == 1 ? '1 word' : '$words words';
    final postingAs = _postingAs;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
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
                    Row(
                      children: [
                        const Icon(
                          Icons.diversity_1,
                          size: 18,
                          color: albumTerracotta,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'FAMILY PERSPECTIVE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: albumSage,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add your perspective',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tell this story in your own words — a full telling, not a quick reaction.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B5E55),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close modal',
                onPressed: _busy ? null : _cancel,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE7DECE)),
          if (postingAs != null) ...[
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF3EDE6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x4DE7DECE)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _initials(postingAs),
                    const SizedBox(width: 10),
                    Text(
                      'Posting as',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF6B5E55),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        postingAs,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_showAuthorChip) ...[
                      const SizedBox(width: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: albumTerracotta.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          child: Text(
                            'Author',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: albumTerracotta,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Your story',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                ' *',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: albumTerracotta,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                wordLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF6B5E55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('perspective-body'),
            controller: _body,
            minLines: 6,
            maxLines: 8,
            enabled: !_busy,
            cursorColor: albumTerracotta,
            onChanged: (_) => setState(() {}),
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
              border: _fieldBorder(const Color(0x66E7DECE)),
              enabledBorder: _fieldBorder(const Color(0x66E7DECE)),
              focusedBorder: _fieldBorder(albumTerracotta, width: 2),
              disabledBorder: _fieldBorder(const Color(0x66E7DECE)),
            ),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF3EDE6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x4DE7DECE)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: albumTerracotta,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF6B5E55),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE7DECE)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : _cancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _canPublish ? _publish : null,
                icon: const Icon(Icons.history_edu, size: 18),
                label: const Text('Publish perspective'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _initials(String name) {
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
