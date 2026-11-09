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

/// Keys whose objects must be deleted from blob storage. Written in the SAME
/// transaction that drops/replaces the DB reference; drained by a recurring future
/// call. Needed because Serverpod CloudStorage has no list/prefix-delete (§4.3).
abstract class BlobDeletion
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  BlobDeletion._({
    this.id,
    required this.key,
    DateTime? createdAt,
    int? attempts,
  }) : createdAt = createdAt ?? DateTime.now(),
       attempts = attempts ?? 0;

  factory BlobDeletion({
    _is.UuidValue? id,
    required String key,
    DateTime? createdAt,
    int? attempts,
  }) = _BlobDeletionImpl;

  factory BlobDeletion.fromJson(Map<String, dynamic> jsonSerialization) {
    return BlobDeletion(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      key: jsonSerialization['key'] as String,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      attempts: jsonSerialization['attempts'] as int?,
    );
  }

  static final t = BlobDeletionTable();

  static const db = BlobDeletionRepository._();

  @override
  _is.UuidValue? id;

  String key;

  DateTime createdAt;

  int attempts;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [BlobDeletion]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BlobDeletion copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    String? key,
    DateTime? createdAt,
    int? attempts,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BlobDeletion',
      if (id != null) 'id': id?.toJson(),
      'key': key,
      'createdAt': createdAt.toJson(),
      'attempts': attempts,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static BlobDeletionInclude include() {
    return BlobDeletionInclude._();
  }

  static BlobDeletionIncludeList includeList({
    _is.WhereExpressionBuilder<BlobDeletionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BlobDeletionTable>? orderBy,
    _is.OrderByListBuilder<BlobDeletionTable>? orderByList,
    BlobDeletionInclude? include,
  }) {
    return BlobDeletionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BlobDeletion.t),
      orderByList: orderByList?.call(BlobDeletion.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _BlobDeletionImpl extends BlobDeletion {
  _BlobDeletionImpl({
    _is.UuidValue? id,
    required String key,
    DateTime? createdAt,
    int? attempts,
  }) : super._(
         id: id,
         key: key,
         createdAt: createdAt,
         attempts: attempts,
       );

  /// Returns a shallow copy of this [BlobDeletion]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BlobDeletion copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    String? key,
    DateTime? createdAt,
    int? attempts,
  }) {
    return BlobDeletion(
      id: id is _is.UndefinedSentinel ? this.id : id,
      key: key ?? this.key,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
    );
  }
}

class BlobDeletionUpdateTable extends _is.UpdateTable<BlobDeletionTable> {
  BlobDeletionUpdateTable(super.table);

