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

abstract class Family
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  Family._({
    this.id,
    required this.treeId,
    this.parentId,
    required this.name,
    this.branchYear,
    this.originStoryId,
    this.coverKey,
    this.createdById,
    DateTime? createdAt,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Family({
    _is.UuidValue? id,
    required _is.UuidValue treeId,
    _is.UuidValue? parentId,
    required String name,
    int? branchYear,
    _is.UuidValue? originStoryId,
    String? coverKey,
    _is.UuidValue? createdById,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) = _FamilyImpl;

  factory Family.fromJson(Map<String, dynamic> jsonSerialization) {
    return Family(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      treeId: _is.UuidValueJsonExtension.fromJson(jsonSerialization['treeId']),
      parentId: jsonSerialization['parentId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['parentId']),
      name: jsonSerialization['name'] as String,
      branchYear: jsonSerialization['branchYear'] as int?,
      originStoryId: jsonSerialization['originStoryId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['originStoryId'],
            ),
      coverKey: jsonSerialization['coverKey'] as String?,
      createdById: jsonSerialization['createdById'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['createdById'],
            ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      deletedAt: jsonSerialization['deletedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['deletedAt']),
    );
  }

  static final t = FamilyTable();

  static const db = FamilyRepository._();

  @override
  _is.UuidValue? id;

  /// Immutable. Tree rows are deleted by the purge job only when empty.
  _is.UuidValue treeId;

  /// Branch parent; same tree enforced by raw FK families_parent_same_tree_fk.
  _is.UuidValue? parentId;

  String name;

  /// Attach year, 1000..9999 (CHECK families_branch_year_1000_9999). Null for roots.
  int? branchYear;

  /// Origin story: published, in the parent family (branch) or this family (root). Set at branch creation, changeable by stewards (setOrigin). Same tree enforced by families_origin_tree_fk; the effective origin is derived (§3.5).
  _is.UuidValue? originStoryId;

  /// Blob key, see §4. families/{familyId}/cover/{blobId}.{jpg|png|webp}
  String? coverKey;

  _is.UuidValue? createdById;

  DateTime createdAt;

  /// Soft delete; purged 60 days later by a future call.
  DateTime? deletedAt;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Family]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Family copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? treeId,
    _is.UuidValue? parentId = const _is.$UndefinedUuidValue(),
    String? name,
    int? branchYear,
    _is.UuidValue? originStoryId = const _is.$UndefinedUuidValue(),
    String? coverKey,
    _is.UuidValue? createdById = const _is.$UndefinedUuidValue(),
    DateTime? createdAt,
    DateTime? deletedAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Family',
      if (id != null) 'id': id?.toJson(),
      'treeId': treeId.toJson(),
      if (parentId != null) 'parentId': parentId?.toJson(),
      'name': name,
      if (branchYear != null) 'branchYear': branchYear,
      if (originStoryId != null) 'originStoryId': originStoryId?.toJson(),
      if (coverKey != null) 'coverKey': coverKey,
      if (createdById != null) 'createdById': createdById?.toJson(),
      'createdAt': createdAt.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Family',
      if (id != null) 'id': id?.toJson(),
      'treeId': treeId.toJson(),
      if (parentId != null) 'parentId': parentId?.toJson(),
      'name': name,
      if (branchYear != null) 'branchYear': branchYear,
      if (originStoryId != null) 'originStoryId': originStoryId?.toJson(),
      if (coverKey != null) 'coverKey': coverKey,
      if (createdById != null) 'createdById': createdById?.toJson(),
      'createdAt': createdAt.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  static FamilyInclude include() {
    return FamilyInclude._();
  }

  static FamilyIncludeList includeList({
    _is.WhereExpressionBuilder<FamilyTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FamilyTable>? orderBy,
    _is.OrderByListBuilder<FamilyTable>? orderByList,
    FamilyInclude? include,
  }) {
    return FamilyIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Family.t),
      orderByList: orderByList?.call(Family.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FamilyImpl extends Family {
  _FamilyImpl({
    _is.UuidValue? id,
    required _is.UuidValue treeId,
    _is.UuidValue? parentId,
    required String name,
    int? branchYear,
    _is.UuidValue? originStoryId,
    String? coverKey,
    _is.UuidValue? createdById,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) : super._(
         id: id,
         treeId: treeId,
         parentId: parentId,
         name: name,
         branchYear: branchYear,
         originStoryId: originStoryId,
         coverKey: coverKey,
         createdById: createdById,
         createdAt: createdAt,
         deletedAt: deletedAt,
       );

  /// Returns a shallow copy of this [Family]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Family copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? treeId,
    _is.UuidValue? parentId = const _is.$UndefinedUuidValue(),
    String? name,
    Object? branchYear = _Undefined,
    _is.UuidValue? originStoryId = const _is.$UndefinedUuidValue(),
    Object? coverKey = _Undefined,
    _is.UuidValue? createdById = const _is.$UndefinedUuidValue(),
    DateTime? createdAt,
    DateTime? deletedAt = const _is.$UndefinedDateTime(),
  }) {
    return Family(
      id: id is _is.UndefinedSentinel ? this.id : id,
      treeId: treeId ?? this.treeId,
      parentId: parentId is _is.UndefinedSentinel ? this.parentId : parentId,
      name: name ?? this.name,
      branchYear: branchYear is int? ? branchYear : this.branchYear,
      originStoryId: originStoryId is _is.UndefinedSentinel
          ? this.originStoryId
          : originStoryId,
      coverKey: coverKey is String? ? coverKey : this.coverKey,
      createdById: createdById is _is.UndefinedSentinel
          ? this.createdById
          : createdById,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt is _is.UndefinedSentinel
          ? this.deletedAt
          : deletedAt,
    );
  }
}

class FamilyUpdateTable extends _is.UpdateTable<FamilyTable> {
  FamilyUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> treeId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.treeId,
        value,
      );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> parentId(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.parentId,
    value,
  );

  _is.ColumnValue<String, String> name(String value) => _is.ColumnValue(
    table.name,
    value,
  );

  _is.ColumnValue<int, int> branchYear(int? value) => _is.ColumnValue(
    table.branchYear,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> originStoryId(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.originStoryId,
    value,
  );

  _is.ColumnValue<String, String> coverKey(String? value) => _is.ColumnValue(
    table.coverKey,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> createdById(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.createdById,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> deletedAt(DateTime? value) =>
      _is.ColumnValue(
        table.deletedAt,
        value,
      );
}

class FamilyTable extends _is.Table<_is.UuidValue?> {
  FamilyTable({super.tableRelation}) : super(tableName: 'families') {
    updateTable = FamilyUpdateTable(this);
    treeId = _is.ColumnUuid(
      'treeId',
      this,
    );
    parentId = _is.ColumnUuid(
      'parentId',
      this,
    );
    name = _is.ColumnString(
      'name',
      this,
    );
    branchYear = _is.ColumnInt(
      'branchYear',
      this,
    );
    originStoryId = _is.ColumnUuid(
      'originStoryId',
      this,
    );
    coverKey = _is.ColumnString(
      'coverKey',
      this,
    );
    createdById = _is.ColumnUuid(
      'createdById',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
    deletedAt = _is.ColumnDateTime(
      'deletedAt',
      this,
    );
  }

  late final FamilyUpdateTable updateTable;

  /// Immutable. Tree rows are deleted by the purge job only when empty.
  late final _is.ColumnUuid treeId;

  /// Branch parent; same tree enforced by raw FK families_parent_same_tree_fk.
  late final _is.ColumnUuid parentId;

  late final _is.ColumnString name;

  /// Attach year, 1000..9999 (CHECK families_branch_year_1000_9999). Null for roots.
  late final _is.ColumnInt branchYear;

  /// Origin story: published, in the parent family (branch) or this family (root). Set at branch creation, changeable by stewards (setOrigin). Same tree enforced by families_origin_tree_fk; the effective origin is derived (§3.5).
  late final _is.ColumnUuid originStoryId;

  /// Blob key, see §4. families/{familyId}/cover/{blobId}.{jpg|png|webp}
  late final _is.ColumnString coverKey;

  late final _is.ColumnUuid createdById;

  late final _is.ColumnDateTime createdAt;

  /// Soft delete; purged 60 days later by a future call.
  late final _is.ColumnDateTime deletedAt;

  @override
  List<_is.Column> get columns => [
    id,
    treeId,
    parentId,
    name,
    branchYear,
    originStoryId,
    coverKey,
    createdById,
    createdAt,
    deletedAt,
  ];
}

class FamilyInclude extends _is.IncludeObject {
  FamilyInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => Family.t;
}

class FamilyIncludeList extends _is.IncludeList {
  FamilyIncludeList._({
    _is.WhereExpressionBuilder<FamilyTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Family.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => Family.t;
}

class FamilyRepository {
  const FamilyRepository._();

  /// Returns a list of [Family]s matching the given query parameters.
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
  Future<List<Family>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FamilyTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FamilyTable>? orderBy,
    _is.OrderByListBuilder<FamilyTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Family>(
      where: where?.call(Family.t),
      orderBy: orderBy?.call(Family.t),
      orderByList: orderByList?.call(Family.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Family]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `Family.t`.
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
  _ida.Stream<List<Family>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FamilyTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FamilyTable>? orderBy,
    _is.OrderByListBuilder<FamilyTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Family>(
      where: where?.call(Family.t),
      orderBy: orderBy?.call(Family.t),
      orderByList: orderByList?.call(Family.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Family] matching the given query parameters.
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
  Future<Family?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FamilyTable>? where,
    int? offset,
    _is.OrderByBuilder<FamilyTable>? orderBy,
    _is.OrderByListBuilder<FamilyTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Family>(
      where: where?.call(Family.t),
      orderBy: orderBy?.call(Family.t),
      orderByList: orderByList?.call(Family.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Family] by its [id] or null if no such row exists.
  Future<Family?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Family>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Family]s in the list and returns the inserted rows.
  ///
  /// The returned [Family]s will have their `id` fields set.
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
  Future<List<Family>> insert(
    _is.DatabaseSession session,
    List<Family> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Family>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Family] and returns the inserted row.
  ///
  /// The returned [Family] will have its `id` field set.
  Future<Family> insertRow(
    _is.DatabaseSession session,
    Family row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Family>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Family]s in the list and returns the resulting rows.
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
  /// The returned [Family]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Family>> upsert(
    _is.DatabaseSession session,
    List<Family> rows, {
    required _is.ColumnSelections<FamilyTable> conflictColumns,
    _is.ColumnSelections<FamilyTable>? updateColumns,
    _is.WhereExpressionBuilder<FamilyTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Family>(
      rows,
      conflictColumns: conflictColumns(Family.t),
      updateColumns: updateColumns?.call(Family.t),
      updateWhere: updateWhere?.call(Family.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Family] and returns the resulting row.
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
  /// The returned [Family] will have its `id` field set.
  Future<Family?> upsertRow(
    _is.DatabaseSession session,
    Family row, {
    required _is.ColumnSelections<FamilyTable> conflictColumns,
    _is.ColumnSelections<FamilyTable>? updateColumns,
    _is.WhereExpressionBuilder<FamilyTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Family>(
      row,
      conflictColumns: conflictColumns(Family.t),
      updateColumns: updateColumns?.call(Family.t),
      updateWhere: updateWhere?.call(Family.t),
      transaction: transaction,
    );
  }

  /// Updates all [Family]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Family>> update(
    _is.DatabaseSession session,
    List<Family> rows, {
    _is.ColumnSelections<FamilyTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Family>(
      rows,
      columns: columns?.call(Family.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Family]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Family> updateRow(
    _is.DatabaseSession session,
    Family row, {
    _is.ColumnSelections<FamilyTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Family>(
      row,
      columns: columns?.call(Family.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Family] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Family?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<FamilyUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Family>(
      id,
      columnValues: columnValues(Family.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Family]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Family>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<FamilyUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<FamilyTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FamilyTable>? orderBy,
    _is.OrderByListBuilder<FamilyTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Family>(
      columnValues: columnValues(Family.t.updateTable),
      where: where(Family.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Family.t),
      orderByList: orderByList?.call(Family.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Family]s in the list and returns the deleted rows.
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
  Future<List<Family>> delete(
    _is.DatabaseSession session,
    List<Family> rows, {
    _is.OrderByBuilder<FamilyTable>? orderBy,
    _is.OrderByListBuilder<FamilyTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Family>(
      rows,
      orderBy: orderBy?.call(Family.t),
      orderByList: orderByList?.call(Family.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Family].
  Future<Family> deleteRow(
    _is.DatabaseSession session,
    Family row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Family>(
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
  Future<List<Family>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<FamilyTable> where,
    _is.OrderByBuilder<FamilyTable>? orderBy,
    _is.OrderByListBuilder<FamilyTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Family>(
      where: where(Family.t),
      orderBy: orderBy?.call(Family.t),
      orderByList: orderByList?.call(Family.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FamilyTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Family>(
      where: where?.call(Family.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Family] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<FamilyTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Family>(
      where: where(Family.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
