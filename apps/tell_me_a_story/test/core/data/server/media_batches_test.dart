import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/data/server/media_batches.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

/// Answers every `getMany` with one byte per key (the key's batch index), and
/// fails the batches listed in [failing].
class _FakeMedia extends server.EndpointMedia {
  _FakeMedia(super.caller, {this.failing = const {}});

  final Set<int> failing;
  final calls = <List<String>>[];

  @override
  Future<Map<String, ByteData>> getMany(List<String> keys) async {
    final batch = calls.length;
    calls.add(List.of(keys));
    if (failing.contains(batch)) throw Exception('response too large');
    return {
      for (final key in keys)
        key: ByteData.sublistView(Uint8List.fromList([batch])),
    };
  }
}

class _FakeClient extends server.Client {
  _FakeClient({Set<int> failing = const {}}) : super('http://127.0.0.1:1/') {
    fake = _FakeMedia(this, failing: failing);
  }

  late final _FakeMedia fake;

  @override
  server.EndpointMedia get media => fake;
}

List<String> _keys(int count) => [for (var i = 0; i < count; i++) 'k$i'];

void main() {
  test('the batch stays under the server cap of 16 keys per call', () {
    expect(mediaBatchSize, lessThanOrEqualTo(16));
  });

  test('no keys means no call', () async {
    final client = _FakeClient();

    expect(await getMediaBatched(client, const []), isEmpty);
    expect(client.fake.calls, isEmpty);
  });

  test('more keys than one batch go out in bounded calls and merge', () async {
    final client = _FakeClient();
    final keys = _keys(2 * mediaBatchSize + 3);

    final blobs = await getMediaBatched(client, keys);

    expect(client.fake.calls.map((c) => c.length), [
      mediaBatchSize,
      mediaBatchSize,
      3,
    ]);
    expect(client.fake.calls.expand((c) => c), keys);
    expect(blobs.keys, keys);
    expect(blobs['k0'], [0]);
    expect(blobs['k${2 * mediaBatchSize}'], [2]);
  });

  test('a failed batch leaves only its own keys out', () async {
    final client = _FakeClient(failing: {1});
    final keys = _keys(2 * mediaBatchSize + 1);

    final blobs = await getMediaBatched(client, keys);

    expect(blobs.keys, [...keys.take(mediaBatchSize), keys.last]);
  });
}
