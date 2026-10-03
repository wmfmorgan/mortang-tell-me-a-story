import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/album_chrome.dart';
import '../../data/perspectives_api.dart';
import '../../data/stories_api.dart';

/// Full-telling overlay at `/stories/:storyId/perspective`.
class AddPerspectivePage extends StatefulWidget {
  const AddPerspectivePage({
    super.key,
    required this.storyId,
    this.familyId,
    this.perspectivesApi,
    this.storiesApi,
  });

  final String storyId;

  /// When set (reader extra / tests), skips [StoriesGateway.getStory].
  final String? familyId;
  final PerspectivesGateway? perspectivesApi;
  final StoriesGateway? storiesApi;

  @override
  State<AddPerspectivePage> createState() => _AddPerspectivePageState();
}

class _AddPerspectivePageState extends State<AddPerspectivePage> {
  PerspectivesGateway? _perspectivesOverride;
  StoriesGateway? _storiesOverride;
  final _body = TextEditingController();
  var _busy = false;

  PerspectivesGateway get _perspectives =>
      widget.perspectivesApi ?? (_perspectivesOverride ??= PerspectivesApi());

  StoriesGateway get _stories =>
      widget.storiesApi ?? (_storiesOverride ??= StoriesApi());

  bool get _canPublish => !_busy && _body.text.trim().isNotEmpty;

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
      context.pop(created);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Try again')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('add-perspective'),
      appBar: AlbumTopBar(
        screenLabel: 'Add your perspective',
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: SafeArea(
        child: AlbumColumn(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tell this story in your own words — a full telling, not a quick reaction.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                AlbumPanel(
                  title: 'Your story',
                  child: TextField(
                    controller: _body,
                    minLines: 8,
                    maxLines: null,
                    enabled: !_busy,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText:
                          'What do you remember? Who was there, what was said…',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _canPublish ? _publish : null,
                  child: const Text('Publish perspective'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
