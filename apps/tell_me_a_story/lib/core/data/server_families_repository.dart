import 'dart:typed_data';

import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/family_covers_repository.dart';
import 'package:tell_me_a_story/core/domain/family_detail.dart';
import 'package:tell_me_a_story/core/domain/family_directory.dart';
import 'package:tell_me_a_story/core/domain/family_directory_repository.dart';
import 'package:tell_me_a_story/core/domain/family_invite.dart';
import 'package:tell_me_a_story/core/domain/family_person.dart';
import 'package:tell_me_a_story/core/domain/family_roster.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/origin_dependent.dart';
import 'package:tell_me_a_story/core/domain/recovery_window.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/core/data/server_family_covers_repository.dart';
import 'package:tell_me_a_story/core/data/server/media_batches.dart';
import 'package:tell_me_a_story/core/data/server/server_errors.dart';
import 'package:tell_me_a_story/core/data/server/wire.dart';

/// A trimmed family name, or `Family` when blank.
String _familyName(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? 'Family' : trimmed;
}

MemberFamily memberFamilyFromDto(server.MemberFamilyDto dto) => MemberFamily(
  id: dto.id.toString(),
  name: _familyName(dto.name),
  parentFamilyId: dto.parentId?.toString(),
  createdAt: dto.createdAt,
  branchYear: dto.branchYear,
  role: roleName(dto.role),
  coverPhotoPath: dto.coverKey,
);

StewardFamily stewardFamilyFromDto(server.StewardFamilyDto dto) =>
    StewardFamily(
      id: dto.id.toString(),
      name: _familyName(dto.name),
      role: roleName(dto.role),
      deletedAt: dto.deletedAt,
    );

TreeFamily treeFamilyFromDto(server.TreeFamilyDto dto) => TreeFamily(
  id: dto.id.toString(),
  name: _familyName(dto.name),
  parentFamilyId: dto.parentId?.toString(),
  branchYear: dto.branchYear,
  originStoryId: dto.effectiveOriginStoryId?.toString(),
);

FamilyRoster familyRosterFromDto(server.FamilyRosterDto dto) => FamilyRoster(
  id: dto.id.toString(),
  name: _familyName(dto.name),
  role: roleName(dto.role),
  memberCount: dto.memberCount,
  publishedCount: dto.publishedCount,
  deletedAt: dto.deletedAt,
);

/// [avatars] holds downloaded avatar bytes by object key.
FamilyPerson familyPersonFromDto(
  server.FamilyMemberDto dto, {
  required Map<String, Uint8List> avatars,
}) => FamilyPerson(
  userId: dto.userId.toString(),
  role: roleName(dto.role),
  displayName: dto.displayName,
  avatarBytes: avatars[dto.avatarKey],
);

FamilyInvite familyInviteFromDto(server.PendingInviteDto dto) => FamilyInvite(
  id: dto.id.toString(),
  email: dto.email?.trim(),
  expiresAt: dto.expiresAt,
  createdAt: dto.createdAt,
  lastSentAt: dto.sentAt,
);

/// [avatars] holds downloaded member avatar bytes by object key.
FamilyDetail familyDetailFromDto(
  server.FamilyDetailDto dto, {
  required Map<String, Uint8List> avatars,
}) => FamilyDetail(
  id: dto.id.toString(),
  name: _familyName(dto.name),
  myRole: roleName(dto.myRole),
  people: [
    for (final member in dto.members)
      familyPersonFromDto(member, avatars: avatars),
  ],
  pendingInvites: [
    for (final invite in dto.pendingInvites) familyInviteFromDto(invite),
  ],
);

/// The set-origin copy users saw before the server cutover: forbidden and
/// not-found get fixed sentences; validation keeps the server's message.
/// Anything else is returned unchanged.
Object originErrorCopy(Object error) {
  if (error is! AppException) return error;
  return switch (error.code) {
    AppErrorCode.forbidden => const AppException(
      code: AppErrorCode.forbidden,
      message: 'You do not have permission to do that.',
    ),
    AppErrorCode.notFound => const AppException(
      code: AppErrorCode.notFound,
      message: 'Not found.',
    ),
    _ => error,
  };
}

/// Runs a set-origin call with [originErrorCopy] applied to its errors.
Future<T> _withOriginCopy<T>(Future<T> Function() call) async {
  try {
    return await withServerErrors(call);
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(originErrorCopy(error), stackTrace);
  }
}

