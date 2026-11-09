/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _ida;
import 'package:serverpod/serverpod.dart' as _is;

/// serverOnly: tokenHash must never be serialized to the app; endpoints return a
/// PendingInviteDto (id, email, personId, sentAt, expiresAt, createdAt).
/// Status is derived: acceptedAt → accepted; revokedAt → revoked;
/// expiresAt <= now → expired; else pending.
abstract class Invite
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  Invite._({
    this.id,
    required this.familyId,
    required this.treeId,
    this.personId,
    this.email,
    required this.tokenHash,
    this.invitedById,
    this.acceptedById,
    this.acceptedAt,
    this.revokedAt,
    DateTime? lastSentAt,
    required this.expiresAt,
    DateTime? createdAt,
  }) : lastSentAt = lastSentAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  factory Invite({
    _is.UuidValue? id,
    required _is.UuidValue familyId,
    required _is.UuidValue treeId,
    _is.UuidValue? personId,
    String? email,
    required String tokenHash,
    _is.UuidValue? invitedById,
    _is.UuidValue? acceptedById,
    DateTime? acceptedAt,
    DateTime? revokedAt,
    DateTime? lastSentAt,
    required DateTime expiresAt,
    DateTime? createdAt,
  }) = _InviteImpl;

  factory Invite.fromJson(Map<String, dynamic> jsonSerialization) {
    return Invite(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      familyId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      treeId: _is.UuidValueJsonExtension.fromJson(jsonSerialization['treeId']),
      personId: jsonSerialization['personId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['personId']),
      email: jsonSerialization['email'] as String?,
      tokenHash: jsonSerialization['tokenHash'] as String,
      invitedById: jsonSerialization['invitedById'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['invitedById'],
            ),
      acceptedById: jsonSerialization['acceptedById'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['acceptedById'],
            ),
      acceptedAt: jsonSerialization['acceptedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['acceptedAt']),
      revokedAt: jsonSerialization['revokedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['revokedAt']),
      lastSentAt: jsonSerialization['lastSentAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['lastSentAt']),
      expiresAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = InviteTable();

  static const db = InviteRepository._();

  @override
  _is.UuidValue? id;

  _is.UuidValue familyId;

  /// Copy of families.treeId, kept equal by invites_family_tree_fk; invites_person_tree_fk keeps personId in the tree.
  _is.UuidValue treeId;

  _is.UuidValue? personId;

  /// Null = open link invite. Lower-cased/trimmed (CHECK).
  String? email;

  /// lowercase hex SHA-256 of the raw token (CHECK invites_token_hash_shape).
  String tokenHash;

  _is.UuidValue? invitedById;

  _is.UuidValue? acceptedById;

  DateTime? acceptedAt;

  DateTime? revokedAt;

  /// Set on create and on every resend.
  DateTime lastSentAt;

  /// Set by the app: now + 7 days (create and resend). No YAML default can express it.
  DateTime expiresAt;

  DateTime createdAt;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Invite]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Invite copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? familyId,
    _is.UuidValue? treeId,
    _is.UuidValue? personId = const _is.$UndefinedUuidValue(),
    String? email,
    String? tokenHash,
    _is.UuidValue? invitedById = const _is.$UndefinedUuidValue(),
    _is.UuidValue? acceptedById = const _is.$UndefinedUuidValue(),
    DateTime? acceptedAt = const _is.$UndefinedDateTime(),
    DateTime? revokedAt = const _is.$UndefinedDateTime(),
    DateTime? lastSentAt,
    DateTime? expiresAt,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Invite',
      if (id != null) 'id': id?.toJson(),
      'familyId': familyId.toJson(),
      'treeId': treeId.toJson(),
      if (personId != null) 'personId': personId?.toJson(),
      if (email != null) 'email': email,
      'tokenHash': tokenHash,
      if (invitedById != null) 'invitedById': invitedById?.toJson(),
      if (acceptedById != null) 'acceptedById': acceptedById?.toJson(),
      if (acceptedAt != null) 'acceptedAt': acceptedAt?.toJson(),
      if (revokedAt != null) 'revokedAt': revokedAt?.toJson(),
      'lastSentAt': lastSentAt.toJson(),
      'expiresAt': expiresAt.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static InviteInclude include() {
    return InviteInclude._();
  }

  static InviteIncludeList includeList({
    _is.WhereExpressionBuilder<InviteTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<InviteTable>? orderBy,
    _is.OrderByListBuilder<InviteTable>? orderByList,
    InviteInclude? include,
  }) {
    return InviteIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Invite.t),
      orderByList: orderByList?.call(Invite.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _InviteImpl extends Invite {
  _InviteImpl({
    _is.UuidValue? id,
    required _is.UuidValue familyId,
    required _is.UuidValue treeId,
    _is.UuidValue? personId,
    String? email,
    required String tokenHash,
    _is.UuidValue? invitedById,
    _is.UuidValue? acceptedById,
    DateTime? acceptedAt,
    DateTime? revokedAt,
    DateTime? lastSentAt,
    required DateTime expiresAt,
    DateTime? createdAt,
  }) : super._(
         id: id,
         familyId: familyId,
         treeId: treeId,
         personId: personId,
         email: email,
         tokenHash: tokenHash,
         invitedById: invitedById,
         acceptedById: acceptedById,
         acceptedAt: acceptedAt,
         revokedAt: revokedAt,
         lastSentAt: lastSentAt,
         expiresAt: expiresAt,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Invite]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Invite copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? familyId,
    _is.UuidValue? treeId,
    _is.UuidValue? personId = const _is.$UndefinedUuidValue(),
    Object? email = _Undefined,
    String? tokenHash,
    _is.UuidValue? invitedById = const _is.$UndefinedUuidValue(),
    _is.UuidValue? acceptedById = const _is.$UndefinedUuidValue(),
    DateTime? acceptedAt = const _is.$UndefinedDateTime(),
    DateTime? revokedAt = const _is.$UndefinedDateTime(),
    DateTime? lastSentAt,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return Invite(
      id: id is _is.UndefinedSentinel ? this.id : id,
      familyId: familyId ?? this.familyId,
      treeId: treeId ?? this.treeId,
      personId: personId is _is.UndefinedSentinel ? this.personId : personId,
      email: email is String? ? email : this.email,
      tokenHash: tokenHash ?? this.tokenHash,
      invitedById: invitedById is _is.UndefinedSentinel
          ? this.invitedById
          : invitedById,
      acceptedById: acceptedById is _is.UndefinedSentinel
          ? this.acceptedById
          : acceptedById,
      acceptedAt: acceptedAt is _is.UndefinedSentinel
          ? this.acceptedAt
          : acceptedAt,
      revokedAt: revokedAt is _is.UndefinedSentinel
          ? this.revokedAt
          : revokedAt,
      lastSentAt: lastSentAt ?? this.lastSentAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class InviteUpdateTable extends _is.UpdateTable<InviteTable> {
  InviteUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> familyId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.familyId,
        value,
      );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> treeId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.treeId,
        value,
      );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> personId(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.personId,
    value,
  );

  _is.ColumnValue<String, String> email(String? value) => _is.ColumnValue(
    table.email,
    value,
  );

  _is.ColumnValue<String, String> tokenHash(String value) => _is.ColumnValue(
    table.tokenHash,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> invitedById(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.invitedById,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> acceptedById(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.acceptedById,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> acceptedAt(DateTime? value) =>
      _is.ColumnValue(
        table.acceptedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> revokedAt(DateTime? value) =>
      _is.ColumnValue(
        table.revokedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> lastSentAt(DateTime value) =>
      _is.ColumnValue(
        table.lastSentAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> expiresAt(DateTime value) =>
      _is.ColumnValue(
        table.expiresAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class InviteTable extends _is.Table<_is.UuidValue?> {
  InviteTable({super.tableRelation}) : super(tableName: 'invites') {
    updateTable = InviteUpdateTable(this);
    familyId = _is.ColumnUuid(
      'familyId',
      this,
    );
    treeId = _is.ColumnUuid(
      'treeId',
      this,
    );
    personId = _is.ColumnUuid(
      'personId',
      this,
    );
    email = _is.ColumnString(
      'email',
      this,
    );
    tokenHash = _is.ColumnString(
      'tokenHash',
      this,
    );
    invitedById = _is.ColumnUuid(
      'invitedById',
      this,
    );
    acceptedById = _is.ColumnUuid(
      'acceptedById',
      this,
    );
    acceptedAt = _is.ColumnDateTime(
      'acceptedAt',
      this,
    );
    revokedAt = _is.ColumnDateTime(
      'revokedAt',
      this,
    );
    lastSentAt = _is.ColumnDateTime(
      'lastSentAt',
      this,
      hasDefault: true,
    );
    expiresAt = _is.ColumnDateTime(
      'expiresAt',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
  }

  late final InviteUpdateTable updateTable;

  late final _is.ColumnUuid familyId;

  /// Copy of families.treeId, kept equal by invites_family_tree_fk; invites_person_tree_fk keeps personId in the tree.
  late final _is.ColumnUuid treeId;

  late final _is.ColumnUuid personId;

  /// Null = open link invite. Lower-cased/trimmed (CHECK).
  late final _is.ColumnString email;

  /// lowercase hex SHA-256 of the raw token (CHECK invites_token_hash_shape).
  late final _is.ColumnString tokenHash;

  late final _is.ColumnUuid invitedById;

  late final _is.ColumnUuid acceptedById;

  late final _is.ColumnDateTime acceptedAt;

  late final _is.ColumnDateTime revokedAt;

  /// Set on create and on every resend.
  late final _is.ColumnDateTime lastSentAt;

  /// Set by the app: now + 7 days (create and resend). No YAML default can express it.
  late final _is.ColumnDateTime expiresAt;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    familyId,
    treeId,
    personId,
    email,
    tokenHash,
    invitedById,
    acceptedById,
    acceptedAt,
    revokedAt,
    lastSentAt,
    expiresAt,
    createdAt,
  ];
}

class InviteInclude extends _is.IncludeObject {
  InviteInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => Invite.t;
}

class InviteIncludeList extends _is.IncludeList {
  InviteIncludeList._({
    _is.WhereExpressionBuilder<InviteTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Invite.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => Invite.t;
}

class InviteRepository {
  const InviteRepository._();

  /// Returns a list of [Invite]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<Invite>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<InviteTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<InviteTable>? orderBy,
    _is.OrderByListBuilder<InviteTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Invite>(
      where: where?.call(Invite.t),
      orderBy: orderBy?.call(Invite.t),
      orderByList: orderByList?.call(Invite.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Invite]s matching the given query parameters every time the
  /// source tables are modified.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// Use [throttle] to specify the minimum interval between queries. It can
  /// also be set to `null`, in which case the stream will only be throttled
  /// when its subscription is paused.
  ///
  /// Source tables are collected from the queried table, [where], [orderBy],
  /// [orderByList], and the [include] graph. [alsoTriggerOnTables] is added
  /// to that set. Pass [Table] instances such as `Invite.t`.
  ///
  /// Raw [Expression] SQL is not inspected. Tables referenced only in raw
  /// SQL must be passed via [alsoTriggerOnTables].
  ///
  /// The stream always reads committed state and never joins an ambient
  /// [Transaction]. Emissions for a write fire after that write commits.
  ///
  /// Currently only supported on SQLite. Calling this method on PostgreSQL
  /// throws an [UnsupportedError].
  ///
  /// ```dart
  /// var subscription = Persons.db.watch(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// ).listen((persons) {
  ///   // Handle the latest matching rows.
  /// });
  /// ```
  _ida.Stream<List<Invite>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<InviteTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<InviteTable>? orderBy,
    _is.OrderByListBuilder<InviteTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Invite>(
      where: where?.call(Invite.t),
      orderBy: orderBy?.call(Invite.t),
      orderByList: orderByList?.call(Invite.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Invite] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<Invite?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<InviteTable>? where,
    int? offset,
    _is.OrderByBuilder<InviteTable>? orderBy,
    _is.OrderByListBuilder<InviteTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Invite>(
      where: where?.call(Invite.t),
      orderBy: orderBy?.call(Invite.t),
      orderByList: orderByList?.call(Invite.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Invite] by its [id] or null if no such row exists.
  Future<Invite?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Invite>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Invite]s in the list and returns the inserted rows.
  ///
  /// The returned [Invite]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Invite>> insert(
    _is.DatabaseSession session,
    List<Invite> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Invite>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Invite] and returns the inserted row.
  ///
  /// The returned [Invite] will have its `id` field set.
  Future<Invite> insertRow(
    _is.DatabaseSession session,
    Invite row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Invite>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Invite]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [Invite]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Invite>> upsert(
    _is.DatabaseSession session,
    List<Invite> rows, {
    required _is.ColumnSelections<InviteTable> conflictColumns,
    _is.ColumnSelections<InviteTable>? updateColumns,
    _is.WhereExpressionBuilder<InviteTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Invite>(
      rows,
      conflictColumns: conflictColumns(Invite.t),
      updateColumns: updateColumns?.call(Invite.t),
      updateWhere: updateWhere?.call(Invite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Invite] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [Invite] will have its `id` field set.
  Future<Invite?> upsertRow(
    _is.DatabaseSession session,
    Invite row, {
    required _is.ColumnSelections<InviteTable> conflictColumns,
    _is.ColumnSelections<InviteTable>? updateColumns,
    _is.WhereExpressionBuilder<InviteTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Invite>(
      row,
      conflictColumns: conflictColumns(Invite.t),
      updateColumns: updateColumns?.call(Invite.t),
      updateWhere: updateWhere?.call(Invite.t),
      transaction: transaction,
    );
  }

  /// Updates all [Invite]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Invite>> update(
    _is.DatabaseSession session,
    List<Invite> rows, {
    _is.ColumnSelections<InviteTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Invite>(
      rows,
      columns: columns?.call(Invite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Invite]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Invite> updateRow(
    _is.DatabaseSession session,
    Invite row, {
    _is.ColumnSelections<InviteTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Invite>(
      row,
      columns: columns?.call(Invite.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Invite] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Invite?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<InviteUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Invite>(
      id,
      columnValues: columnValues(Invite.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Invite]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Invite>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<InviteUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<InviteTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<InviteTable>? orderBy,
    _is.OrderByListBuilder<InviteTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Invite>(
      columnValues: columnValues(Invite.t.updateTable),
      where: where(Invite.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Invite.t),
      orderByList: orderByList?.call(Invite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Invite]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Invite>> delete(
    _is.DatabaseSession session,
    List<Invite> rows, {
    _is.OrderByBuilder<InviteTable>? orderBy,
    _is.OrderByListBuilder<InviteTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Invite>(
      rows,
      orderBy: orderBy?.call(Invite.t),
      orderByList: orderByList?.call(Invite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Invite].
  Future<Invite> deleteRow(
    _is.DatabaseSession session,
    Invite row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Invite>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Invite>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<InviteTable> where,
    _is.OrderByBuilder<InviteTable>? orderBy,
    _is.OrderByListBuilder<InviteTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Invite>(
      where: where(Invite.t),
      orderBy: orderBy?.call(Invite.t),
      orderByList: orderByList?.call(Invite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<InviteTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Invite>(
      where: where?.call(Invite.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Invite] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<InviteTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Invite>(
      where: where(Invite.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
