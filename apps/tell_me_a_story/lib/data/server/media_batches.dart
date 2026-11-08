import 'dart:math';
import 'dart:typed_data';

import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/data/server/server_errors.dart';

/// Keys per `media.getMany` call. Eight compressed photos stay far below
/// Cloud Run's 32 MiB response cap, and the server refuses more than 16.
const mediaBatchSize = 8;

/// Blob bytes for [keys], by key, fetched [mediaBatchSize] keys per call, one
/// call at a time. Blobs are decoration: a missing blob is absent, and a
/// failed call leaves only its own batch out.
Future<Map<String, Uint8List>> getMediaBatched(
  server.Client client,
  Iterable<String> keys,
) async {
  final wanted = keys.toSet().toList();
  final out = <String, Uint8List>{};
  for (var start = 0; start < wanted.length; start += mediaBatchSize) {
    final batch = wanted.sublist(
      start,
      min(start + mediaBatchSize, wanted.length),
    );
    try {
      final blobs = await withServerErrors(() => client.media.getMany(batch));
      for (final MapEntry(:key, :value) in blobs.entries) {
        out[key] = Uint8List.sublistView(value);
      }
    } catch (_) {
      // This batch stays blank (parchment thumbs, initials avatars).
    }
  }
  return out;
}
