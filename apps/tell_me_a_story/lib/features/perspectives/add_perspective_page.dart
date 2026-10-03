import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/album_chrome.dart';
import '../../core/theme/album_theme.dart';
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
    this.asDialog = false,
  });

  final String storyId;

  /// When set (reader extra / tests), skips [StoriesGateway.getStory].
  final String? familyId;
  final PerspectivesGateway? perspectivesApi;
  final StoriesGateway? storiesApi;

  /// Reader opens this as a dialog. The route page stays for the existing URL.
  final bool asDialog;

  static Future<Perspective?> show(
    BuildContext context, {
    required String storyId,
    String? familyId,
    PerspectivesGateway? perspectivesApi,
    StoriesGateway? storiesApi,
  }) {
    return showAlbumDialog<Perspective>(
      context: context,
      maxWidth: 560,
      builder: (ctx) => AddPerspectivePage(
        storyId: storyId,
        familyId: familyId,
        perspectivesApi: perspectivesApi,
        storiesApi: storiesApi,
        asDialog: true,
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
    if (widget.asDialog) {
      Navigator.of(context).pop();
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asDialog) return _dialog(context);
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('add-perspective'),
      appBar: AlbumTopBar(
        screenLabel: 'Add your perspective',
        actions: [TextButton(onPressed: _cancel, child: const Text('Cancel'))],
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

  Widget _dialog(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('add-perspective'),
      color: albumParchment,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add your perspective', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Tell this story in your own words — a full telling, not a quick reaction.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text('Your story', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              minLines: 4,
              maxLines: 6,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'What do you remember? Who was there, what was said…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _canPublish ? _publish : null,
              child: const Text('Publish perspective'),
            ),
            TextButton(
              onPressed: _busy ? null : _cancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
