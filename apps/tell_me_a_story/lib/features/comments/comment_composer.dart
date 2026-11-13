import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/comments_api.dart';

/// Inline short comment field + Post. Empty/whitespace Post is a no-op.
class CommentComposer extends StatefulWidget {
  const CommentComposer({
    super.key,
    required this.onPost,
    this.focusNode,
    this.enabled = true,
    this.initialText,
    this.actionLabel = 'Post',
    this.onCancel,
    this.composerKey = const Key('comment-composer'),
    this.chrome = true,
  });

  /// Called with trimmed non-empty body. Throw to keep the field text.
  final Future<void> Function(String body) onPost;
  final FocusNode? focusNode;
  final bool enabled;

  /// Prefills the field. Used when editing an existing comment.
  final String? initialText;

  /// Primary button label. New comments use Post; edits use Save.
  final String actionLabel;
  final VoidCallback? onCancel;
  final Key composerKey;

  /// The new-comment card chrome. In-place edit turns this off.
  final bool chrome;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final _controller = TextEditingController();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialText;
    if (initial != null) _controller.text = initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !widget.enabled) return;
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.onPost(body);
      if (!mounted) return;
      _controller.clear();
    } catch (_) {
      // Caller shows SnackBar; keep text.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_busy;
    final field = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE7DECE)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE7DECE)),
                ),
              ),
            ),
          ),
          if (widget.onCancel != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: enabled ? widget.onCancel : null,
              child: const Text('Cancel'),
            ),
          ],
          const SizedBox(width: 8),
          FilledButton(
            onPressed: enabled ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: albumTerracotta,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            child: Text(widget.actionLabel),
          ),
        ],
      ),
    );
    if (!widget.chrome) {
      return KeyedSubtree(key: widget.composerKey, child: field);
    }
    return DecoratedBox(
      key: widget.composerKey,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1EB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7DECE)),
      ),
      child: field,
    );
  }
}

/// Comment body + author. Overflow Edit and Delete only when [canDelete].
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.canDelete,
    this.onDelete,
    this.onEdit,
    this.editing = false,
    this.onSave,
    this.onCancelEdit,
    this.editFocus,
  });

  final Comment comment;
  final bool canDelete;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool editing;
  final Future<void> Function(String body)? onSave;
  final VoidCallback? onCancelEdit;
  final FocusNode? editFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = comment.createdAt.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final date = '${months[when.month - 1]} ${when.day}, ${when.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF6F1EB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE7DECE)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _CommentInitials(comment.authorLabel),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          comment.authorLabel,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          '• $date',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF6B5E55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (editing && onSave != null)
                      CommentComposer(
                        onPost: onSave!,
                        focusNode: editFocus,
                        initialText: comment.body,
                        actionLabel: 'Save',
                        onCancel: onCancelEdit,
                        composerKey: Key('comment-edit-field-${comment.id}'),
                        chrome: false,
                      )
                    else
                      Text(comment.body, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              if (canDelete && !editing)
                PopupMenuButton<String>(
                  key: Key('comment-menu-${comment.id}'),
                  tooltip: 'Comment actions',
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      key: Key('comment-edit-${comment.id}'),
                      value: 'edit',
                      child: const Text('Edit'),
                    ),
                    PopupMenuItem<String>(
                      key: Key('comment-delete-${comment.id}'),
                      value: 'delete',
                      child: const Text('Delete'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentInitials extends StatelessWidget {
  const _CommentInitials(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final letters = parts.isEmpty
        ? '?'
        : parts.length == 1
        ? (parts.first.length == 1 ? parts.first : parts.first.substring(0, 2))
        : '${parts[0][0]}${parts[1][0]}';
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFE7D5CC),
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: Text(
            letters.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: albumTerracotta,
            ),
          ),
        ),
      ),
    );
  }
}
