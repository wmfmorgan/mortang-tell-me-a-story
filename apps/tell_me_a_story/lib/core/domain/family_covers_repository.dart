import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'family_covers_repository.g.dart';

/// Download, upload, and clear for family covers.
abstract class FamilyCoverClient {
  Future<Uint8List?> download(String? path);

  Future<String> save({required String familyId, required Uint8List bytes});

  Future<void> clear({required String familyId, required String? path});
}

/// The standalone family cover repository.
abstract class FamilyCoversRepository implements FamilyCoverClient {}

@Riverpod(keepAlive: true)
FamilyCoversRepository familyCoversRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');
