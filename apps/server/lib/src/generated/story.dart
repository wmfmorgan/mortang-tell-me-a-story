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
import 'date_precision.dart' as _ilvyd2nu;
import 'story_status.dart' as _ixc1exsr;

abstract class Story
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  Story._({
    this.id,
    required this.familyId,
    this.authorId,
    this.title,
    this.body,
    _ixc1exsr.StoryStatus? status,
    this.dateStart,
    this.dateEnd,
    this.datePrecision,
    this.placeId,
    this.publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : status = status ?? _ixc1exsr.StoryStatus.draft,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Story({
    _is.UuidValue? id,
    required _is.UuidValue familyId,
    _is.UuidValue? authorId,
    String? title,
    String? body,
    _ixc1exsr.StoryStatus? status,
    DateTime? dateStart,
    DateTime? dateEnd,
    _ilvyd2nu.DatePrecision? datePrecision,
    _is.UuidValue? placeId,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _StoryImpl;

  factory Story.fromJson(Map<String, dynamic> jsonSerialization) {
    return Story(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      familyId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      authorId: jsonSerialization['authorId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['authorId']),
      title: jsonSerialization['title'] as String?,
      body: jsonSerialization['body'] as String?,
      status: jsonSerialization['status'] == null
          ? null
          : _ixc1exsr.StoryStatus.fromJson(
              (jsonSerialization['status'] as String),
            ),
      dateStart: jsonSerialization['dateStart'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['dateStart']),
      dateEnd: jsonSerialization['dateEnd'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['dateEnd']),
      datePrecision: jsonSerialization['datePrecision'] == null
          ? null
          : _ilvyd2nu.DatePrecision.fromJson(
              (jsonSerialization['datePrecision'] as int),
            ),
      placeId: jsonSerialization['placeId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['placeId']),
      publishedAt: jsonSerialization['publishedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['publishedAt'],
            ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
    );
  }

  static final t = StoryTable();

  static const db = StoryRepository._();

  @override
  _is.UuidValue? id;

  _is.UuidValue familyId;

  /// Null only after the author's account is deleted.
  _is.UuidValue? authorId;

  String? title;

  String? body;

  _ixc1exsr.StoryStatus status;

  /// UTC midnight. All three null (undated draft) or a valid span (CHECK stories_date_shape).
  DateTime? dateStart;

  DateTime? dateEnd;

  _ilvyd2nu.DatePrecision? datePrecision;

  _is.UuidValue? placeId;

  DateTime? publishedAt;

  DateTime createdAt;

  DateTime updatedAt;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Story]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Story copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? familyId,
    _is.UuidValue? authorId = const _is.$UndefinedUuidValue(),
    String? title,
    String? body,
    _ixc1exsr.StoryStatus? status,
    DateTime? dateStart = const _is.$UndefinedDateTime(),
    DateTime? dateEnd = const _is.$UndefinedDateTime(),
    _ilvyd2nu.DatePrecision? datePrecision,
    _is.UuidValue? placeId = const _is.$UndefinedUuidValue(),
    DateTime? publishedAt = const _is.$UndefinedDateTime(),
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Story',
      if (id != null) 'id': id?.toJson(),
      'familyId': familyId.toJson(),
      if (authorId != null) 'authorId': authorId?.toJson(),
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      'status': status.toJson(),
      if (dateStart != null) 'dateStart': dateStart?.toJson(),
      if (dateEnd != null) 'dateEnd': dateEnd?.toJson(),
      if (datePrecision != null) 'datePrecision': datePrecision?.toJson(),
      if (placeId != null) 'placeId': placeId?.toJson(),
      if (publishedAt != null) 'publishedAt': publishedAt?.toJson(),
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Story',
      if (id != null) 'id': id?.toJson(),
      'familyId': familyId.toJson(),
      if (authorId != null) 'authorId': authorId?.toJson(),
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      'status': status.toJson(),
      if (dateStart != null) 'dateStart': dateStart?.toJson(),
      if (dateEnd != null) 'dateEnd': dateEnd?.toJson(),
      if (datePrecision != null) 'datePrecision': datePrecision?.toJson(),
      if (placeId != null) 'placeId': placeId?.toJson(),
      if (publishedAt != null) 'publishedAt': publishedAt?.toJson(),
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  static StoryInclude include() {
    return StoryInclude._();
  }

  static StoryIncludeList includeList({
    _is.WhereExpressionBuilder<StoryTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StoryTable>? orderBy,
    _is.OrderByListBuilder<StoryTable>? orderByList,
    StoryInclude? include,
  }) {
    return StoryIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Story.t),
      orderByList: orderByList?.call(Story.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StoryImpl extends Story {
  _StoryImpl({
    _is.UuidValue? id,
    required _is.UuidValue familyId,
    _is.UuidValue? authorId,
    String? title,
    String? body,
    _ixc1exsr.StoryStatus? status,
    DateTime? dateStart,
    DateTime? dateEnd,
    _ilvyd2nu.DatePrecision? datePrecision,
    _is.UuidValue? placeId,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super._(
         id: id,
         familyId: familyId,
         authorId: authorId,
         title: title,
         body: body,
         status: status,
         dateStart: dateStart,
         dateEnd: dateEnd,
         datePrecision: datePrecision,
         placeId: placeId,
         publishedAt: publishedAt,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [Story]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Story copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? familyId,
    _is.UuidValue? authorId = const _is.$UndefinedUuidValue(),
    Object? title = _Undefined,
    Object? body = _Undefined,
    _ixc1exsr.StoryStatus? status,
    DateTime? dateStart = const _is.$UndefinedDateTime(),
    DateTime? dateEnd = const _is.$UndefinedDateTime(),
    Object? datePrecision = _Undefined,
    _is.UuidValue? placeId = const _is.$UndefinedUuidValue(),
    DateTime? publishedAt = const _is.$UndefinedDateTime(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Story(
      id: id is _is.UndefinedSentinel ? this.id : id,
      familyId: familyId ?? this.familyId,
      authorId: authorId is _is.UndefinedSentinel ? this.authorId : authorId,
      title: title is String? ? title : this.title,
      body: body is String? ? body : this.body,
      status: status ?? this.status,
      dateStart: dateStart is _is.UndefinedSentinel
          ? this.dateStart
          : dateStart,
      dateEnd: dateEnd is _is.UndefinedSentinel ? this.dateEnd : dateEnd,
      datePrecision: datePrecision is _ilvyd2nu.DatePrecision?
          ? datePrecision
          : this.datePrecision,
      placeId: placeId is _is.UndefinedSentinel ? this.placeId : placeId,
      publishedAt: publishedAt is _is.UndefinedSentinel
          ? this.publishedAt
          : publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StoryUpdateTable extends _is.UpdateTable<StoryTable> {
  StoryUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> familyId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.familyId,
        value,
      );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> authorId(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.authorId,
    value,
  );

  _is.ColumnValue<String, String> title(String? value) => _is.ColumnValue(
    table.title,
    value,
  );

  _is.ColumnValue<String, String> body(String? value) => _is.ColumnValue(
    table.body,
    value,
  );

  _is.ColumnValue<_ixc1exsr.StoryStatus, _ixc1exsr.StoryStatus> status(
    _ixc1exsr.StoryStatus value,
  ) => _is.ColumnValue(
    table.status,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> dateStart(DateTime? value) =>
      _is.ColumnValue(
        table.dateStart,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> dateEnd(DateTime? value) =>
      _is.ColumnValue(
        table.dateEnd,
        value,
      );

  _is.ColumnValue<_ilvyd2nu.DatePrecision, _ilvyd2nu.DatePrecision>
  datePrecision(_ilvyd2nu.DatePrecision? value) => _is.ColumnValue(
    table.datePrecision,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> placeId(_is.UuidValue? value) =>
      _is.ColumnValue(
        table.placeId,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> publishedAt(DateTime? value) =>
      _is.ColumnValue(
        table.publishedAt,
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

class StoryTable extends _is.Table<_is.UuidValue?> {
  StoryTable({super.tableRelation}) : super(tableName: 'stories') {
    updateTable = StoryUpdateTable(this);
    familyId = _is.ColumnUuid(
      'familyId',
      this,
    );
    authorId = _is.ColumnUuid(
      'authorId',
      this,
    );
    title = _is.ColumnString(
      'title',
      this,
    );
    body = _is.ColumnString(
      'body',
      this,
    );
    status = _is.ColumnEnum(
      'status',
      this,
      _is.EnumSerialization.byName,
      hasDefault: true,
    );
    dateStart = _is.ColumnDateTime(
      'dateStart',
      this,
    );
    dateEnd = _is.ColumnDateTime(
      'dateEnd',
      this,
    );
    datePrecision = _is.ColumnEnum(
      'datePrecision',
      this,
      _is.EnumSerialization.byIndex,
    );
    placeId = _is.ColumnUuid(
      'placeId',
      this,
    );
    publishedAt = _is.ColumnDateTime(
      'publishedAt',
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

  late final StoryUpdateTable updateTable;

  late final _is.ColumnUuid familyId;

  /// Null only after the author's account is deleted.
  late final _is.ColumnUuid authorId;

  late final _is.ColumnString title;

  late final _is.ColumnString body;

  late final _is.ColumnEnum<_ixc1exsr.StoryStatus> status;

  /// UTC midnight. All three null (undated draft) or a valid span (CHECK stories_date_shape).
  late final _is.ColumnDateTime dateStart;

  late final _is.ColumnDateTime dateEnd;

  late final _is.ColumnEnum<_ilvyd2nu.DatePrecision> datePrecision;

  late final _is.ColumnUuid placeId;

  late final _is.ColumnDateTime publishedAt;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    familyId,
    authorId,
    title,
    body,
    status,
    dateStart,
    dateEnd,
    datePrecision,
    placeId,
    publishedAt,
    createdAt,
    updatedAt,
  ];
}

class StoryInclude extends _is.IncludeObject {
  StoryInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => Story.t;
}

class StoryIncludeList extends _is.IncludeList {
  StoryIncludeList._({
    _is.WhereExpressionBuilder<StoryTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Story.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => Story.t;
}

class StoryRepository {
  const StoryRepository._();

  /// Returns a list of [Story]s matching the given query parameters.
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
  Future<List<Story>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StoryTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StoryTable>? orderBy,
    _is.OrderByListBuilder<StoryTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Story>(
      where: where?.call(Story.t),
      orderBy: orderBy?.call(Story.t),
      orderByList: orderByList?.call(Story.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Story]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `Story.t`.
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
  _ida.Stream<List<Story>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StoryTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StoryTable>? orderBy,
    _is.OrderByListBuilder<StoryTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Story>(
      where: where?.call(Story.t),
      orderBy: orderBy?.call(Story.t),
      orderByList: orderByList?.call(Story.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Story] matching the given query parameters.
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
  Future<Story?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StoryTable>? where,
    int? offset,
    _is.OrderByBuilder<StoryTable>? orderBy,
    _is.OrderByListBuilder<StoryTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Story>(
      where: where?.call(Story.t),
      orderBy: orderBy?.call(Story.t),
      orderByList: orderByList?.call(Story.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Story] by its [id] or null if no such row exists.
  Future<Story?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Story>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Story]s in the list and returns the inserted rows.
  ///
  /// The returned [Story]s will have their `id` fields set.
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
  Future<List<Story>> insert(
    _is.DatabaseSession session,
    List<Story> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Story>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Story] and returns the inserted row.
  ///
  /// The returned [Story] will have its `id` field set.
  Future<Story> insertRow(
    _is.DatabaseSession session,
    Story row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Story>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Story]s in the list and returns the resulting rows.
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
  /// The returned [Story]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Story>> upsert(
    _is.DatabaseSession session,
    List<Story> rows, {
    required _is.ColumnSelections<StoryTable> conflictColumns,
    _is.ColumnSelections<StoryTable>? updateColumns,
    _is.WhereExpressionBuilder<StoryTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Story>(
      rows,
      conflictColumns: conflictColumns(Story.t),
      updateColumns: updateColumns?.call(Story.t),
      updateWhere: updateWhere?.call(Story.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Story] and returns the resulting row.
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
  /// The returned [Story] will have its `id` field set.
  Future<Story?> upsertRow(
    _is.DatabaseSession session,
    Story row, {
    required _is.ColumnSelections<StoryTable> conflictColumns,
    _is.ColumnSelections<StoryTable>? updateColumns,
    _is.WhereExpressionBuilder<StoryTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Story>(
      row,
      conflictColumns: conflictColumns(Story.t),
      updateColumns: updateColumns?.call(Story.t),
      updateWhere: updateWhere?.call(Story.t),
      transaction: transaction,
    );
  }

  /// Updates all [Story]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Story>> update(
    _is.DatabaseSession session,
    List<Story> rows, {
    _is.ColumnSelections<StoryTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Story>(
      rows,
      columns: columns?.call(Story.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Story]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Story> updateRow(
    _is.DatabaseSession session,
    Story row, {
    _is.ColumnSelections<StoryTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Story>(
      row,
      columns: columns?.call(Story.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Story] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Story?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<StoryUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Story>(
      id,
      columnValues: columnValues(Story.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Story]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Story>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<StoryUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<StoryTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StoryTable>? orderBy,
    _is.OrderByListBuilder<StoryTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Story>(
      columnValues: columnValues(Story.t.updateTable),
      where: where(Story.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Story.t),
      orderByList: orderByList?.call(Story.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Story]s in the list and returns the deleted rows.
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
  Future<List<Story>> delete(
    _is.DatabaseSession session,
    List<Story> rows, {
    _is.OrderByBuilder<StoryTable>? orderBy,
    _is.OrderByListBuilder<StoryTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Story>(
      rows,
      orderBy: orderBy?.call(Story.t),
      orderByList: orderByList?.call(Story.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Story].
  Future<Story> deleteRow(
    _is.DatabaseSession session,
    Story row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Story>(
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
  Future<List<Story>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<StoryTable> where,
    _is.OrderByBuilder<StoryTable>? orderBy,
    _is.OrderByListBuilder<StoryTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Story>(
      where: where(Story.t),
      orderBy: orderBy?.call(Story.t),
      orderByList: orderByList?.call(Story.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StoryTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Story>(
      where: where?.call(Story.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Story] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<StoryTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Story>(
      where: where(Story.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
