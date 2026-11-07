import 'dart:typed_data';

import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import '../core/server/server_client.dart';
import 'app_exception.dart';
import 'family_covers.dart';
import 'recovery_window.dart';
import 'server/server_errors.dart';
import 'server/wire.dart';

/// A trimmed family name, or `Family` when blank.
String _familyName(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? 'Family' : trimmed;
}

/// A family the signed-in member can already read.
class MemberFamily {
  const MemberFamily({
    required this.id,
    required this.name,
    required this.createdAt,
    this.parentFamilyId,
    this.branchYear,
    this.role,
    this.coverPhotoPath,
  });

  final String id;
  final String name;
  final String? parentFamilyId;
  final DateTime createdAt;

  /// `families.branch_year`; null when the family has no attach year.
  final int? branchYear;

  /// The caller's `memberships.role` ('owner', 'co_owner', 'member');
  /// null when the row did not come from `listMine()`.
  final String? role;

  /// Object key in `family-covers`, or null when the hero is a placeholder.
  final String? coverPhotoPath;

  factory MemberFamily.fromDto(server.MemberFamilyDto dto) => MemberFamily(
    id: dto.id.toString(),
    name: _familyName(dto.name),
    parentFamilyId: dto.parentId?.toString(),
    createdAt: dto.createdAt,
    branchYear: dto.branchYear,
    role: roleName(dto.role),
    coverPhotoPath: dto.coverKey,
  );
}

