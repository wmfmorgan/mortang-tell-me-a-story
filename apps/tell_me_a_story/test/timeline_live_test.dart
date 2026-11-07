import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/timeline_live.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

const _family = '0190d7a0-0000-7000-8000-000000000001';
const _otherFamily = '0190d7a0-0000-7000-8000-000000000002';
const _story = '0190d7a0-0000-7000-8000-000000000003';

server.LiveEventDto _event({
  String family = _family,
  server.LiveKind kind = server.LiveKind.story,
  server.StoryStatus? status = server.StoryStatus.published,
  bool deleted = false,
}) => server.LiveEventDto(
  familyId: server.UuidValue.fromString(family),
  storyId: server.UuidValue.fromString(_story),
  kind: kind,
  storyStatus: status,
  deleted: deleted,
);

/// Hands out one controller per subscribe and records what was watched.
class _FakeLiveEndpoint extends server.EndpointLive {
  _FakeLiveEndpoint(super.caller);

  final families = <String>[];
  final stories = <String>[];
  final streams = <StreamController<server.LiveEventDto>>[];

  StreamController<server.LiveEventDto> get latest => streams.last;

  @override
  Stream<server.LiveEventDto> watchFamily(server.UuidValue familyId) {
    families.add(familyId.toString());
    return _open();
  }

  @override
  Stream<server.LiveEventDto> watchStory(server.UuidValue storyId) {
    stories.add(storyId.toString());
    return _open();
  }

  Stream<server.LiveEventDto> _open() {
    final controller = StreamController<server.LiveEventDto>();
    streams.add(controller);
    return controller.stream;
  }
}

class _FakeClient extends server.Client {
  _FakeClient() : super('http://127.0.0.1:1/');

  late final fake = _FakeLiveEndpoint(this);

  @override
  server.EndpointLive get live => fake;
}

