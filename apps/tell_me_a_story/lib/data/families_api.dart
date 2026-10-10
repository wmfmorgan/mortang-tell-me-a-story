import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'recovery_window.dart';

/// A family the signed-in member can already read.
class MemberFamily {
  const MemberFamily({
    required this.id,
    required this.name,
    required this.createdAt,
    this.parentFamilyId,
  });

  final String id;
  final String name;
  final String? parentFamilyId;
  final DateTime createdAt;

  factory MemberFamily.fromJson(Map<String, dynamic> json) {
    return MemberFamily(
      id: json['id'] as String,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Family',
      parentFamilyId: json['parent_family_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.utc(2020),
    );
  }
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

  bool countsForManage([DateTime? now]) {
    if (role != 'owner' && role != 'co_owner') return false;
    final deleted = deletedAt;
    if (deleted == null) return true;
    return isInsideRecoveryWindow(deleted, now);
  }
}

/// One live family from `list_family_tree`. [branchYear] stays null until M11.
class TreeFamily {
  const TreeFamily({
    required this.id,
    required this.name,
    this.parentFamilyId,
    this.branchYear,
  });

  final String id;
  final String name;
  final String? parentFamilyId;
  final int? branchYear;

  factory TreeFamily.fromJson(Map<String, dynamic> json) {
    final rawYear = json['branch_year'];
    return TreeFamily(
      id: json['id'] as String,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Family',
      parentFamilyId: json['parent_family_id'] as String?,
      branchYear: rawYear is num ? rawYear.toInt() : null,
    );
  }
}

abstract class FamiliesGateway {
  Future<List<MemberFamily>> listMine();

