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

/// Groups a root family and all its branches. Every family has exactly one tree;
/// "same tree" checks become an equality on treeId (no recursive parent walk).
abstract class Tree
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  Tree._({
    this.id,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Tree({
    _is.UuidValue? id,
    DateTime? createdAt,
  }) = _TreeImpl;

  factory Tree.fromJson(Map<String, dynamic> jsonSerialization) {
    return Tree(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = TreeTable();

  static const db = TreeRepository._();

  @override
  _is.UuidValue? id;

  DateTime createdAt;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Tree]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Tree copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Tree',
      if (id != null) 'id': id?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Tree',
      if (id != null) 'id': id?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  static TreeInclude include() {
    return TreeInclude._();
  }

  static TreeIncludeList includeList({
    _is.WhereExpressionBuilder<TreeTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<TreeTable>? orderBy,
    _is.OrderByListBuilder<TreeTable>? orderByList,
    TreeInclude? include,
  }) {
    return TreeIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Tree.t),
      orderByList: orderByList?.call(Tree.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _TreeImpl extends Tree {
  _TreeImpl({
    _is.UuidValue? id,
    DateTime? createdAt,
  }) : super._(
         id: id,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Tree]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Tree copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    DateTime? createdAt,
  }) {
    return Tree(
      id: id is _is.UndefinedSentinel ? this.id : id,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class TreeUpdateTable extends _is.UpdateTable<TreeTable> {
  TreeUpdateTable(super.table);

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class TreeTable extends _is.Table<_is.UuidValue?> {
  TreeTable({super.tableRelation}) : super(tableName: 'trees') {
    updateTable = TreeUpdateTable(this);
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
  }

  late final TreeUpdateTable updateTable;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    createdAt,
  ];
}

class TreeInclude extends _is.IncludeObject {
  TreeInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => Tree.t;
}

class TreeIncludeList extends _is.IncludeList {
  TreeIncludeList._({
    _is.WhereExpressionBuilder<TreeTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Tree.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => Tree.t;
}

class TreeRepository {
  const TreeRepository._();

  /// Returns a list of [Tree]s matching the given query parameters.
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
  Future<List<Tree>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<TreeTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<TreeTable>? orderBy,
    _is.OrderByListBuilder<TreeTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Tree>(
      where: where?.call(Tree.t),
      orderBy: orderBy?.call(Tree.t),
      orderByList: orderByList?.call(Tree.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Tree]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `Tree.t`.
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
  _ida.Stream<List<Tree>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<TreeTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<TreeTable>? orderBy,
    _is.OrderByListBuilder<TreeTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Tree>(
      where: where?.call(Tree.t),
      orderBy: orderBy?.call(Tree.t),
      orderByList: orderByList?.call(Tree.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Tree] matching the given query parameters.
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
  Future<Tree?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<TreeTable>? where,
    int? offset,
    _is.OrderByBuilder<TreeTable>? orderBy,
    _is.OrderByListBuilder<TreeTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Tree>(
      where: where?.call(Tree.t),
      orderBy: orderBy?.call(Tree.t),
      orderByList: orderByList?.call(Tree.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Tree] by its [id] or null if no such row exists.
  Future<Tree?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Tree>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Tree]s in the list and returns the inserted rows.
  ///
  /// The returned [Tree]s will have their `id` fields set.
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
  Future<List<Tree>> insert(
    _is.DatabaseSession session,
    List<Tree> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Tree>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Tree] and returns the inserted row.
  ///
  /// The returned [Tree] will have its `id` field set.
  Future<Tree> insertRow(
    _is.DatabaseSession session,
    Tree row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Tree>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Tree]s in the list and returns the resulting rows.
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
  /// The returned [Tree]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Tree>> upsert(
    _is.DatabaseSession session,
    List<Tree> rows, {
    required _is.ColumnSelections<TreeTable> conflictColumns,
    _is.ColumnSelections<TreeTable>? updateColumns,
    _is.WhereExpressionBuilder<TreeTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Tree>(
      rows,
      conflictColumns: conflictColumns(Tree.t),
      updateColumns: updateColumns?.call(Tree.t),
      updateWhere: updateWhere?.call(Tree.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Tree] and returns the resulting row.
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
  /// The returned [Tree] will have its `id` field set.
  Future<Tree?> upsertRow(
    _is.DatabaseSession session,
    Tree row, {
    required _is.ColumnSelections<TreeTable> conflictColumns,
    _is.ColumnSelections<TreeTable>? updateColumns,
    _is.WhereExpressionBuilder<TreeTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Tree>(
      row,
      conflictColumns: conflictColumns(Tree.t),
      updateColumns: updateColumns?.call(Tree.t),
      updateWhere: updateWhere?.call(Tree.t),
      transaction: transaction,
    );
  }

  /// Updates all [Tree]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Tree>> update(
    _is.DatabaseSession session,
    List<Tree> rows, {
    _is.ColumnSelections<TreeTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Tree>(
      rows,
      columns: columns?.call(Tree.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Tree]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Tree> updateRow(
    _is.DatabaseSession session,
    Tree row, {
    _is.ColumnSelections<TreeTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Tree>(
      row,
      columns: columns?.call(Tree.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Tree] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Tree?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<TreeUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Tree>(
      id,
      columnValues: columnValues(Tree.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Tree]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Tree>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<TreeUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<TreeTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<TreeTable>? orderBy,
    _is.OrderByListBuilder<TreeTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Tree>(
      columnValues: columnValues(Tree.t.updateTable),
      where: where(Tree.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Tree.t),
      orderByList: orderByList?.call(Tree.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Tree]s in the list and returns the deleted rows.
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
  Future<List<Tree>> delete(
    _is.DatabaseSession session,
    List<Tree> rows, {
    _is.OrderByBuilder<TreeTable>? orderBy,
    _is.OrderByListBuilder<TreeTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Tree>(
      rows,
      orderBy: orderBy?.call(Tree.t),
      orderByList: orderByList?.call(Tree.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Tree].
  Future<Tree> deleteRow(
    _is.DatabaseSession session,
    Tree row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Tree>(
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
  Future<List<Tree>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<TreeTable> where,
    _is.OrderByBuilder<TreeTable>? orderBy,
    _is.OrderByListBuilder<TreeTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Tree>(
      where: where(Tree.t),
      orderBy: orderBy?.call(Tree.t),
      orderByList: orderByList?.call(Tree.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<TreeTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Tree>(
      where: where?.call(Tree.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Tree] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<TreeTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Tree>(
      where: where(Tree.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
