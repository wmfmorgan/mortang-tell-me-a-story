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

/// Junction story ↔ person (Serverpod tables always have an id; the old composite PK
/// becomes a unique index). https://docs.serverpod.dev/concepts/data-and-the-database/database/relations/many-to-many
abstract class StoryPerson
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  StoryPerson._({
    this.id,
    required this.storyId,
    required this.personId,
    required this.treeId,
  });

  factory StoryPerson({
    _is.UuidValue? id,
    required _is.UuidValue storyId,
    required _is.UuidValue personId,
    required _is.UuidValue treeId,
  }) = _StoryPersonImpl;

  factory StoryPerson.fromJson(Map<String, dynamic> jsonSerialization) {
    return StoryPerson(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      storyId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['storyId'],
      ),
      personId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['personId'],
      ),
      treeId: _is.UuidValueJsonExtension.fromJson(jsonSerialization['treeId']),
    );
  }

  static final t = StoryPersonTable();

  static const db = StoryPersonRepository._();

  @override
  _is.UuidValue? id;

  _is.UuidValue storyId;

  _is.UuidValue personId;

  /// Copy of the story's treeId; story_people_story_tree_fk and story_people_person_tree_fk make tags same-tree.
  _is.UuidValue treeId;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [StoryPerson]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StoryPerson copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? storyId,
    _is.UuidValue? personId,
    _is.UuidValue? treeId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StoryPerson',
      if (id != null) 'id': id?.toJson(),
      'storyId': storyId.toJson(),
      'personId': personId.toJson(),
      'treeId': treeId.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StoryPerson',
      if (id != null) 'id': id?.toJson(),
      'storyId': storyId.toJson(),
      'personId': personId.toJson(),
      'treeId': treeId.toJson(),
    };
  }

  static StoryPersonInclude include() {
    return StoryPersonInclude._();
  }

  static StoryPersonIncludeList includeList({
    _is.WhereExpressionBuilder<StoryPersonTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StoryPersonTable>? orderBy,
    _is.OrderByListBuilder<StoryPersonTable>? orderByList,
    StoryPersonInclude? include,
  }) {
    return StoryPersonIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(StoryPerson.t),
      orderByList: orderByList?.call(StoryPerson.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _StoryPersonImpl extends StoryPerson {
  _StoryPersonImpl({
    _is.UuidValue? id,
    required _is.UuidValue storyId,
    required _is.UuidValue personId,
    required _is.UuidValue treeId,
  }) : super._(
         id: id,
         storyId: storyId,
         personId: personId,
         treeId: treeId,
       );

  /// Returns a shallow copy of this [StoryPerson]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StoryPerson copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? storyId,
    _is.UuidValue? personId,
    _is.UuidValue? treeId,
  }) {
    return StoryPerson(
      id: id is _is.UndefinedSentinel ? this.id : id,
      storyId: storyId ?? this.storyId,
      personId: personId ?? this.personId,
      treeId: treeId ?? this.treeId,
    );
  }
}

class StoryPersonUpdateTable extends _is.UpdateTable<StoryPersonTable> {
  StoryPersonUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> storyId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.storyId,
        value,
      );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> personId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.personId,
        value,
      );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> treeId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.treeId,
        value,
      );
}

class StoryPersonTable extends _is.Table<_is.UuidValue?> {
  StoryPersonTable({super.tableRelation}) : super(tableName: 'story_people') {
    updateTable = StoryPersonUpdateTable(this);
    storyId = _is.ColumnUuid(
      'storyId',
      this,
    );
    personId = _is.ColumnUuid(
      'personId',
      this,
    );
    treeId = _is.ColumnUuid(
      'treeId',
      this,
    );
  }

  late final StoryPersonUpdateTable updateTable;

  late final _is.ColumnUuid storyId;

  late final _is.ColumnUuid personId;

  /// Copy of the story's treeId; story_people_story_tree_fk and story_people_person_tree_fk make tags same-tree.
  late final _is.ColumnUuid treeId;

  @override
  List<_is.Column> get columns => [
    id,
    storyId,
    personId,
    treeId,
  ];
}

class StoryPersonInclude extends _is.IncludeObject {
  StoryPersonInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => StoryPerson.t;
}