/// A family the caller owns or co-owns. [deletedAt] is set while it is
/// soft-deleted. The manage gate keeps rows still inside the 60-day window.
class StewardFamily {
  const StewardFamily({
    required this.id,
    required this.name,
    required this.role,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String role;
  final DateTime? deletedAt;

  factory StewardFamily.fromDto(server.StewardFamilyDto dto) => StewardFamily(
    id: dto.id.toString(),
    name: _familyName(dto.name),
    role: roleName(dto.role),
    deletedAt: dto.deletedAt,
  );

  bool countsForManage([DateTime? now]) {
    if (!originSteward(role)) return false;
    final deleted = deletedAt;
    if (deleted == null) return true;
    return isInsideRecoveryWindow(deleted, now);
  }
}

/// Owner or co-owner of a family. Other roles are false.
bool originSteward(String? role) => role == 'owner' || role == 'co_owner';

/// One live family from `family.listTree`.
/// [branchYear] and [originStoryId] are whatever the server returns.
class TreeFamily {
  const TreeFamily({
    required this.id,
    required this.name,
    this.parentFamilyId,
    this.branchYear,
    this.originStoryId,
  });

  final String id;
  final String name;
  final String? parentFamilyId;
  final int? branchYear;

  /// Effective origin from `family_origin`. Null when the timeline has none.
  final String? originStoryId;

  factory TreeFamily.fromDto(server.TreeFamilyDto dto) => TreeFamily(
    id: dto.id.toString(),
    name: _familyName(dto.name),
    parentFamilyId: dto.parentId?.toString(),
    branchYear: dto.branchYear,
    originStoryId: dto.effectiveOriginStoryId?.toString(),
  );
}

/// A live family whose effective origin is [storyId].
class OriginDependent {
  const OriginDependent({required this.familyId, required this.name});

  final String familyId;
  final String name;
}

abstract class FamiliesGateway {
  Future<List<MemberFamily>> listMine();

  /// Owner and co-owner families, including soft-deleted rows still inside
  /// the 60-day window. Live member-only families are not included.
  Future<List<StewardFamily>> listStewarded();

  Future<void> setFamilyOrigin({
    required String familyId,
    required String storyId,
  }) async {}

  Future<List<OriginDependent>> listOriginDependents(String storyId) async {
    return const [];
  }

  /// Upload the hero, then store its object key. Tests that never save
  /// inherit the unimplemented default.
  Future<String> setCoverPhoto({
    required String familyId,
    required Uint8List bytes,
    String? previousPath,
  }) {
    throw UnimplementedError();
  }

  /// Delete the hero object and clear `cover_photo_path`.
  Future<void> clearCoverPhoto({
    required String familyId,
    required String? path,
  }) {
    throw UnimplementedError();
  }

  /// Live members of [familyId], with accounts. The default is empty so
  /// callers that do not open the create form stay quiet.
  Future<List<FamilyPerson>> listMembers(String familyId) async => const [];

  /// Live families in the session family's tree. The default is the current
  /// family only, so marks and the related menu stay empty until a caller
  /// returns the rest of the tree.
  Future<List<TreeFamily>> listFamilyTree(String familyId) async {
    final mine = await listMine();
    for (final row in mine) {
      if (row.id == familyId) {
        return [
          TreeFamily(
            id: row.id,
            name: row.name,
            parentFamilyId: row.parentFamilyId,
          ),
        ];
      }
    }
    return const [];
  }
}

/// Hub card. Active rows have a null [deletedAt].
class FamilyRoster {
  const FamilyRoster({
    required this.id,
    required this.name,
    required this.role,
    required this.memberCount,
    required this.publishedCount,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String role;
  final int memberCount;
  final int publishedCount;
  final DateTime? deletedAt;

  factory FamilyRoster.fromDto(server.FamilyRosterDto dto) => FamilyRoster(
    id: dto.id.toString(),
    name: _familyName(dto.name),
    role: roleName(dto.role),
    memberCount: dto.memberCount,
    publishedCount: dto.publishedCount,
    deletedAt: dto.deletedAt,
  );
}

class FamilyDirectory {
  const FamilyDirectory({required this.active, required this.recoverable});

  final List<FamilyRoster> active;
  final List<FamilyRoster> recoverable;
}

class FamilyPerson {
  const FamilyPerson({
    required this.userId,
    required this.role,
    required this.displayName,
    this.avatarBytes,
  });

  final String userId;
  final String role;
  final String? displayName;
  final Uint8List? avatarBytes;

  /// [avatars] holds downloaded avatar bytes by object key.
  factory FamilyPerson.fromDto(
    server.FamilyMemberDto dto, {
    required Map<String, Uint8List> avatars,
  }) => FamilyPerson(
    userId: dto.userId.toString(),
    role: roleName(dto.role),
    displayName: dto.displayName,
    avatarBytes: avatars[dto.avatarKey],
  );
}

class FamilyInvite {
  const FamilyInvite({
    required this.id,
    required this.email,
    required this.expiresAt,
    this.createdAt,
    this.lastSentAt,
  });

  final String id;
  final String? email;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  /// When the invite was last emailed or resent.
  final DateTime? lastSentAt;

  factory FamilyInvite.fromDto(server.PendingInviteDto dto) => FamilyInvite(
    id: dto.id.toString(),
    email: dto.email?.trim(),
    expiresAt: dto.expiresAt,
    createdAt: dto.createdAt,
    lastSentAt: dto.sentAt,
  );

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// [lastSentAt], else [createdAt], else [expiresAt] minus the 7-day window.
  DateTime? get sentAt {
    final sent = lastSentAt ?? createdAt;
    if (sent != null) return sent;
    final expiry = expiresAt;
    if (expiry == null) return null;
    return expiry.subtract(const Duration(days: 7));
  }
}

const _albumMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Month and day, for invite sent and expiry lines. No new package.
String albumMonthDay(DateTime value) {
  final local = value.toLocal();
  return '${_albumMonths[local.month - 1]} ${local.day}';
}

class FamilyDetail {
  const FamilyDetail({
    required this.id,
    required this.name,
    required this.myRole,
    required this.people,
    this.pendingInvites = const [],
  });

  final String id;
  final String name;
  final String myRole;
  final List<FamilyPerson> people;
  final List<FamilyInvite> pendingInvites;

  /// [avatars] holds downloaded member avatar bytes by object key.
  factory FamilyDetail.fromDto(
    server.FamilyDetailDto dto, {
    required Map<String, Uint8List> avatars,
  }) => FamilyDetail(
    id: dto.id.toString(),
    name: _familyName(dto.name),
    myRole: roleName(dto.myRole),
    people: [
      for (final member in dto.members)
        FamilyPerson.fromDto(member, avatars: avatars),
    ],
    pendingInvites: [
      for (final invite in dto.pendingInvites) FamilyInvite.fromDto(invite),
    ],
  );
}

abstract class FamilyDirectoryGateway {
  Future<FamilyDirectory> listDirectory();
  Future<FamilyDetail?> loadDetail(String familyId);
}

class FamiliesApi
    implements FamiliesGateway, FamilyDirectoryGateway, FamilyCoverClient {
  FamiliesApi({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  FamilyCoversApi get _covers => FamilyCoversApi(client: _injected);

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
    return [for (final row in rows) MemberFamily.fromDto(row)];
  }

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async {
    final rows = await withServerErrors(
      () => _client.family.listTree(server.UuidValue.fromString(familyId)),
    );
    return [for (final row in rows) TreeFamily.fromDto(row)];
  }

  @override
  Future<void> setFamilyOrigin({
    required String familyId,
    required String storyId,
  }) {
    return withServerErrors(
      () => _client.family.setOrigin(
        server.UuidValue.fromString(familyId),
        server.UuidValue.fromString(storyId),
      ),
    );
  }

  @override
  Future<List<OriginDependent>> listOriginDependents(String storyId) async {
    final rows = await withServerErrors(
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
        if (StewardFamily.fromDto(row) case final family
            when family.countsForManage())
          family,
    ];
  }

  @override
  Future<FamilyDirectory> listDirectory() async {
    final dto = await withServerErrors(() => _client.family.directory());
    return FamilyDirectory(
      active: [for (final row in dto.active) FamilyRoster.fromDto(row)],
      recoverable: [
        for (final row in dto.recoverable)
          if (row.deletedAt != null && isInsideRecoveryWindow(row.deletedAt!))
            FamilyRoster.fromDto(row),
      ],
    );
  }

  @override
  Future<List<FamilyPerson>> listMembers(String familyId) async {
    final rows = await withServerErrors(
      () => _client.family.listMembers(server.UuidValue.fromString(familyId)),
    );
    final avatars = await _avatars([for (final row in rows) row.avatarKey]);
    return [
      for (final row in rows) FamilyPerson.fromDto(row, avatars: avatars),
    ];
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
    return FamilyDetail.fromDto(dto, avatars: avatars);
  }

  /// Avatar bytes by key. Avatars are decoration: a failed download leaves
  /// the initials.
  Future<Map<String, Uint8List>> _avatars(List<String?> keys) async {
    final wanted = {
      for (final key in keys)
        if (key != null && key.isNotEmpty) key,
    }.toList();
    if (wanted.isEmpty) return const {};
    try {
      final blobs = await withServerErrors(() => _client.media.getMany(wanted));
      return {
        for (final entry in blobs.entries)
          entry.key: Uint8List.sublistView(entry.value),
      };
    } catch (_) {
      return const {};
    }
  }
}
