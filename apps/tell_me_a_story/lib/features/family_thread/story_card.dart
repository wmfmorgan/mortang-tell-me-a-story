import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import '../stories/story_date.dart';
import 'family_thread_copy.dart';
import 'photo_cover.dart';
import 'photo_fan.dart';
import 'quote_card.dart';
import 'thread_photo_cache.dart';

class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.story,
    required this.ink,
    required this.semanticsLabel,
    this.moreLabel,
    this.showBody = false,
    this.onYear,
    this.onCard,
    this.onMore,
    this.onOpen,
    this.photos,
    this.cache,
  });

  final Story story;
  final Color ink;
  final String semanticsLabel;
  final String? moreLabel;
  final bool showBody;
  final VoidCallback? onYear;
  final VoidCallback? onCard;
  final VoidCallback? onMore;
  final VoidCallback? onOpen;
  final PhotosGateway Function()? photos;
  final ThreadPhotoCache? cache;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: LayoutBuilder(builder: _row),
    );
  }

  Widget _row(BuildContext context, BoxConstraints constraints) {
    final slot = _slot(constraints);
    return Row(
      children: [
        SizedBox(width: slot.width, height: slot.height, child: _art()),
        Expanded(child: _copy(context)),
        if (onOpen != null) _OpenStoryButton(onPressed: onOpen!),
      ],
    );
  }

  Size _slot(BoxConstraints constraints) {
    final full = constraints.maxHeight.isFinite ? constraints.maxHeight : 64.0;
    final wanted = full * 4 / 3;
    if (!constraints.maxWidth.isFinite) return Size(wanted, full);
    final reserve = onOpen == null ? 96.0 : 200.0;
    final cap = constraints.maxWidth - reserve;
    if (cap >= wanted) return Size(wanted, full);
    final width = cap < 48 ? 48.0 : cap;
    return Size(width, width * 3 / 4);
  }

  Widget _art() {
    final line = QuoteCard.firstLine(story.body);
    final gateway = photos;
    final store = cache;
    final count = story.photoPaths.length;
    if (count == 1 && gateway != null && store != null) {
      return PhotoCover(
        story: story,
        photos: gateway,
        cache: store,
        line: line,
      );
    }
    final child = count < 2 || gateway == null || store == null
        ? QuoteCard(line: line)
        : PhotoFan(story: story, photos: gateway, cache: store);
    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  bool _quoteOwns(String body) {
    if (story.photoPaths.isNotEmpty && photos != null && cache != null) {
      return false;
    }
    return QuoteCard.firstLine(body) == body;
  }

  Widget _copy(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dateLine(context),
          _title(context),
          if (showBody) _body(context),
          if (showBody) _places(context),
        ],
      ),
    );
  }

  Widget _dateLine(BuildContext context) {
    if (showBody || moreLabel == null) return _date(context);
    return Row(
      children: [
        Flexible(child: _date(context)),
        const SizedBox(width: 8),
        Flexible(child: _more(context)),
      ],
    );
  }

  Widget _date(BuildContext context) {
    final detail = _detail(story);
    final date = storyDateLabelFor(story);
    final line = !showBody && detail != null ? '$date · $detail' : date;
    return threadTap(
      Text(
        line,
        key: const Key('thread-year'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: ink),
      ),
      onYear ?? onCard,
    );
  }

  Widget _title(BuildContext context) {
    final title = story.title?.trim() ?? '';
    if (title.isEmpty) return const SizedBox.shrink();
    return threadTap(
      Text(
        title,
        maxLines: showBody ? 3 : 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: ink),
      ),
      onCard,
    );
  }

  Widget _body(BuildContext context) {
    final body = story.body?.trim() ?? '';
    if (body.isEmpty || _quoteOwns(body)) return const SizedBox.shrink();
    return Flexible(
      child: threadTap(
        Text(
          body,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ink),
        ),
        onCard,
      ),
    );
  }

  Widget _places(BuildContext context) {
    final detail = _detail(story);
    if (detail == null) return const SizedBox.shrink();
    return threadTap(
      Text(
        detail,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: ink),
      ),
      onCard,
    );
  }

  Widget _more(BuildContext context) {
    return threadTap(
      Text(
        moreLabel!,
        key: const Key('thread-more'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: albumTerracotta),
      ),
      onMore,
    );
  }
}

Widget threadTap(Widget child, VoidCallback? onTap) {
  if (onTap == null) return child;
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: child,
  );
}

String? _detail(Story story) {
  final place = story.placeLabel?.trim();
  final names = [
    for (final person in story.people)
      if (person.name.trim().isNotEmpty) person.name.trim(),
  ];
  final parts = [
    if (place != null && place.isNotEmpty) place,
    if (names.isNotEmpty) names.join(', '),
  ];
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

class _OpenStoryButton extends StatefulWidget {
  const _OpenStoryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_OpenStoryButton> createState() => _OpenStoryButtonState();
}

class _OpenStoryButtonState extends State<_OpenStoryButton> {
  final _node = FocusNode();

  @override
  void initState() {
    super.initState();
    _node.addListener(_changed);
  }

  @override
  void dispose() {
    _node.removeListener(_changed);
    _node.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final ring = _node.hasFocus;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _keepArrows,
      child: Container(
        key: const Key('open-story-ring'),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(albumCardRadius),
          border: Border.all(
            color: ring ? albumTerracotta : albumBackdropClear,
            width: 2,
          ),
        ),
        child: TextButton(
          key: const Key('open-story'),
          focusNode: _node,
          onPressed: widget.onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: albumTerracotta,
          ),
          child: const Text(FamilyThreadCopy.openStory),
        ),
      ),
    );
  }
}

KeyEventResult _keepArrows(FocusNode node, KeyEvent event) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return KeyEventResult.ignored;
  }
  return switch (event.logicalKey) {
    LogicalKeyboardKey.arrowUp ||
    LogicalKeyboardKey.arrowDown ||
    LogicalKeyboardKey.arrowLeft ||
    LogicalKeyboardKey.arrowRight => KeyEventResult.handled,
    _ => KeyEventResult.ignored,
  };
}
