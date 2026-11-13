import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/perspectives_api.dart';

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

  group('Perspective.fromJson', () {
    test('parses nested author.display_name', () {
      final perspective = Perspective.fromJson({
        'id': 'c1',
        'story_id': 's1',
        'family_id': 'f1',
        'author_id': 'u1',
        'body': 'hi',
        'created_at': '2026-09-27T00:00:00Z',
        'author': {'display_name': 'Aunt Clara'},
      });
      expect(perspective.id, 'c1');
      expect(perspective.storyId, 's1');
      expect(perspective.familyId, 'f1');
      expect(perspective.authorId, 'u1');
      expect(perspective.body, 'hi');
      expect(perspective.createdAt, DateTime.parse('2026-09-27T00:00:00Z'));
      expect(perspective.authorDisplayName, 'Aunt Clara');
      expect(perspective.authorLabel, 'Aunt Clara');
    });

    test('authorLabel is Member when author embed is missing', () {
      final perspective = Perspective.fromJson({
        'id': 'c1',
        'story_id': 's1',
        'family_id': 'f1',
        'author_id': 'u1',
        'body': 'hi',
        'created_at': '2026-09-27T00:00:00Z',
      });
      expect(perspective.authorDisplayName, isNull);
      expect(perspective.authorLabel, 'Member');
    });

    test('authorLabel is Member when author is null', () {
      final perspective = Perspective.fromJson({
        'id': 'c1',
        'story_id': 's1',
        'family_id': 'f1',
        'author_id': 'u1',
        'body': 'hi',
        'created_at': '2026-09-27T00:00:00Z',
        'author': null,
      });
      expect(perspective.authorLabel, 'Member');
    });

    test('authorLabel is Member when display_name is null', () {
      final perspective = Perspective.fromJson({
        'id': 'c1',
        'story_id': 's1',
        'family_id': 'f1',
        'author_id': 'u1',
        'body': 'hi',
        'created_at': '2026-09-27T00:00:00Z',
        'author': {'display_name': null},
      });
      expect(perspective.authorDisplayName, isNull);
      expect(perspective.authorLabel, 'Member');
    });

    test('authorLabel is Member when display_name is blank', () {
      final perspective = Perspective.fromJson({
        'id': 'c1',
        'story_id': 's1',
        'family_id': 'f1',
        'author_id': 'u1',
        'body': 'hi',
        'created_at': '2026-09-27T00:00:00Z',
        'author': {'display_name': '  '},
      });
      expect(perspective.authorLabel, 'Member');
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
      final api = PerspectivesApi(
        client: SupabaseClient('http://127.0.0.1', 'anon-key'),
      );
      expect(
        () => api.create(storyId: 's1', familyId: 'f1', body: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects whitespace-only body before network', () {
      final api = PerspectivesApi(
        client: SupabaseClient('http://127.0.0.1', 'anon-key'),
      );
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
    );
  }

  @override
  Future<void> delete(String id) async {
    rows.removeWhere((p) => p.id == id);
  }
}
