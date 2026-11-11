import 'dart:typed_data';

import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/data/photos_repository.dart';
import 'package:tell_me_a_story/core/data/server/server_errors.dart';
import 'package:tell_me_a_story/core/data/server/wire.dart';
import 'package:tell_me_a_story/core/domain/birth_visibility.dart';
import 'package:tell_me_a_story/core/domain/own_profile.dart';
import 'package:tell_me_a_story/core/domain/profile_repository.dart';

extension BirthVisibilityServer on BirthVisibility {
  server.BirthVisibility toServer() => switch (this) {
    BirthVisibility.hidden => server.BirthVisibility.hidden,
    BirthVisibility.year => server.BirthVisibility.year,
    BirthVisibility.yearMonth => server.BirthVisibility.yearMonth,
    BirthVisibility.full => server.BirthVisibility.full,
  };
}

BirthVisibility birthVisibilityFromServer(server.BirthVisibility value) =>
    switch (value) {
      server.BirthVisibility.hidden => BirthVisibility.hidden,
      server.BirthVisibility.year => BirthVisibility.year,
      server.BirthVisibility.yearMonth => BirthVisibility.yearMonth,
      server.BirthVisibility.full => BirthVisibility.full,
    };

OwnProfile ownProfileFromDto(server.OwnProfileDto dto) => OwnProfile(
  id: dto.authUserId.toString(),
  displayName: dto.displayName,
  email: dto.email,
  avatarPath: dto.avatarKey,
  birthDate: fromWireDate(dto.birthDate),
  birthPrecision: dto.birthPrecision == null
      ? null
      : precisionName(dto.birthPrecision!),
  birthVisibility: birthVisibilityFromServer(dto.birthVisibility),
  about: dto.about,
);

/// The caller's account through the `profile` endpoint; avatars through
/// `media`.
class ServerProfileRepository implements ProfileRepository {
  ServerProfileRepository({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  /// Null when nobody is signed in.
  @override
  Future<OwnProfile?> loadOwn() async {
    if (!_client.auth.isAuthenticated) return null;
    final dto = await withServerErrors(() => _client.profile.me());
    return ownProfileFromDto(dto);
  }

  @override
  Future<void> saveName(String displayName) {
    return withServerErrors(() => _client.profile.saveName(displayName));
  }

  @override
  Future<void> saveAccount({
    required String displayName,
    DateTime? birthDate,
    String? birthPrecision,
    BirthVisibility? birthVisibility,
    String? about,
  }) {
    return withServerErrors(
      () => _client.profile.saveAccount(
        displayName: displayName,
        birthDate: toWireDate(birthDate),
        birthPrecision: precisionFromName(birthPrecision),
        birthVisibility: birthVisibility?.toServer(),
        about: about,
      ),
    );
  }

  /// Compresses to a 512 px JPEG first, so undecodable bytes never leave.
  @override
  Future<String> saveAvatar(Uint8List bytes) {
    final compressed = compressStoryPhoto(bytes, maxEdge: 512, quality: 80);
    return withServerErrors(
      () => _client.profile.saveAvatar(ByteData.sublistView(compressed.bytes)),
    );
  }

  @override
  Future<void> clearAvatar() {
    return withServerErrors(() => _client.profile.clearAvatar());
  }

  @override
  Future<Uint8List?> downloadAvatar(String path) async {
    final data = await withServerErrors(() => _client.media.get(path));
    return data == null ? null : Uint8List.sublistView(data);
  }
}