void main() {
  group('timelineEventMatters', () {
    bool matters(server.LiveEventDto event) =>
        timelineEventMatters(familyId: _family, event: event);

    test('another family never refreshes the rail', () {
      expect(matters(_event(family: _otherFamily)), isFalse);
    });

    test('a draft story stays off the rail', () {
      expect(matters(_event(status: server.StoryStatus.draft)), isFalse);
    });

    test('published and deleted stories, photos and notes refresh', () {
      expect(matters(_event()), isTrue);
      expect(
        matters(_event(status: server.StoryStatus.draft, deleted: true)),
        isTrue,
      );
      expect(matters(_event(kind: server.LiveKind.photo)), isTrue);
      expect(matters(_event(kind: server.LiveKind.note, status: null)), isTrue);
    });
  });

  group('ServerTimelineLive', () {
    late _FakeClient client;
    late ServerTimelineLive live;
    late int changes;

    void watch([String familyId = _family]) =>
        live.watch(familyId: familyId, onChange: () => changes++);

    setUp(() {
      client = _FakeClient();
      live = ServerTimelineLive(client: client);
      changes = 0;
    });

    tearDown(() => live.dispose());

    testWidgets('matching events refresh once, 200 ms after the last', (
      tester,
    ) async {
      watch();
      client.fake.latest.add(_event());
      await tester.pump(const Duration(milliseconds: 100));
      client.fake.latest.add(_event(kind: server.LiveKind.photo));
      await tester.pump(const Duration(milliseconds: 199));
      expect(changes, 0);

      await tester.pump(const Duration(milliseconds: 1));
      expect(changes, 1);
      expect(client.fake.families, [_family]);
    });

    testWidgets('other families and drafts do not refresh', (tester) async {
      watch();
      client.fake.latest
        ..add(_event(family: _otherFamily))
        ..add(_event(status: server.StoryStatus.draft));
      await tester.pump(const Duration(seconds: 1));

      expect(changes, 0);
    });

    testWidgets('a stream error resubscribes with backoff, never throws', (
      tester,
    ) async {
      watch();
      client.fake.latest.addError(const server.WebSocketClosedException());
      await tester.pump(const Duration(milliseconds: 999));
      expect(client.fake.families, hasLength(1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(client.fake.families, hasLength(2));

      client.fake.latest.addError(const server.WebSocketClosedException());
      await tester.pump(const Duration(milliseconds: 1999));
      expect(client.fake.families, hasLength(2));
      await tester.pump(const Duration(milliseconds: 1));
      expect(client.fake.families, hasLength(3));

      // An event shows the feed is healthy: the next drop waits 1 s again.
      client.fake.latest.add(_event());
      await tester.pump(const Duration(milliseconds: 200));
      expect(changes, 1);
      client.fake.latest.addError(const server.WebSocketClosedException());
      await tester.pump(const Duration(seconds: 1));
      expect(client.fake.families, hasLength(4));
      expect(client.fake.families.toSet(), {_family});
    });

    testWidgets('the backoff stops growing at 30 s', (tester) async {
      watch();
      for (final wait in [1, 2, 4, 8, 16, 30, 30]) {
        final before = client.fake.families.length;
        client.fake.latest.addError(const server.WebSocketClosedException());
        await tester.pump(
          Duration(seconds: wait) - const Duration(milliseconds: 1),
        );
        expect(client.fake.families, hasLength(before), reason: '$wait s');
        await tester.pump(const Duration(milliseconds: 1));
        expect(client.fake.families, hasLength(before + 1), reason: '$wait s');
      }
    });

    testWidgets('a stream that ends resubscribes too', (tester) async {
      watch();
      await client.fake.latest.close();
      await tester.pump(const Duration(seconds: 1));

      expect(client.fake.families, hasLength(2));
    });

    for (final refusal in <String, Object Function()>{
      'forbidden': () => server.AppException(
        code: server.AppErrorCode.forbidden,
        message: 'member only',
      ),
      'notFound': () => server.AppException(
        code: server.AppErrorCode.notFound,
        message: 'not found',
      ),
      'unauthorized': server.ServerpodClientUnauthorized.new,
    }.entries) {
      testWidgets('a ${refusal.key} refusal stops the feed for good', (
        tester,
      ) async {
        watch();
        client.fake.latest.addError(refusal.value());
        await tester.pump(const Duration(minutes: 1));

        expect(client.fake.families, hasLength(1));
        expect(changes, 0);
      });
    }

    testWidgets('a refused story feed is not reopened either', (tester) async {
      live.watchStory(storyId: _story, onChange: () => changes++);
      client.fake.latest.addError(
        server.AppException(
          code: server.AppErrorCode.forbidden,
          message: 'forbidden',
        ),
      );
      await tester.pump(const Duration(minutes: 1));

      expect(client.fake.stories, [_story]);
    });

    testWidgets('dispose stops the stream, the debounce and the retry', (
      tester,
    ) async {
      watch();
      final first = client.fake.latest;
      first.add(_event());
      await tester.pump(const Duration(milliseconds: 50));
      live.dispose();
      await tester.pump(const Duration(minutes: 1));
      expect(changes, 0);
      expect(first.hasListener, isFalse);

      watch();
      client.fake.latest.addError(const server.WebSocketClosedException());
      live.dispose();
      await tester.pump(const Duration(minutes: 1));
      expect(client.fake.families, hasLength(2));
    });

    testWidgets('one stream per family; switching closes the old one', (
      tester,
    ) async {
      watch();
      watch();
      expect(client.fake.families, [_family]);
      final first = client.fake.latest;

      watch(_otherFamily);
      await tester.pump();
      expect(client.fake.families, [_family, _otherFamily]);
      expect(first.hasListener, isFalse);
    });

    testWidgets('watchStory refreshes on any event of its story', (
      tester,
    ) async {
      live.watchStory(storyId: _story, onChange: () => changes++);
      client.fake.latest.add(_event(kind: server.LiveKind.note, status: null));
      await tester.pump(const Duration(milliseconds: 200));

      expect(client.fake.stories, [_story]);
      expect(changes, 1);
    });
  });
}
