import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/unexpected_payload_exception.dart';

void main() {
  test('listStewarded with no signed-in user throws NotSignedInException', () {
    final api = FamiliesApi(
      client: SupabaseClient('http://127.0.0.1', 'anon-key'),
    );
    expect(api.listStewarded(), throwsA(isA<NotSignedInException>()));
  });

  test('listMine with no signed-in user throws NotSignedInException', () {
    final api = FamiliesApi(
      client: SupabaseClient('http://127.0.0.1', 'anon-key'),
    );
    expect(api.listMine(), throwsA(isA<NotSignedInException>()));
  });

  test('listDirectory with no signed-in user throws NotSignedInException', () {
    final api = FamiliesApi(
      client: SupabaseClient('http://127.0.0.1', 'anon-key'),
    );
    expect(api.listDirectory(), throwsA(isA<NotSignedInException>()));
  });

  test('familyTreeRows keeps maps and drops other rows', () {
    final rows = familyTreeRows([
      {'id': 'parent', 'name': ' Morgan '},
      {'id': 'child'},
      'skip',
    ]);
    expect(rows, [
      {'id': 'parent', 'name': ' Morgan '},
      {'id': 'child'},
    ]);
    expect(familyTreeRows({'id': 'parent'}), isNull);
  });

  test('listFamilyTree maps a tree row', () async {
    final families = await _api([
      {
        'id': 'parent',
        'name': ' Morgan ',
        'parent_family_id': null,
        'branch_year': 1970,
        'origin_story_id': 'story-1',
      },
      'skip',
    ]).listFamilyTree('parent');
    expect(families, hasLength(1));
    expect(families.single.name, 'Morgan');
    expect(families.single.branchYear, 1970);
    expect(families.single.originStoryId, 'story-1');
  });

  test('listFamilyTree keeps an empty list empty', () async {
    final families = await _api(<Object?>[]).listFamilyTree('parent');
    expect(families, isEmpty);
  });

  test('listFamilyTree throws when the rpc is not a list', () async {
    await expectLater(
      _api({'id': 'parent'}).listFamilyTree('parent'),
      throwsA(
        isA<UnexpectedPayloadException>().having(
          (error) => error.rpc,
          'rpc',
          'list_family_tree',
        ),
      ),
    );
  });

  test('listOriginDependents throws when the rpc is not a list', () async {
    await expectLater(
      _api({'id': 'story'}).listOriginDependents('story'),
      throwsA(
        isA<UnexpectedPayloadException>().having(
          (error) => error.rpc,
          'rpc',
          'list_origin_dependents',
        ),
      ),
    );
  });
}

FamiliesApi _api(Object body) {
  return FamiliesApi(
    client: SupabaseClient(
      'http://localhost',
      'test-anon-key',
      httpClient: _TreeClient(body),
    ),
  );
}

class _TreeClient extends http.BaseClient {
  _TreeClient(this.body);

  final Object body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}
