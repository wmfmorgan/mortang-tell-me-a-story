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
import 'kinship_kind.dart' as _iq59nsdl;

/// Person-to-person edge inside one tree. Replaces the dropped free-text people.relationship.
abstract class Kinship
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  Kinship._({
    this.id,
    required this.treeId,
    required this.kind,
    required this.fromPersonId,
    required this.toPersonId,
    this.createdById,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Kinship({
    _is.UuidValue? id,
    required _is.UuidValue treeId,
    required _iq59nsdl.KinshipKind kind,
    required _is.UuidValue fromPersonId,
    required _is.UuidValue toPersonId,
    _is.UuidValue? createdById,
    DateTime? createdAt,
  }) = _KinshipImpl;

  factory Kinship.fromJson(Map<String, dynamic> jsonSerialization) {
    return Kinship(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      treeId: _is.UuidValueJsonExtension.fromJson(jsonSerialization['treeId']),
      kind: _iq59nsdl.KinshipKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      fromPersonId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['fromPersonId'],
      ),
      toPersonId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['toPersonId'],
      ),
      createdById: jsonSerialization['createdById'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['createdById'],
            ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = KinshipTable();

  static const db = KinshipRepository._();

  @override
  _is.UuidValue? id;

  _is.UuidValue treeId;

  _iq59nsdl.KinshipKind kind;

  _is.UuidValue fromPersonId;

  _is.UuidValue toPersonId;

  _is.UuidValue? createdById;

  DateTime createdAt;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Kinship]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Kinship copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? treeId,
    _iq59nsdl.KinshipKind? kind,
    _is.UuidValue? fromPersonId,
    _is.UuidValue? toPersonId,
    _is.UuidValue? createdById = const _is.$UndefinedUuidValue(),
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Kinship',
      if (id != null) 'id': id?.toJson(),
      'treeId': treeId.toJson(),
      'kind': kind.toJson(),
      'fromPersonId': fromPersonId.toJson(),
      'toPersonId': toPersonId.toJson(),
      if (createdById != null) 'createdById': createdById?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Kinship',
      if (id != null) 'id': id?.toJson(),
      'treeId': treeId.toJson(),
      'kind': kind.toJson(),
      'fromPersonId': fromPersonId.toJson(),
      'toPersonId': toPersonId.toJson(),
      if (createdById != null) 'createdById': createdById?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  static KinshipInclude include() {
    return KinshipInclude._();
  }

  static KinshipIncludeList includeList({
    _is.WhereExpressionBuilder<KinshipTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<KinshipTable>? orderBy,
    _is.OrderByListBuilder<KinshipTable>? orderByList,
    KinshipInclude? include,
  }) {
    return KinshipIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Kinship.t),
      orderByList: orderByList?.call(Kinship.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _KinshipImpl extends Kinship {
  _KinshipImpl({
    _is.UuidValue? id,
    required _is.UuidValue treeId,
    required _iq59nsdl.KinshipKind kind,
    required _is.UuidValue fromPersonId,
    required _is.UuidValue toPersonId,
    _is.UuidValue? createdById,
    DateTime? createdAt,
  }) : super._(
         id: id,
         treeId: treeId,
         kind: kind,
         fromPersonId: fromPersonId,
         toPersonId: toPersonId,
         createdById: createdById,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Kinship]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Kinship copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? treeId,
    _iq59nsdl.KinshipKind? kind,
    _is.UuidValue? fromPersonId,
    _is.UuidValue? toPersonId,
    _is.UuidValue? createdById = const _is.$UndefinedUuidValue(),
    DateTime? createdAt,
  }) {
    return Kinship(
      id: id is _is.UndefinedSentinel ? this.id : id,
      treeId: treeId ?? this.treeId,
      kind: kind ?? this.kind,
      fromPersonId: fromPersonId ?? this.fromPersonId,
      toPersonId: toPersonId ?? this.toPersonId,
      createdById: createdById is _is.UndefinedSentinel
          ? this.createdById
          : createdById,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class KinshipUpdateTable extends _is.UpdateTable<KinshipTable> {
  KinshipUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> treeId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.treeId,
        value,
      );

  _is.ColumnValue<_iq59nsdl.KinshipKind, _iq59nsdl.KinshipKind> kind(
    _iq59nsdl.KinshipKind value,
  ) => _is.ColumnValue(
    table.kind,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> fromPersonId(
    _is.UuidValue value,
  ) => _is.ColumnValue(
    table.fromPersonId,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> toPersonId(
    _is.UuidValue value,
  ) => _is.ColumnValue(
    table.toPersonId,
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
}

class KinshipTable extends _is.Table<_is.UuidValue?> {
  KinshipTable({super.tableRelation}) : super(tableName: 'kinships') {
    updateTable = KinshipUpdateTable(this);
    treeId = _is.ColumnUuid(
      'treeId',
      this,
    );
    kind = _is.ColumnEnum(
      'kind',
      this,
      _is.EnumSerialization.byName,
    );
    fromPersonId = _is.ColumnUuid(
      'fromPersonId',
      this,
    );
    toPersonId = _is.ColumnUuid(
      'toPersonId',
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
  }

  late final KinshipUpdateTable updateTable;

  late final _is.ColumnUuid treeId;

  late final _is.ColumnEnum<_iq59nsdl.KinshipKind> kind;

  late final _is.ColumnUuid fromPersonId;

  late final _is.ColumnUuid toPersonId;

  late final _is.ColumnUuid createdById;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    treeId,
    kind,
    fromPersonId,
    toPersonId,
    createdById,
    createdAt,
  ];
}

class KinshipInclude extends _is.IncludeObject {
  KinshipInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => Kinship.t;
}

class KinshipIncludeList extends _is.IncludeList {
  KinshipIncludeList._({
    _is.WhereExpressionBuilder<KinshipTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Kinship.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => Kinship.t;
}

class KinshipRepository {
  const KinshipRepository._();

  /// Returns a list of [Kinship]s matching the given query parameters.
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
  Future<List<Kinship>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<KinshipTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<KinshipTable>? orderBy,
    _is.OrderByListBuilder<KinshipTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Kinship>(
      where: where?.call(Kinship.t),
      orderBy: orderBy?.call(Kinship.t),
      orderByList: orderByList?.call(Kinship.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Kinship]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `Kinship.t`.
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
  _ida.Stream<List<Kinship>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<KinshipTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<KinshipTable>? orderBy,
    _is.OrderByListBuilder<KinshipTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Kinship>(
      where: where?.call(Kinship.t),
      orderBy: orderBy?.call(Kinship.t),
      orderByList: orderByList?.call(Kinship.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Kinship] matching the given query parameters.
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
  Future<Kinship?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<KinshipTable>? where,
    int? offset,
    _is.OrderByBuilder<KinshipTable>? orderBy,
    _is.OrderByListBuilder<KinshipTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Kinship>(
      where: where?.call(Kinship.t),
      orderBy: orderBy?.call(Kinship.t),
      orderByList: orderByList?.call(Kinship.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Kinship] by its [id] or null if no such row exists.
  Future<Kinship?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Kinship>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Kinship]s in the list and returns the inserted rows.
  ///
  /// The returned [Kinship]s will have their `id` fields set.
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
  Future<List<Kinship>> insert(
    _is.DatabaseSession session,
    List<Kinship> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Kinship>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Kinship] and returns the inserted row.
  ///
  /// The returned [Kinship] will have its `id` field set.
  Future<Kinship> insertRow(
    _is.DatabaseSession session,
    Kinship row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Kinship>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Kinship]s in the list and returns the resulting rows.
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
  /// The returned [Kinship]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Kinship>> upsert(
    _is.DatabaseSession session,
    List<Kinship> rows, {
    required _is.ColumnSelections<KinshipTable> conflictColumns,
    _is.ColumnSelections<KinshipTable>? updateColumns,
    _is.WhereExpressionBuilder<KinshipTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Kinship>(
      rows,
      conflictColumns: conflictColumns(Kinship.t),
      updateColumns: updateColumns?.call(Kinship.t),
      updateWhere: updateWhere?.call(Kinship.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Kinship] and returns the resulting row.
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
  /// The returned [Kinship] will have its `id` field set.
  Future<Kinship?> upsertRow(
    _is.DatabaseSession session,
    Kinship row, {
    required _is.ColumnSelections<KinshipTable> conflictColumns,
    _is.ColumnSelections<KinshipTable>? updateColumns,
    _is.WhereExpressionBuilder<KinshipTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Kinship>(
      row,
      conflictColumns: conflictColumns(Kinship.t),
      updateColumns: updateColumns?.call(Kinship.t),
      updateWhere: updateWhere?.call(Kinship.t),
      transaction: transaction,
    );
  }

  /// Updates all [Kinship]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Kinship>> update(
    _is.DatabaseSession session,
    List<Kinship> rows, {
    _is.ColumnSelections<KinshipTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Kinship>(
      rows,
      columns: columns?.call(Kinship.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Kinship]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Kinship> updateRow(
    _is.DatabaseSession session,
    Kinship row, {
    _is.ColumnSelections<KinshipTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Kinship>(
      row,
      columns: columns?.call(Kinship.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Kinship] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Kinship?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<KinshipUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Kinship>(
      id,
      columnValues: columnValues(Kinship.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Kinship]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Kinship>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<KinshipUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<KinshipTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<KinshipTable>? orderBy,
    _is.OrderByListBuilder<KinshipTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Kinship>(
      columnValues: columnValues(Kinship.t.updateTable),
      where: where(Kinship.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Kinship.t),
      orderByList: orderByList?.call(Kinship.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Kinship]s in the list and returns the deleted rows.
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
  Future<List<Kinship>> delete(
    _is.DatabaseSession session,
    List<Kinship> rows, {
    _is.OrderByBuilder<KinshipTable>? orderBy,
    _is.OrderByListBuilder<KinshipTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Kinship>(
      rows,
      orderBy: orderBy?.call(Kinship.t),
      orderByList: orderByList?.call(Kinship.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Kinship].
  Future<Kinship> deleteRow(
    _is.DatabaseSession session,
    Kinship row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Kinship>(
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
  Future<List<Kinship>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<KinshipTable> where,
    _is.OrderByBuilder<KinshipTable>? orderBy,
    _is.OrderByListBuilder<KinshipTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Kinship>(
      where: where(Kinship.t),
      orderBy: orderBy?.call(Kinship.t),
      orderByList: orderByList?.call(Kinship.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<KinshipTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Kinship>(
      where: where?.call(Kinship.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Kinship] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<KinshipTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Kinship>(
      where: where(Kinship.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
