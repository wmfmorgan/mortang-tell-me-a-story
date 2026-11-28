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

class StoryCard extends StatefulWidget {
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
  State<StoryCard> createState() => _StoryCardState();
}

enum _CardArt { none, cover, fan }

/// Browse row height when the card is not given a finite height.
const _fallbackRowHeight = 64.0;

/// Width kept for the date and title when Open story is absent.
const _copyReserve = 96.0;

/// Width kept for the date line and the Open story button.
const _openReserve = 200.0;

/// Narrowest slot that still keeps a 4:3 cover readable.
const _minSlotWidth = 48.0;

class _StoryCardState extends State<StoryCard> {
  var _coverQuote = false;

  Story get story => widget.story;
  Color get ink => widget.ink;
  String get semanticsLabel => widget.semanticsLabel;
  String? get moreLabel => widget.moreLabel;
  bool get showBody => widget.showBody;
  VoidCallback? get onYear => widget.onYear;
  VoidCallback? get onCard => widget.onCard;
  VoidCallback? get onMore => widget.onMore;
  VoidCallback? get onOpen => widget.onOpen;
  PhotosGateway Function()? get photos => widget.photos;
  ThreadPhotoCache? get cache => widget.cache;

  void _setCoverQuote(bool showing) {
    if (!mounted || _coverQuote == showing) return;
    setState(() => _coverQuote = showing);
  }

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
    final full = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : _fallbackRowHeight;
    final wanted = full * 4 / 3;
    if (!constraints.maxWidth.isFinite) return Size(wanted, full);
    final reserve = onOpen == null ? _copyReserve : _openReserve;
    final cap = constraints.maxWidth - reserve;
    if (cap >= wanted) return Size(wanted, full);
    final width = cap < _minSlotWidth ? _minSlotWidth : cap;
    return Size(width, width * 3 / 4);
  }

  _CardArt get _artKind {
    if (story.photoPaths.isEmpty || photos == null || cache == null) {
      return _CardArt.none;
    }
    if (story.photoPaths.length == 1) return _CardArt.cover;
    return _CardArt.fan;
  }

  Widget _art() {
    final line = QuoteCard.firstLine(story.body);
    final gateway = photos;
    final store = cache;
    if (gateway == null || store == null) {
      return _fitted(QuoteCard(line: line));
    }
    return switch (_artKind) {
      _CardArt.none => _fitted(QuoteCard(line: line)),
      _CardArt.cover => PhotoCover(
        story: story,
        photos: gateway,
        cache: store,
        line: line,
        onQuote: _setCoverQuote,
      ),
      _CardArt.fan => _fitted(
        PhotoFan(story: story, photos: gateway, cache: store),
      ),
    };
  }

  Widget _fitted(Widget child) {
    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  Widget _copy(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
    final text = _bodyText();
    if (text.isEmpty) return const SizedBox.shrink();
    return threadTap(
      Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ink),
      ),
      onCard,
    );
  }

  String _bodyText() {
    final body = story.body?.trim() ?? '';
    if (body.isEmpty) return '';
    final quote = switch (_artKind) {
      _CardArt.none => true,
      _CardArt.fan => false,
      _CardArt.cover => _coverQuote,
    };
    if (!quote) return body;
    return QuoteCard.remainder(body);
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
