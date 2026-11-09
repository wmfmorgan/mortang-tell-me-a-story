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

abstract class Photo
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  Photo._({
    this.id,
    required this.storyId,
    this.uploaderId,
    required this.originalKey,
    this.editedKey,
    int? editVersion,
    int? sortOrder,
    DateTime? createdAt,
  }) : editVersion = editVersion ?? 0,
       sortOrder = sortOrder ?? 0,
       createdAt = createdAt ?? DateTime.now();

  factory Photo({
    _is.UuidValue? id,
    required _is.UuidValue storyId,
    _is.UuidValue? uploaderId,
    required String originalKey,
    String? editedKey,
    int? editVersion,
    int? sortOrder,
    DateTime? createdAt,
  }) = _PhotoImpl;

  factory Photo.fromJson(Map<String, dynamic> jsonSerialization) {
    return Photo(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      storyId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['storyId'],
      ),
      uploaderId: jsonSerialization['uploaderId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['uploaderId'],
            ),
      originalKey: jsonSerialization['originalKey'] as String,
      editedKey: jsonSerialization['editedKey'] as String?,
      editVersion: jsonSerialization['editVersion'] as int?,
      sortOrder: jsonSerialization['sortOrder'] as int?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = PhotoTable();

  static const db = PhotoRepository._();

  @override
  _is.UuidValue? id;

  _is.UuidValue storyId;

  /// Uploader may delete own photo (story_reader_page.dart:1017).
  _is.UuidValue? uploaderId;

  /// families/{familyId}/stories/{storyId}/photos/{photoId}/original.{jpg|png|webp}
  String originalKey;

  /// families/{familyId}/stories/{storyId}/photos/{photoId}/edited-{editVersion}.jpg
  String? editedKey;

  /// Optimistic-concurrency counter; +1 on every save AND reset of an edit.
  int editVersion;

  int sortOrder;

  DateTime createdAt;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Photo]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Photo copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? storyId,
    _is.UuidValue? uploaderId = const _is.$UndefinedUuidValue(),
    String? originalKey,
    String? editedKey,
    int? editVersion,
    int? sortOrder,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Photo',
      if (id != null) 'id': id?.toJson(),
      'storyId': storyId.toJson(),
      if (uploaderId != null) 'uploaderId': uploaderId?.toJson(),
      'originalKey': originalKey,
      if (editedKey != null) 'editedKey': editedKey,
      'editVersion': editVersion,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Photo',
      if (id != null) 'id': id?.toJson(),
      'storyId': storyId.toJson(),
      if (uploaderId != null) 'uploaderId': uploaderId?.toJson(),
      'originalKey': originalKey,
      if (editedKey != null) 'editedKey': editedKey,
      'editVersion': editVersion,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toJson(),
    };
  }

  static PhotoInclude include() {
    return PhotoInclude._();
  }

  static PhotoIncludeList includeList({
    _is.WhereExpressionBuilder<PhotoTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PhotoTable>? orderBy,
    _is.OrderByListBuilder<PhotoTable>? orderByList,
    PhotoInclude? include,
  }) {
    return PhotoIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Photo.t),
      orderByList: orderByList?.call(Photo.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PhotoImpl extends Photo {
  _PhotoImpl({
    _is.UuidValue? id,
    required _is.UuidValue storyId,
    _is.UuidValue? uploaderId,
    required String originalKey,
    String? editedKey,
    int? editVersion,
    int? sortOrder,
    DateTime? createdAt,
  }) : super._(
         id: id,
         storyId: storyId,
         uploaderId: uploaderId,
         originalKey: originalKey,
         editedKey: editedKey,
         editVersion: editVersion,
         sortOrder: sortOrder,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Photo]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Photo copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? storyId,
    _is.UuidValue? uploaderId = const _is.$UndefinedUuidValue(),
    String? originalKey,
    Object? editedKey = _Undefined,
    int? editVersion,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return Photo(
      id: id is _is.UndefinedSentinel ? this.id : id,
      storyId: storyId ?? this.storyId,
      uploaderId: uploaderId is _is.UndefinedSentinel
          ? this.uploaderId
          : uploaderId,
      originalKey: originalKey ?? this.originalKey,
      editedKey: editedKey is String? ? editedKey : this.editedKey,
      editVersion: editVersion ?? this.editVersion,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class PhotoUpdateTable extends _is.UpdateTable<PhotoTable> {
  PhotoUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> storyId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.storyId,
        value,
      );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> uploaderId(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.uploaderId,
    value,
  );

  _is.ColumnValue<String, String> originalKey(String value) => _is.ColumnValue(
    table.originalKey,
    value,
  );

  _is.ColumnValue<String, String> editedKey(String? value) => _is.ColumnValue(
    table.editedKey,
    value,
  );

  _is.ColumnValue<int, int> editVersion(int value) => _is.ColumnValue(
    table.editVersion,
    value,
  );

  _is.ColumnValue<int, int> sortOrder(int value) => _is.ColumnValue(
    table.sortOrder,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class PhotoTable extends _is.Table<_is.UuidValue?> {
  PhotoTable({super.tableRelation}) : super(tableName: 'photos') {
    updateTable = PhotoUpdateTable(this);
    storyId = _is.ColumnUuid(
      'storyId',
      this,
    );
    uploaderId = _is.ColumnUuid(
      'uploaderId',
      this,
    );
    originalKey = _is.ColumnString(
      'originalKey',
      this,
    );
    editedKey = _is.ColumnString(
      'editedKey',
      this,
    );
    editVersion = _is.ColumnInt(
      'editVersion',
      this,
      hasDefault: true,
    );
    sortOrder = _is.ColumnInt(
      'sortOrder',
      this,
      hasDefault: true,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
  }

  late final PhotoUpdateTable updateTable;

  late final _is.ColumnUuid storyId;

  /// Uploader may delete own photo (story_reader_page.dart:1017).
  late final _is.ColumnUuid uploaderId;

  /// families/{familyId}/stories/{storyId}/photos/{photoId}/original.{jpg|png|webp}
  late final _is.ColumnString originalKey;

  /// families/{familyId}/stories/{storyId}/photos/{photoId}/edited-{editVersion}.jpg
  late final _is.ColumnString editedKey;

  /// Optimistic-concurrency counter; +1 on every save AND reset of an edit.
  late final _is.ColumnInt editVersion;

  late final _is.ColumnInt sortOrder;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    storyId,
    uploaderId,
    originalKey,
    editedKey,
    editVersion,
    sortOrder,
    createdAt,
  ];
}

class PhotoInclude extends _is.IncludeObject {
  PhotoInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => Photo.t;
}

class PhotoIncludeList extends _is.IncludeList {
  PhotoIncludeList._({
    _is.WhereExpressionBuilder<PhotoTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Photo.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => Photo.t;
}

class PhotoRepository {
  const PhotoRepository._();

  /// Returns a list of [Photo]s matching the given query parameters.
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
  Future<List<Photo>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PhotoTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PhotoTable>? orderBy,
    _is.OrderByListBuilder<PhotoTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Photo>(
      where: where?.call(Photo.t),
      orderBy: orderBy?.call(Photo.t),
      orderByList: orderByList?.call(Photo.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Photo]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `Photo.t`.
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
  _ida.Stream<List<Photo>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PhotoTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PhotoTable>? orderBy,
    _is.OrderByListBuilder<PhotoTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Photo>(
      where: where?.call(Photo.t),
      orderBy: orderBy?.call(Photo.t),
      orderByList: orderByList?.call(Photo.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Photo] matching the given query parameters.
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
  Future<Photo?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PhotoTable>? where,
    int? offset,
    _is.OrderByBuilder<PhotoTable>? orderBy,
    _is.OrderByListBuilder<PhotoTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Photo>(
      where: where?.call(Photo.t),
      orderBy: orderBy?.call(Photo.t),
      orderByList: orderByList?.call(Photo.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Photo] by its [id] or null if no such row exists.
  Future<Photo?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Photo>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Photo]s in the list and returns the inserted rows.
  ///
  /// The returned [Photo]s will have their `id` fields set.
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
  Future<List<Photo>> insert(
    _is.DatabaseSession session,
    List<Photo> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Photo>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Photo] and returns the inserted row.
  ///
  /// The returned [Photo] will have its `id` field set.
  Future<Photo> insertRow(
    _is.DatabaseSession session,
    Photo row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Photo>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Photo]s in the list and returns the resulting rows.
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
  /// The returned [Photo]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Photo>> upsert(
    _is.DatabaseSession session,
    List<Photo> rows, {
    required _is.ColumnSelections<PhotoTable> conflictColumns,
    _is.ColumnSelections<PhotoTable>? updateColumns,
    _is.WhereExpressionBuilder<PhotoTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Photo>(
      rows,
      conflictColumns: conflictColumns(Photo.t),
      updateColumns: updateColumns?.call(Photo.t),
      updateWhere: updateWhere?.call(Photo.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Photo] and returns the resulting row.
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
  /// The returned [Photo] will have its `id` field set.
  Future<Photo?> upsertRow(
    _is.DatabaseSession session,
    Photo row, {
    required _is.ColumnSelections<PhotoTable> conflictColumns,
    _is.ColumnSelections<PhotoTable>? updateColumns,
    _is.WhereExpressionBuilder<PhotoTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Photo>(
      row,
      conflictColumns: conflictColumns(Photo.t),
      updateColumns: updateColumns?.call(Photo.t),
      updateWhere: updateWhere?.call(Photo.t),
      transaction: transaction,
    );
  }

  /// Updates all [Photo]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Photo>> update(
    _is.DatabaseSession session,
    List<Photo> rows, {
    _is.ColumnSelections<PhotoTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Photo>(
      rows,
      columns: columns?.call(Photo.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Photo]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Photo> updateRow(
    _is.DatabaseSession session,
    Photo row, {
    _is.ColumnSelections<PhotoTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Photo>(
      row,
      columns: columns?.call(Photo.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Photo] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Photo?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<PhotoUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Photo>(
      id,
      columnValues: columnValues(Photo.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Photo]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Photo>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<PhotoUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<PhotoTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PhotoTable>? orderBy,
    _is.OrderByListBuilder<PhotoTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Photo>(
      columnValues: columnValues(Photo.t.updateTable),
      where: where(Photo.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Photo.t),
      orderByList: orderByList?.call(Photo.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Photo]s in the list and returns the deleted rows.
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
  Future<List<Photo>> delete(
    _is.DatabaseSession session,
    List<Photo> rows, {
    _is.OrderByBuilder<PhotoTable>? orderBy,
    _is.OrderByListBuilder<PhotoTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Photo>(
      rows,
      orderBy: orderBy?.call(Photo.t),
      orderByList: orderByList?.call(Photo.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Photo].
  Future<Photo> deleteRow(
    _is.DatabaseSession session,
    Photo row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Photo>(
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
  Future<List<Photo>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<PhotoTable> where,
    _is.OrderByBuilder<PhotoTable>? orderBy,
    _is.OrderByListBuilder<PhotoTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Photo>(
      where: where(Photo.t),
      orderBy: orderBy?.call(Photo.t),
      orderByList: orderByList?.call(Photo.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PhotoTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Photo>(
      where: where?.call(Photo.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Photo] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<PhotoTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Photo>(
      where: where(Photo.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
