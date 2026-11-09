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
import 'note_kind.dart' as _ixhn57mr;

/// Comments and perspectives in one table.
abstract class StoryNote
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  StoryNote._({
    this.id,
    required this.storyId,
    this.authorId,
    required this.kind,
    required this.body,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory StoryNote({
    _is.UuidValue? id,
    required _is.UuidValue storyId,
    _is.UuidValue? authorId,
    required _ixhn57mr.NoteKind kind,
    required String body,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _StoryNoteImpl;

  factory StoryNote.fromJson(Map<String, dynamic> jsonSerialization) {
    return StoryNote(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      storyId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['storyId'],
      ),
      authorId: jsonSerialization['authorId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['authorId']),
      kind: _ixhn57mr.NoteKind.fromJson((jsonSerialization['kind'] as String)),
      body: jsonSerialization['body'] as String,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
    );
  }

  static final t = StoryNoteTable();

  static const db = StoryNoteRepository._();

  @override
  _is.UuidValue? id;

  _is.UuidValue storyId;

  _is.UuidValue? authorId;

  _ixhn57mr.NoteKind kind;

  String body;

  DateTime createdAt;

  DateTime updatedAt;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [StoryNote]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StoryNote copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? storyId,
    _is.UuidValue? authorId = const _is.$UndefinedUuidValue(),
    _ixhn57mr.NoteKind? kind,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StoryNote',
      if (id != null) 'id': id?.toJson(),
      'storyId': storyId.toJson(),
      if (authorId != null) 'authorId': authorId?.toJson(),
      'kind': kind.toJson(),
      'body': body,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StoryNote',
      if (id != null) 'id': id?.toJson(),
      'storyId': storyId.toJson(),
      if (authorId != null) 'authorId': authorId?.toJson(),
      'kind': kind.toJson(),
      'body': body,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  static StoryNoteInclude include() {
    return StoryNoteInclude._();
  }

  static StoryNoteIncludeList includeList({
    _is.WhereExpressionBuilder<StoryNoteTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StoryNoteTable>? orderBy,
    _is.OrderByListBuilder<StoryNoteTable>? orderByList,
    StoryNoteInclude? include,
  }) {
    return StoryNoteIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(StoryNote.t),
      orderByList: orderByList?.call(StoryNote.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _StoryNoteImpl extends StoryNote {
  _StoryNoteImpl({
    _is.UuidValue? id,
    required _is.UuidValue storyId,
    _is.UuidValue? authorId,
    required _ixhn57mr.NoteKind kind,
    required String body,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super._(
         id: id,
         storyId: storyId,
         authorId: authorId,
         kind: kind,
         body: body,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [StoryNote]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StoryNote copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? storyId,
    _is.UuidValue? authorId = const _is.$UndefinedUuidValue(),
    _ixhn57mr.NoteKind? kind,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoryNote(
      id: id is _is.UndefinedSentinel ? this.id : id,
      storyId: storyId ?? this.storyId,
      authorId: authorId is _is.UndefinedSentinel ? this.authorId : authorId,
      kind: kind ?? this.kind,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StoryNoteUpdateTable extends _is.UpdateTable<StoryNoteTable> {
  StoryNoteUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> storyId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.storyId,
        value,
      );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> authorId(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.authorId,
    value,
  );

  _is.ColumnValue<_ixhn57mr.NoteKind, _ixhn57mr.NoteKind> kind(
    _ixhn57mr.NoteKind value,
  ) => _is.ColumnValue(
    table.kind,
    value,
  );

  _is.ColumnValue<String, String> body(String value) => _is.ColumnValue(
    table.body,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );
}

class StoryNoteTable extends _is.Table<_is.UuidValue?> {
  StoryNoteTable({super.tableRelation}) : super(tableName: 'story_notes') {
    updateTable = StoryNoteUpdateTable(this);
    storyId = _is.ColumnUuid(
      'storyId',
      this,
    );
    authorId = _is.ColumnUuid(
      'authorId',
      this,
    );
    kind = _is.ColumnEnum(
      'kind',
      this,
      _is.EnumSerialization.byName,
    );
    body = _is.ColumnString(
      'body',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
      hasDefault: true,
    );
  }

  late final StoryNoteUpdateTable updateTable;

  late final _is.ColumnUuid storyId;

  late final _is.ColumnUuid authorId;

  late final _is.ColumnEnum<_ixhn57mr.NoteKind> kind;

  late final _is.ColumnString body;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    storyId,
    authorId,
    kind,
    body,
    createdAt,
    updatedAt,
  ];
}

class StoryNoteInclude extends _is.IncludeObject {
  StoryNoteInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => StoryNote.t;
}

class StoryNoteIncludeList extends _is.IncludeList {
  StoryNoteIncludeList._({
    _is.WhereExpressionBuilder<StoryNoteTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(StoryNote.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => StoryNote.t;
}

class StoryNoteRepository {
  const StoryNoteRepository._();

  /// Returns a list of [StoryNote]s matching the given query parameters.
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
  Future<List<StoryNote>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StoryNoteTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StoryNoteTable>? orderBy,
    _is.OrderByListBuilder<StoryNoteTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<StoryNote>(
      where: where?.call(StoryNote.t),
      orderBy: orderBy?.call(StoryNote.t),
      orderByList: orderByList?.call(StoryNote.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [StoryNote]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `StoryNote.t`.
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
  _ida.Stream<List<StoryNote>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StoryNoteTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StoryNoteTable>? orderBy,
    _is.OrderByListBuilder<StoryNoteTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<StoryNote>(
      where: where?.call(StoryNote.t),
      orderBy: orderBy?.call(StoryNote.t),
      orderByList: orderByList?.call(StoryNote.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [StoryNote] matching the given query parameters.
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
  Future<StoryNote?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StoryNoteTable>? where,
    int? offset,
    _is.OrderByBuilder<StoryNoteTable>? orderBy,
    _is.OrderByListBuilder<StoryNoteTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<StoryNote>(
      where: where?.call(StoryNote.t),
      orderBy: orderBy?.call(StoryNote.t),
      orderByList: orderByList?.call(StoryNote.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [StoryNote] by its [id] or null if no such row exists.
  Future<StoryNote?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<StoryNote>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [StoryNote]s in the list and returns the inserted rows.
  ///
  /// The returned [StoryNote]s will have their `id` fields set.
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
  Future<List<StoryNote>> insert(
    _is.DatabaseSession session,
    List<StoryNote> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<StoryNote>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [StoryNote] and returns the inserted row.
  ///
  /// The returned [StoryNote] will have its `id` field set.
  Future<StoryNote> insertRow(
    _is.DatabaseSession session,
    StoryNote row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<StoryNote>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [StoryNote]s in the list and returns the resulting rows.
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
  /// The returned [StoryNote]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StoryNote>> upsert(
    _is.DatabaseSession session,
    List<StoryNote> rows, {
    required _is.ColumnSelections<StoryNoteTable> conflictColumns,
    _is.ColumnSelections<StoryNoteTable>? updateColumns,
    _is.WhereExpressionBuilder<StoryNoteTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<StoryNote>(
      rows,
      conflictColumns: conflictColumns(StoryNote.t),
      updateColumns: updateColumns?.call(StoryNote.t),
      updateWhere: updateWhere?.call(StoryNote.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [StoryNote] and returns the resulting row.
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
  /// The returned [StoryNote] will have its `id` field set.
  Future<StoryNote?> upsertRow(
    _is.DatabaseSession session,
    StoryNote row, {
    required _is.ColumnSelections<StoryNoteTable> conflictColumns,
    _is.ColumnSelections<StoryNoteTable>? updateColumns,
    _is.WhereExpressionBuilder<StoryNoteTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<StoryNote>(
      row,
      conflictColumns: conflictColumns(StoryNote.t),
      updateColumns: updateColumns?.call(StoryNote.t),
      updateWhere: updateWhere?.call(StoryNote.t),
      transaction: transaction,
    );
  }

  /// Updates all [StoryNote]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StoryNote>> update(
    _is.DatabaseSession session,
    List<StoryNote> rows, {
    _is.ColumnSelections<StoryNoteTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<StoryNote>(
      rows,
      columns: columns?.call(StoryNote.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [StoryNote]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<StoryNote> updateRow(
    _is.DatabaseSession session,
    StoryNote row, {
    _is.ColumnSelections<StoryNoteTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<StoryNote>(
      row,
      columns: columns?.call(StoryNote.t),
      transaction: transaction,
    );
  }

  /// Updates a single [StoryNote] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<StoryNote?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<StoryNoteUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<StoryNote>(
      id,
      columnValues: columnValues(StoryNote.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [StoryNote]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StoryNote>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<StoryNoteUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<StoryNoteTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StoryNoteTable>? orderBy,
    _is.OrderByListBuilder<StoryNoteTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<StoryNote>(
      columnValues: columnValues(StoryNote.t.updateTable),
      where: where(StoryNote.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(StoryNote.t),
      orderByList: orderByList?.call(StoryNote.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [StoryNote]s in the list and returns the deleted rows.
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
  Future<List<StoryNote>> delete(
    _is.DatabaseSession session,
    List<StoryNote> rows, {
    _is.OrderByBuilder<StoryNoteTable>? orderBy,
    _is.OrderByListBuilder<StoryNoteTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<StoryNote>(
      rows,
      orderBy: orderBy?.call(StoryNote.t),
      orderByList: orderByList?.call(StoryNote.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [StoryNote].
  Future<StoryNote> deleteRow(
    _is.DatabaseSession session,
    StoryNote row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<StoryNote>(
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
  Future<List<StoryNote>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<StoryNoteTable> where,
    _is.OrderByBuilder<StoryNoteTable>? orderBy,
    _is.OrderByListBuilder<StoryNoteTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<StoryNote>(
      where: where(StoryNote.t),
      orderBy: orderBy?.call(StoryNote.t),
      orderByList: orderByList?.call(StoryNote.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StoryNoteTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<StoryNote>(
      where: where?.call(StoryNote.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [StoryNote] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<StoryNoteTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<StoryNote>(
      where: where(StoryNote.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
