import 'dart:async';

import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import '../core/server/server_client.dart';

/// Whether a live event should refresh the open family timeline.
///
/// Other families and draft stories stay off the published rail.
bool timelineEventMatters({
  required String familyId,
  required server.LiveEventDto event,
}) {
  if (event.familyId.toString() != familyId) return false;
  if (event.kind == server.LiveKind.story &&
      !event.deleted &&
      event.storyStatus != null &&
      event.storyStatus != server.StoryStatus.published) {
    return false;
  }
  return true;
}

abstract class TimelineLive {
  void watch({required String familyId, required void Function() onChange});

  /// Reader feed for one story. The default does nothing so existing fakes
  /// keep compiling. The timeline [watch] stays on the family.
  void watchStory({
    required String storyId,
    required void Function() onChange,
  }) {}

  void dispose();
}

/// Live refreshes from the server's `live` streams: the timeline follows
/// `watchFamily`, the reader `watchStory`. A change calls `onChange` after
/// 200 ms without further events.
///
/// A stream that fails or ends (a dropped WebSocket, a refused or expired
/// sign-in) never reaches the UI. It is reopened after 1 s, doubling up to
/// 30 s while it keeps failing; any event resets the delay. [dispose] stops
/// both feeds.
class ServerTimelineLive implements TimelineLive {
  ServerTimelineLive({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  _LiveFeed? _family;
  String? _familyId;
  _LiveFeed? _story;
  String? _storyId;

  @override
  void watch({required String familyId, required void Function() onChange}) {
    if (_familyId == familyId && _family != null) return;
    _family?.close();
    _familyId = familyId;
    _family = _LiveFeed(
      open: () =>
          _client.live.watchFamily(server.UuidValue.fromString(familyId)),
      matters: (event) =>
          timelineEventMatters(familyId: familyId, event: event),
      onChange: onChange,
    );
  }

  @override
  void watchStory({
    required String storyId,
    required void Function() onChange,
  }) {
    if (_storyId == storyId && _story != null) return;
    _story?.close();
    _storyId = storyId;
    _story = _LiveFeed(
      open: () => _client.live.watchStory(server.UuidValue.fromString(storyId)),
      matters: (_) => true,
      onChange: onChange,
    );
  }

  @override
  void dispose() {
    _family?.close();
    _story?.close();
    _family = null;
    _story = null;
    _familyId = null;
    _storyId = null;
  }
}

/// One live subscription that reopens itself until [close].
class _LiveFeed {
  _LiveFeed({
    required this.open,
    required this.matters,
    required this.onChange,
  }) {
    _subscribe();
  }

  static const _quiet = Duration(milliseconds: 200);
  static const _firstRetry = Duration(seconds: 1);
  static const _maxRetry = Duration(seconds: 30);

  final Stream<server.LiveEventDto> Function() open;
  final bool Function(server.LiveEventDto event) matters;
  final void Function() onChange;

  StreamSubscription<server.LiveEventDto>? _subscription;
  Timer? _debounce;
  Timer? _retry;
  var _retryDelay = _firstRetry;
  var _closed = false;

  void _subscribe() {
    try {
      _subscription = open().listen(
        _onEvent,
        onError: (Object _) => _reopen(),
        onDone: _reopen,
        cancelOnError: true,
      );
    } catch (_) {
      // No client yet, or the call could not start: retry like a drop.
      _reopen();
    }
  }

  void _onEvent(server.LiveEventDto event) {
    _retryDelay = _firstRetry;
    if (!matters(event)) return;
    _debounce?.cancel();
    _debounce = Timer(_quiet, onChange);
  }

  void _reopen() {
    _subscription = null;
    if (_closed) return;
    _retry?.cancel();
    _retry = Timer(_retryDelay, _subscribe);
    final next = _retryDelay * 2;
    _retryDelay = next > _maxRetry ? _maxRetry : next;
  }

  void close() {
    _closed = true;
    _debounce?.cancel();
    _retry?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}
