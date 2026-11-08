import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/perspectives_api.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

const _noteId = '0190d7a0-0000-7000-8000-0000000000c2';
const _storyId = '0190d7a0-0000-7000-8000-0000000000a1';
const _familyId = '0190d7a0-0000-7000-8000-0000000000f1';
const _authorId = '0190d7a0-0000-7000-8000-0000000000b1';

server.NoteDto _note({String? authorId = _authorId, String? authorName}) =>
    server.NoteDto(
      id: server.UuidValue.fromString(_noteId),
      storyId: server.UuidValue.fromString(_storyId),
      familyId: server.UuidValue.fromString(_familyId),
      kind: server.NoteKind.perspective,
      authorId: authorId == null ? null : server.UuidValue.fromString(authorId),
      authorName: authorName,
      body: 'hi',
      createdAt: DateTime.utc(2026, 9, 27),
      canDelete: true,
    );

void main() {
  group('displayNameOrMember', () {
    test('returns trimmed name', () {
      expect(displayNameOrMember('Aunt Clara'), 'Aunt Clara');
      expect(displayNameOrMember('  Ada  '), 'Ada');
    });

    test('falls back to Member when missing blank or null', () {
      expect(displayNameOrMember(null), 'Member');
      expect(displayNameOrMember(''), 'Member');
      expect(displayNameOrMember('   '), 'Member');
    });
  });

  group('Perspective.fromNote', () {
    test('maps ids, body, author name and canDelete', () {
      final perspective = Perspective.fromNote(_note(authorName: 'Aunt Clara'));
      expect(perspective.id, _noteId);
      expect(perspective.storyId, _storyId);
      expect(perspective.familyId, _familyId);
      expect(perspective.authorId, _authorId);
      expect(perspective.body, 'hi');
      expect(perspective.createdAt, DateTime.utc(2026, 9, 27));
      expect(perspective.authorDisplayName, 'Aunt Clara');
      expect(perspective.authorLabel, 'Aunt Clara');
      expect(perspective.canDelete, isTrue);
    });

    test('authorLabel is Member when the author is gone or unnamed', () {
      final gone = Perspective.fromNote(_note(authorId: null));
      expect(gone.authorId, isNull);
      expect(gone.authorLabel, 'Member');
      expect(
        Perspective.fromNote(_note(authorName: '  ')).authorLabel,
        'Member',
      );
    });

    test('canDelete defaults to false', () {
      final perspective = Perspective(
        id: 'p1',
        storyId: 's1',
        familyId: 'f1',
        authorId: 'u1',
        body: 'hi',
        createdAt: DateTime.utc(2026, 9, 27),
      );
      expect(perspective.canDelete, isFalse);
    });
  });

  group('ensureValidPerspectiveBody', () {
    test('accepts non-empty body', () {
      expect(() => ensureValidPerspectiveBody('hi'), returnsNormally);
      expect(() => ensureValidPerspectiveBody('  hi  '), returnsNormally);
    });

    test('rejects empty body', () {
      expect(
        () => ensureValidPerspectiveBody(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects whitespace-only body', () {
      expect(
        () => ensureValidPerspectiveBody('   '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('PerspectivesApi.create', () {
    test('rejects empty body before network', () {
      final api = PerspectivesApi(client: server.Client('http://127.0.0.1:1/'));
      expect(
        () => api.create(storyId: 's1', familyId: 'f1', body: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects whitespace-only body before network', () {
      final api = PerspectivesApi(client: server.Client('http://127.0.0.1:1/'));
      expect(
        () => api.create(storyId: 's1', familyId: 'f1', body: '  \n'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('FakePerspectivesGateway', () {
    late FakePerspectivesGateway gateway;

    setUp(() {
      gateway = FakePerspectivesGateway(authorId: 'u1');
    });

    test('create trims body', () async {
      final perspective = await gateway.create(
        storyId: 's1',
        familyId: 'f1',
        body: '  hi  ',
      );
      expect(perspective.body, 'hi');
      expect(perspective.authorId, 'u1');
    });

    test('create rejects empty body before insert', () async {
      await expectLater(
        () => gateway.create(storyId: 's1', familyId: 'f1', body: '  '),
        throwsA(isA<ArgumentError>()),
      );
      expect(gateway.rows, isEmpty);
    });

    test('listForStory returns perspectives ordered by created_at', () async {
      gateway.rows.addAll([
        Perspective(
          id: 'c-late',
          storyId: 's1',
          familyId: 'f1',
          authorId: 'u1',
          body: 'later',
          createdAt: DateTime.utc(2026, 9, 27, 2),
        ),
        Perspective(
          id: 'c-early',
          storyId: 's1',
          familyId: 'f1',
          authorId: 'u1',
          body: 'earlier',
          createdAt: DateTime.utc(2026, 9, 27, 1),
        ),
        Perspective(
          id: 'c-other',
          storyId: 's2',
          familyId: 'f1',
          authorId: 'u1',
          body: 'other story',
          createdAt: DateTime.utc(2026, 9, 27),
        ),
      ]);

      final listed = await gateway.listForStory('s1');
      expect(listed.map((p) => p.id), ['c-early', 'c-late']);
    });
  });
}

/// In-memory [PerspectivesGateway] that mirrors PerspectivesApi create validation.
class FakePerspectivesGateway implements PerspectivesGateway {
  FakePerspectivesGateway({required this.authorId});

  final String authorId;
  final List<Perspective> rows = [];
  var _seq = 0;

  @override
  Future<List<Perspective>> listForStory(String storyId) async {
    final filtered = rows.where((p) => p.storyId == storyId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return filtered;
  }

  @override
  Future<Perspective> create({
    required String storyId,
    required String familyId,
    required String body,
  }) async {
    ensureValidPerspectiveBody(body);
    final perspective = Perspective(
      id: 'c${++_seq}',
      storyId: storyId,
      familyId: familyId,
      authorId: authorId,
      body: body.trim(),
      createdAt: DateTime.utc(2026, 9, 27),
      canDelete: true,
    );
    rows.add(perspective);
    return perspective;
  }

  @override
  Future<void> update({required String id, required String body}) async {
    ensureValidPerspectiveBody(body);
    final index = rows.indexWhere((p) => p.id == id);
    if (index < 0) return;
    final current = rows[index];
    rows[index] = Perspective(
      id: current.id,
      storyId: current.storyId,
      familyId: current.familyId,
      authorId: current.authorId,
      body: body.trim(),
      createdAt: current.createdAt,
      authorDisplayName: current.authorDisplayName,
      canDelete: current.canDelete,
    );
  }

  @override
  Future<void> delete(String id) async {
    rows.removeWhere((p) => p.id == id);
  }
}