class ServerFamiliesRepository
    implements
        FamiliesRepository,
        FamilyDirectoryRepository,
        FamilyCoverClient {
  ServerFamiliesRepository({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  ServerFamilyCoversRepository get _covers =>
      ServerFamilyCoversRepository(client: _injected);

  @override
  Future<Uint8List?> download(String? path) => _covers.download(path);

  @override
  Future<String> save({required String familyId, required Uint8List bytes}) {
    return _covers.save(familyId: familyId, bytes: bytes);
  }

  @override
  Future<void> clear({required String familyId, required String? path}) {
    return _covers.clear(familyId: familyId, path: path);
  }

  /// Uploads the hero and makes it the cover. The server queues the
  /// replaced cover for deletion, so [previousPath] is not used.
  @override
  Future<String> setCoverPhoto({
    required String familyId,
    required Uint8List bytes,
    String? previousPath,
  }) => save(familyId: familyId, bytes: bytes);

  /// Clears the cover; the server queues its object for deletion.
  @override
  Future<void> clearCoverPhoto({
    required String familyId,
    required String? path,
  }) => clear(familyId: familyId, path: path);

  @override
  Future<List<MemberFamily>> listMine() async {
    final rows = await withServerErrors(() => _client.family.listMine());
    return [for (final row in rows) memberFamilyFromDto(row)];
  }

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async {
    final rows = await withServerErrors(
      () => _client.family.listTree(server.UuidValue.fromString(familyId)),
    );
    return [for (final row in rows) treeFamilyFromDto(row)];
  }

  @override
  Future<void> setFamilyOrigin({
    required String familyId,
    required String storyId,
  }) {
    return _withOriginCopy(
      () => _client.family.setOrigin(
        server.UuidValue.fromString(familyId),
        server.UuidValue.fromString(storyId),
      ),
    );
  }

  @override
  Future<List<OriginDependent>> listOriginDependents(String storyId) async {
    final rows = await _withOriginCopy(
      () => _client.family.listOriginDependents(
        server.UuidValue.fromString(storyId),
      ),
    );
    return [
      for (final row in rows)
        OriginDependent(familyId: row.familyId.toString(), name: row.name),
    ];
  }

  /// The server returns live families and soft-deleted ones inside the
  /// recovery window.
  @override
  Future<List<StewardFamily>> listStewarded() async {
    final rows = await withServerErrors(() => _client.family.listStewarded());
    return [
      for (final row in rows)
        if (stewardFamilyFromDto(row) case final family
            when family.countsForManage())
          family,
    ];
  }

  @override
  Future<FamilyDirectory> listDirectory() async {
    final dto = await withServerErrors(() => _client.family.directory());
    return FamilyDirectory(
      active: [for (final row in dto.active) familyRosterFromDto(row)],
      recoverable: [
        for (final row in dto.recoverable)
          if (row.deletedAt case final deletedAt?
              when isInsideRecoveryWindow(deletedAt))
            familyRosterFromDto(row),
      ],
    );
  }

  @override
  Future<List<FamilyPerson>> listMembers(String familyId) async {
    final rows = await withServerErrors(
      () => _client.family.listMembers(server.UuidValue.fromString(familyId)),
    );
    final avatars = await _avatars([for (final row in rows) row.avatarKey]);
    return [for (final row in rows) familyPersonFromDto(row, avatars: avatars)];
  }

  /// Null when the caller cannot see [familyId].
  @override
  Future<FamilyDetail?> loadDetail(String familyId) async {
    final server.FamilyDetailDto dto;
    try {
      dto = await withServerErrors(
        () => _client.family.detail(server.UuidValue.fromString(familyId)),
      );
    } on AppException catch (error) {
      if (error.code == AppErrorCode.forbidden ||
          error.code == AppErrorCode.notFound) {
        return null;
      }
      rethrow;
    }
    final avatars = await _avatars([
      for (final member in dto.members) member.avatarKey,
    ]);
    return familyDetailFromDto(dto, avatars: avatars);
  }

  /// Avatar bytes by key. Avatars are decoration: a failed download leaves
  /// the initials.
  Future<Map<String, Uint8List>> _avatars(List<String?> keys) async {
    final wanted = {
      for (final key in keys)
        if (key != null && key.isNotEmpty) key,
    };
    if (wanted.isEmpty) return const {};
    return getMediaBatched(_client, wanted);
  }
}