  _is.ColumnValue<String, String> key(String value) => _is.ColumnValue(
    table.key,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<int, int> attempts(int value) => _is.ColumnValue(
    table.attempts,
    value,
  );
}

class BlobDeletionTable extends _is.Table<_is.UuidValue?> {
  BlobDeletionTable({super.tableRelation})
    : super(tableName: 'blob_deletions') {
    updateTable = BlobDeletionUpdateTable(this);
    key = _is.ColumnString(
      'key',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
    attempts = _is.ColumnInt(
      'attempts',
      this,
      hasDefault: true,
    );
  }

  late final BlobDeletionUpdateTable updateTable;

  late final _is.ColumnString key;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnInt attempts;

  @override
  List<_is.Column> get columns => [
    id,
    key,
    createdAt,
    attempts,
  ];
}

class BlobDeletionInclude extends _is.IncludeObject {
  BlobDeletionInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => BlobDeletion.t;
}

class BlobDeletionIncludeList extends _is.IncludeList {
  BlobDeletionIncludeList._({
    _is.WhereExpressionBuilder<BlobDeletionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(BlobDeletion.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => BlobDeletion.t;
}

class BlobDeletionRepository {
  const BlobDeletionRepository._();

  /// Returns a list of [BlobDeletion]s matching the given query parameters.
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
  Future<List<BlobDeletion>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BlobDeletionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BlobDeletionTable>? orderBy,
    _is.OrderByListBuilder<BlobDeletionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<BlobDeletion>(
      where: where?.call(BlobDeletion.t),
      orderBy: orderBy?.call(BlobDeletion.t),
      orderByList: orderByList?.call(BlobDeletion.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [BlobDeletion]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `BlobDeletion.t`.
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
  _ida.Stream<List<BlobDeletion>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BlobDeletionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BlobDeletionTable>? orderBy,
    _is.OrderByListBuilder<BlobDeletionTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<BlobDeletion>(
      where: where?.call(BlobDeletion.t),
      orderBy: orderBy?.call(BlobDeletion.t),
      orderByList: orderByList?.call(BlobDeletion.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [BlobDeletion] matching the given query parameters.
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
  Future<BlobDeletion?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BlobDeletionTable>? where,
    int? offset,
    _is.OrderByBuilder<BlobDeletionTable>? orderBy,
    _is.OrderByListBuilder<BlobDeletionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<BlobDeletion>(
      where: where?.call(BlobDeletion.t),
      orderBy: orderBy?.call(BlobDeletion.t),
      orderByList: orderByList?.call(BlobDeletion.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [BlobDeletion] by its [id] or null if no such row exists.
  Future<BlobDeletion?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<BlobDeletion>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [BlobDeletion]s in the list and returns the inserted rows.
  ///
  /// The returned [BlobDeletion]s will have their `id` fields set.
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
  Future<List<BlobDeletion>> insert(
    _is.DatabaseSession session,
    List<BlobDeletion> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<BlobDeletion>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [BlobDeletion] and returns the inserted row.
  ///
  /// The returned [BlobDeletion] will have its `id` field set.
  Future<BlobDeletion> insertRow(
    _is.DatabaseSession session,
    BlobDeletion row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<BlobDeletion>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [BlobDeletion]s in the list and returns the resulting rows.
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
  /// The returned [BlobDeletion]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BlobDeletion>> upsert(
    _is.DatabaseSession session,
    List<BlobDeletion> rows, {
    required _is.ColumnSelections<BlobDeletionTable> conflictColumns,
    _is.ColumnSelections<BlobDeletionTable>? updateColumns,
    _is.WhereExpressionBuilder<BlobDeletionTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<BlobDeletion>(
      rows,
      conflictColumns: conflictColumns(BlobDeletion.t),
      updateColumns: updateColumns?.call(BlobDeletion.t),
      updateWhere: updateWhere?.call(BlobDeletion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [BlobDeletion] and returns the resulting row.
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
  /// The returned [BlobDeletion] will have its `id` field set.
  Future<BlobDeletion?> upsertRow(
    _is.DatabaseSession session,
    BlobDeletion row, {
    required _is.ColumnSelections<BlobDeletionTable> conflictColumns,
    _is.ColumnSelections<BlobDeletionTable>? updateColumns,
    _is.WhereExpressionBuilder<BlobDeletionTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<BlobDeletion>(
      row,
      conflictColumns: conflictColumns(BlobDeletion.t),
      updateColumns: updateColumns?.call(BlobDeletion.t),
      updateWhere: updateWhere?.call(BlobDeletion.t),
      transaction: transaction,
    );
  }

  /// Updates all [BlobDeletion]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BlobDeletion>> update(
    _is.DatabaseSession session,
    List<BlobDeletion> rows, {
    _is.ColumnSelections<BlobDeletionTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<BlobDeletion>(
      rows,
      columns: columns?.call(BlobDeletion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [BlobDeletion]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<BlobDeletion> updateRow(
    _is.DatabaseSession session,
    BlobDeletion row, {
    _is.ColumnSelections<BlobDeletionTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<BlobDeletion>(
      row,
      columns: columns?.call(BlobDeletion.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BlobDeletion] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<BlobDeletion?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<BlobDeletionUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<BlobDeletion>(
      id,
      columnValues: columnValues(BlobDeletion.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [BlobDeletion]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BlobDeletion>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<BlobDeletionUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<BlobDeletionTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BlobDeletionTable>? orderBy,
    _is.OrderByListBuilder<BlobDeletionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<BlobDeletion>(
      columnValues: columnValues(BlobDeletion.t.updateTable),
      where: where(BlobDeletion.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BlobDeletion.t),
      orderByList: orderByList?.call(BlobDeletion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [BlobDeletion]s in the list and returns the deleted rows.
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
  Future<List<BlobDeletion>> delete(
    _is.DatabaseSession session,
    List<BlobDeletion> rows, {
    _is.OrderByBuilder<BlobDeletionTable>? orderBy,
    _is.OrderByListBuilder<BlobDeletionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<BlobDeletion>(
      rows,
      orderBy: orderBy?.call(BlobDeletion.t),
      orderByList: orderByList?.call(BlobDeletion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [BlobDeletion].
  Future<BlobDeletion> deleteRow(
    _is.DatabaseSession session,
    BlobDeletion row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<BlobDeletion>(
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
  Future<List<BlobDeletion>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BlobDeletionTable> where,
    _is.OrderByBuilder<BlobDeletionTable>? orderBy,
    _is.OrderByListBuilder<BlobDeletionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<BlobDeletion>(
      where: where(BlobDeletion.t),
      orderBy: orderBy?.call(BlobDeletion.t),
      orderByList: orderByList?.call(BlobDeletion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BlobDeletionTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<BlobDeletion>(
      where: where?.call(BlobDeletion.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [BlobDeletion] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BlobDeletionTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<BlobDeletion>(
      where: where(BlobDeletion.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
