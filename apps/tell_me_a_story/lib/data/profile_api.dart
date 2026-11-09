import 'dart:typed_data';

import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/server/server_errors.dart';
import 'package:tell_me_a_story/data/server/wire.dart';

/// Who sees the account's birth date on its linked people.
enum BirthVisibility {
  hidden,
  year,
  yearMonth,
  full;

  server.BirthVisibility toServer() => switch (this) {
    BirthVisibility.hidden => server.BirthVisibility.hidden,
    BirthVisibility.year => server.BirthVisibility.year,
    BirthVisibility.yearMonth => server.BirthVisibility.yearMonth,
    BirthVisibility.full => server.BirthVisibility.full,
  };

  static BirthVisibility fromServer(server.BirthVisibility value) =>
      switch (value) {
        server.BirthVisibility.hidden => BirthVisibility.hidden,
        server.BirthVisibility.year => BirthVisibility.year,
        server.BirthVisibility.yearMonth => BirthVisibility.yearMonth,
        server.BirthVisibility.full => BirthVisibility.full,
      };
}

/// The signed-in user's account. The email is the login identity and is
/// read-only (D1). [avatarPath] is the avatar's blob key.
class OwnProfile {
  const OwnProfile({
    required this.id,
    this.displayName,
    this.email,
    this.avatarPath,
    this.birthDate,
    this.birthPrecision,
    this.birthVisibility = BirthVisibility.hidden,
    this.about,
  });

  final String id;
  final String? displayName;
  final String? email;
  final String? avatarPath;
  final DateTime? birthDate;
  final String? birthPrecision;
  final BirthVisibility birthVisibility;
  final String? about;

  factory OwnProfile.fromDto(server.OwnProfileDto dto) => OwnProfile(
    id: dto.authUserId.toString(),
    displayName: dto.displayName,
    email: dto.email,
    avatarPath: dto.avatarKey,
    birthDate: fromWireDate(dto.birthDate),
    birthPrecision: dto.birthPrecision == null
        ? null
        : precisionName(dto.birthPrecision!),
    birthVisibility: BirthVisibility.fromServer(dto.birthVisibility),
    about: dto.about,
  );
}

abstract class ProfileGateway {
  Future<OwnProfile?> loadOwn();

  /// Writes the display name only.
  Future<void> saveName(String displayName);

  /// One Save: display name, birth, and about. Does not write email or people.
  Future<void> saveAccount({
    required String displayName,
    DateTime? birthDate,
    String? birthPrecision,
    BirthVisibility? birthVisibility,
    String? about,
  });

  /// Stores [bytes] as the account avatar; returns its blob key.
  Future<String> saveAvatar(Uint8List bytes);

  /// Clears the account avatar.
  Future<void> clearAvatar();

  Future<Uint8List?> downloadAvatar(String path);
}

/// The caller's account through the `profile` endpoint; avatars through
/// `media`.
class ProfileApi implements ProfileGateway {
  ProfileApi({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  /// Null when nobody is signed in.
  @override
  Future<OwnProfile?> loadOwn() async {
    if (!_client.auth.isAuthenticated) return null;
    final dto = await withServerErrors(() => _client.profile.me());
    return OwnProfile.fromDto(dto);
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