  /// Owner and co-owner families, including soft-deleted rows still inside
  /// the 60-day window. Live member-only families are not included.
  Future<List<StewardFamily>> listStewarded();

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
}

class FamilyInvite {
  const FamilyInvite({
    required this.id,
    required this.email,
    required this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String? email;
  final DateTime? expiresAt;

  /// Invites have no created_at column. Callers may pass one for display.
  /// Otherwise the sent date is [expiresAt] minus the 7-day invite window.
  final DateTime? createdAt;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  DateTime? get sentAt {
    if (createdAt != null) return createdAt;
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
}

abstract class FamilyDirectoryGateway {
  Future<FamilyDirectory> listDirectory();
  Future<FamilyDetail?> loadDetail(String familyId);
}

class FamiliesApi implements FamiliesGateway, FamilyDirectoryGateway {
  FamiliesApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<MemberFamily>> listMine() async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('memberships')
        .select(
          'families!inner(id, name, parent_family_id, created_at, deleted_at)',
        )
        .eq('user_id', uid)
        .isFilter('families.deleted_at', null);
    final families = <MemberFamily>[];
    for (final row in rows) {
      final embedded = row['families'];
      if (embedded is Map<String, dynamic>) {
        families.add(MemberFamily.fromJson(embedded));
      } else if (embedded is Map) {
        families.add(
          MemberFamily.fromJson(Map<String, dynamic>.from(embedded)),
        );
      }
    }
    return families;
  }

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async {
    final rows = await _client.rpc(
      'list_family_tree',
      params: {'fid': familyId},
    );
    if (rows is! List) return const [];
    final families = <TreeFamily>[];
    for (final row in rows) {
      if (row is Map<String, dynamic>) {
        families.add(TreeFamily.fromJson(row));
      } else if (row is Map) {
        families.add(TreeFamily.fromJson(Map<String, dynamic>.from(row)));
      }
    }
    return families;
  }

  @override
  Future<List<StewardFamily>> listStewarded() async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _membershipRows(uid, deleted: null, stewardOnly: true);
    final stewarded = <StewardFamily>[];
    for (final roster in _rosters(rows)) {
      final family = StewardFamily(
        id: roster.id,
        name: roster.name,
        role: roster.role,
        deletedAt: roster.deletedAt,
      );
      if (family.countsForManage()) stewarded.add(family);
    }
    return stewarded;
  }

  @override
  Future<FamilyDirectory> listDirectory() async {
    final uid = _client.auth.currentUser!.id;
    final activeRows = await _membershipRows(
      uid,
      deleted: false,
      stewardOnly: true,
    );
    final recoverableRows = await _membershipRows(
      uid,
      deleted: true,
      stewardOnly: true,
    );
    final active = _rosters(activeRows);
    final recoverable = [
      for (final row in _rosters(recoverableRows))
        if (row.deletedAt != null && isInsideRecoveryWindow(row.deletedAt!))
          row,
    ];
    final ids = [...active, ...recoverable].map((row) => row.id).toList();
    final members = await _counts('memberships', ids);
    final stories = await _publishedCounts(ids);
    FamilyRoster withCounts(FamilyRoster row) {
      return FamilyRoster(
        id: row.id,
        name: row.name,
        role: row.role,
        memberCount: members[row.id] ?? 0,
        publishedCount: stories[row.id] ?? 0,
        deletedAt: row.deletedAt,
      );
    }

    return FamilyDirectory(
      active: [for (final row in active) withCounts(row)],
      recoverable: [for (final row in recoverable) withCounts(row)],
    );
  }

  @override
  Future<FamilyDetail?> loadDetail(String familyId) async {
    final uid = _client.auth.currentUser?.id;
    final family = await _client
        .from('families')
        .select('id, name')
        .eq('id', familyId)
        .maybeSingle();
    if (family == null) return null;
    final rows = await _client
        .from('memberships')
        .select('user_id, role, profiles(display_name, avatar_path)')
        .eq('family_id', familyId);
    final people = <FamilyPerson>[];
    var myRole = 'member';
    for (final row in rows) {
      final userId = row['user_id'] as String?;
      final role = row['role'] as String? ?? 'member';
      if (userId == null) continue;
      if (userId == uid) myRole = role;
      final profile = row['profiles'];
      String? displayName;
      String? avatarPath;
      if (profile is Map) {
        displayName = profile['display_name'] as String?;
        avatarPath = profile['avatar_path'] as String?;
      }
      Uint8List? bytes;
      if (avatarPath != null && avatarPath.isNotEmpty) {
        try {
          bytes = await _client.storage.from('avatars').download(avatarPath);
        } catch (_) {
          bytes = null;
        }
      }
      people.add(
        FamilyPerson(
          userId: userId,
          role: role,
          displayName: displayName,
          avatarBytes: bytes,
        ),
      );
    }
    final inviteRows = await _client
        .from('invites')
        .select('id, email, expires_at')
        .eq('family_id', familyId)
        .eq('status', 'pending')
        .order('email');
    final pendingInvites = <FamilyInvite>[];
    for (final row in inviteRows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      final rawExpiry = row['expires_at'];
      pendingInvites.add(
        FamilyInvite(
          id: id,
          email: (row['email'] as String?)?.trim(),
          expiresAt: rawExpiry is String ? DateTime.tryParse(rawExpiry) : null,
        ),
      );
    }
    return FamilyDetail(
      id: family['id'] as String,
      name: (family['name'] as String?)?.trim().isNotEmpty == true
          ? (family['name'] as String).trim()
          : 'Family',
      myRole: myRole,
      people: people,
      pendingInvites: pendingInvites,
    );
  }

  Future<List<Map<String, dynamic>>> _membershipRows(
    String uid, {
    required bool? deleted,
    bool stewardOnly = false,
  }) async {
    var query = _client
        .from('memberships')
        .select('role, families!inner(id, name, deleted_at)')
        .eq('user_id', uid);
    if (stewardOnly) {
      query = query.inFilter('role', ['owner', 'co_owner']);
    }
    final List<dynamic> rows;
    if (deleted == null) {
      rows = await query;
    } else if (deleted) {
      rows = await query.not('families.deleted_at', 'is', null);
    } else {
      rows = await query.isFilter('families.deleted_at', null);
    }
    return [for (final row in rows) Map<String, dynamic>.from(row as Map)];
  }

  List<FamilyRoster> _rosters(List<dynamic> rows) {
    final rosters = <FamilyRoster>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final embedded = map['families'];
      if (embedded is! Map) continue;
      final family = Map<String, dynamic>.from(embedded);
      final id = family['id'];
      if (id is! String) continue;
      final deleted = family['deleted_at'];
      rosters.add(
        FamilyRoster(
          id: id,
          name: (family['name'] as String?)?.trim().isNotEmpty == true
              ? (family['name'] as String).trim()
              : 'Family',
          role: map['role'] as String? ?? 'member',
          memberCount: 0,
          publishedCount: 0,
          deletedAt: deleted is String ? DateTime.tryParse(deleted) : null,
        ),
      );
    }
    return rosters;
  }

  Future<Map<String, int>> _counts(String table, List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _client
        .from(table)
        .select('family_id')
        .inFilter('family_id', ids);
    final counts = <String, int>{};
    for (final row in rows) {
      final id = row['family_id'];
      if (id is String) counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, int>> _publishedCounts(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _client
        .from('stories')
        .select('family_id')
        .inFilter('family_id', ids)
        .eq('status', 'published');
    final counts = <String, int>{};
    for (final row in rows) {
      final id = row['family_id'];
      if (id is String) counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }
}
