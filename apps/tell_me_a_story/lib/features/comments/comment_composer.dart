import 'package:flutter/material.dart';

import '../../data/comments_api.dart';

/// Inline short comment field + Post. Empty/whitespace Post is a no-op.
class CommentComposer extends StatefulWidget {
  const CommentComposer({
    super.key,
    required this.onPost,
    this.focusNode,
    this.enabled = true,
  });

  /// Called with trimmed non-empty body. Throw to keep the field text.
  final Future<void> Function(String body) onPost;
  final FocusNode? focusNode;
  final bool enabled;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final _controller = TextEditingController();
  var _busy = false;

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
    return Column(
      key: const Key('comment-composer'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          enabled: enabled,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: 'Share a short memory or note...',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: enabled ? _submit : null,
            child: const Text('Post'),
          ),
        ),
      ],
    );
  }
}

/// Comment body + author; overflow Delete only when [canDelete].
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.canDelete,
    this.onDelete,
  });

  final Comment comment;
  final bool canDelete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.authorLabel, style: theme.textTheme.titleSmall),
                Text(comment.body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          if (canDelete)
            PopupMenuButton<String>(
              key: Key('comment-menu-${comment.id}'),
              onSelected: (value) {
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }
}