class StoryPersonIncludeList extends _is.IncludeList {
  StoryPersonIncludeList._({
    _is.WhereExpressionBuilder<StoryPersonTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(StoryPerson.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => StoryPerson.t;
}

class StoryPersonRepository {
  const StoryPersonRepository._();

  /// Returns a list of [StoryPerson]s matching the given query parameters.
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
  Future<List<StoryPerson>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StoryPersonTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StoryPersonTable>? orderBy,
    _is.OrderByListBuilder<StoryPersonTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<StoryPerson>(
      where: where?.call(StoryPerson.t),
      orderBy: orderBy?.call(StoryPerson.t),
      orderByList: orderByList?.call(StoryPerson.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [StoryPerson]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `StoryPerson.t`.
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
  _ida.Stream<List<StoryPerson>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StoryPersonTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StoryPersonTable>? orderBy,
    _is.OrderByListBuilder<StoryPersonTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<StoryPerson>(
      where: where?.call(StoryPerson.t),
      orderBy: orderBy?.call(StoryPerson.t),
      orderByList: orderByList?.call(StoryPerson.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [StoryPerson] matching the given query parameters.
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
  Future<StoryPerson?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StoryPersonTable>? where,
    int? offset,
    _is.OrderByBuilder<StoryPersonTable>? orderBy,
    _is.OrderByListBuilder<StoryPersonTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<StoryPerson>(
      where: where?.call(StoryPerson.t),
      orderBy: orderBy?.call(StoryPerson.t),
      orderByList: orderByList?.call(StoryPerson.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [StoryPerson] by its [id] or null if no such row exists.
  Future<StoryPerson?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<StoryPerson>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [StoryPerson]s in the list and returns the inserted rows.
  ///
  /// The returned [StoryPerson]s will have their `id` fields set.
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
  Future<List<StoryPerson>> insert(
    _is.DatabaseSession session,
    List<StoryPerson> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<StoryPerson>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [StoryPerson] and returns the inserted row.
  ///
  /// The returned [StoryPerson] will have its `id` field set.
  Future<StoryPerson> insertRow(
    _is.DatabaseSession session,
    StoryPerson row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<StoryPerson>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [StoryPerson]s in the list and returns the resulting rows.
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
  /// The returned [StoryPerson]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StoryPerson>> upsert(
    _is.DatabaseSession session,
    List<StoryPerson> rows, {
    required _is.ColumnSelections<StoryPersonTable> conflictColumns,
    _is.ColumnSelections<StoryPersonTable>? updateColumns,
    _is.WhereExpressionBuilder<StoryPersonTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<StoryPerson>(
      rows,
      conflictColumns: conflictColumns(StoryPerson.t),
      updateColumns: updateColumns?.call(StoryPerson.t),
      updateWhere: updateWhere?.call(StoryPerson.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [StoryPerson] and returns the resulting row.
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
  /// The returned [StoryPerson] will have its `id` field set.
  Future<StoryPerson?> upsertRow(
    _is.DatabaseSession session,
    StoryPerson row, {
    required _is.ColumnSelections<StoryPersonTable> conflictColumns,
    _is.ColumnSelections<StoryPersonTable>? updateColumns,
    _is.WhereExpressionBuilder<StoryPersonTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<StoryPerson>(
      row,
      conflictColumns: conflictColumns(StoryPerson.t),
      updateColumns: updateColumns?.call(StoryPerson.t),
      updateWhere: updateWhere?.call(StoryPerson.t),
      transaction: transaction,
    );
  }

  /// Updates all [StoryPerson]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StoryPerson>> update(
    _is.DatabaseSession session,
    List<StoryPerson> rows, {
    _is.ColumnSelections<StoryPersonTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<StoryPerson>(
      rows,
      columns: columns?.call(StoryPerson.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [StoryPerson]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<StoryPerson> updateRow(
    _is.DatabaseSession session,
    StoryPerson row, {
    _is.ColumnSelections<StoryPersonTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<StoryPerson>(
      row,
      columns: columns?.call(StoryPerson.t),
      transaction: transaction,
    );
  }

  /// Updates a single [StoryPerson] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<StoryPerson?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<StoryPersonUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<StoryPerson>(
      id,
      columnValues: columnValues(StoryPerson.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [StoryPerson]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StoryPerson>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<StoryPersonUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<StoryPersonTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StoryPersonTable>? orderBy,
    _is.OrderByListBuilder<StoryPersonTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<StoryPerson>(
      columnValues: columnValues(StoryPerson.t.updateTable),
      where: where(StoryPerson.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(StoryPerson.t),
      orderByList: orderByList?.call(StoryPerson.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [StoryPerson]s in the list and returns the deleted rows.
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
  Future<List<StoryPerson>> delete(
    _is.DatabaseSession session,
    List<StoryPerson> rows, {
    _is.OrderByBuilder<StoryPersonTable>? orderBy,
    _is.OrderByListBuilder<StoryPersonTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<StoryPerson>(
      rows,
      orderBy: orderBy?.call(StoryPerson.t),
      orderByList: orderByList?.call(StoryPerson.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [StoryPerson].
  Future<StoryPerson> deleteRow(
    _is.DatabaseSession session,
    StoryPerson row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<StoryPerson>(
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
  Future<List<StoryPerson>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<StoryPersonTable> where,
    _is.OrderByBuilder<StoryPersonTable>? orderBy,
    _is.OrderByListBuilder<StoryPersonTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<StoryPerson>(
      where: where(StoryPerson.t),
      orderBy: orderBy?.call(StoryPerson.t),
      orderByList: orderByList?.call(StoryPerson.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StoryPersonTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<StoryPerson>(
      where: where?.call(StoryPerson.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [StoryPerson] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<StoryPersonTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<StoryPerson>(
      where: where(StoryPerson.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
