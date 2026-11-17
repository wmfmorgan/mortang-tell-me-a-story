import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/profile_api.dart';

void main() {
  test('avatar object path is {uid}/avatar.jpg', () {
    expect(
      avatarObjectPath('a1111111-1111-4111-8111-111111111111'),
      'a1111111-1111-4111-8111-111111111111/avatar.jpg',
    );
  });

  test('saveName writes display_name and not email', () async {
    final patches = <Map<String, dynamic>>[];
    final api = ProfileApi(
      userId: 'user-1',
      updateProfile: (patch) async => patches.add(patch),
    );

    await api.saveName('Ada Lovelace');

    expect(patches, [
      {'display_name': 'Ada Lovelace'},
    ]);
  });

  test('saveAvatar uploads the jpeg and sets avatar_path', () async {
    final uploads = <({String path, Uint8List bytes})>[];
    final patches = <Map<String, dynamic>>[];
    final api = ProfileApi(
      userId: 'user-1',
      uploadBinary: ({required path, required bytes}) async {
        uploads.add((path: path, bytes: bytes));
      },
      updateProfile: (patch) async => patches.add(patch),
    );
    final source = img.Image(width: 8, height: 8);
    img.fill(source, color: img.ColorRgb8(20, 40, 60));

    final path = await api.saveAvatar(
      Uint8List.fromList(img.encodeJpg(source)),
    );

    expect(path, 'user-1/avatar.jpg');
    expect(uploads.single.path, 'user-1/avatar.jpg');
    expect(uploads.single.bytes, isNotEmpty);
    expect(patches, [
      {'avatar_path': 'user-1/avatar.jpg'},
    ]);
  });

  test('undecodable bytes do not upload', () async {
    var uploads = 0;
    final api = ProfileApi(
      userId: 'user-1',
      uploadBinary: ({required path, required bytes}) async => uploads++,
      updateProfile: (patch) async {},
    );

    expect(
      () => api.saveAvatar(Uint8List.fromList([1, 2, 3])),
      throwsArgumentError,
    );
    expect(uploads, 0);
  });

  test('updateEmail does not write the profile row', () async {
    final emails = <String>[];
    var patches = 0;
    final api = ProfileApi(
      userId: 'user-1',
      updateEmail: (email) async => emails.add(email),
      updateProfile: (patch) async => patches++,
    );

    await api.updateEmail('next@example.com');

    expect(emails, ['next@example.com']);
    expect(patches, 0);
  });

  test('displayName returns the trimmed profile name', () async {
    final api = _profileApi(' Ada ');
    expect(await api.displayName('user-1'), 'Ada');
  });

  test(
    'displayName is null when the name is blank or the row is missing',
    () async {
      expect(await _profileApi('  ').displayName('user-1'), isNull);
      expect(await _profileApi(null).displayName('user-1'), isNull);
    },
  );
}

ProfileApi _profileApi(String? displayName) {
  return ProfileApi(
    client: SupabaseClient(
      'http://localhost',
      'test-anon-key',
      httpClient: _ProfileClient(displayName),
    ),
  );
}

class _ProfileClient extends http.BaseClient {
  _ProfileClient(this.displayName);

  final String? displayName;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final row = displayName == null
        ? const <Map<String, dynamic>>[]
        : [
            {'display_name': displayName},
          ];
    final bytes = utf8.encode(jsonEncode(row));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}
