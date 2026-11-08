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

/// A real-world place, shared by every family in the tree.
abstract class Place
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  Place._({
    this.id,
    required this.treeId,
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
    this.mapboxPlaceId,
    bool? isFavorite,
    this.lastUsedAt,
    DateTime? createdAt,
  }) : isFavorite = isFavorite ?? false,
       createdAt = createdAt ?? DateTime.now();

  factory Place({
    _is.UuidValue? id,
    required _is.UuidValue treeId,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    bool? isFavorite,
    DateTime? lastUsedAt,
    DateTime? createdAt,
  }) = _PlaceImpl;

  factory Place.fromJson(Map<String, dynamic> jsonSerialization) {
    return Place(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      treeId: _is.UuidValueJsonExtension.fromJson(jsonSerialization['treeId']),
      label: jsonSerialization['label'] as String,
      address: jsonSerialization['address'] as String,
      lat: (jsonSerialization['lat'] as num).toDouble(),
      lng: (jsonSerialization['lng'] as num).toDouble(),
      mapboxPlaceId: jsonSerialization['mapboxPlaceId'] as String?,
      isFavorite: jsonSerialization['isFavorite'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['isFavorite']),
      lastUsedAt: jsonSerialization['lastUsedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['lastUsedAt']),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = PlaceTable();

  static const db = PlaceRepository._();

  @override
  _is.UuidValue? id;

  _is.UuidValue treeId;

  String label;

  String address;

  double lat;

  double lng;

  String? mapboxPlaceId;

  bool isFavorite;

  DateTime? lastUsedAt;

  DateTime createdAt;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Place]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Place copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? treeId,
    String? label,
    String? address,
    double? lat,
    double? lng,
    String? mapboxPlaceId,
    bool? isFavorite,
    DateTime? lastUsedAt = const _is.$UndefinedDateTime(),
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Place',
      if (id != null) 'id': id?.toJson(),
      'treeId': treeId.toJson(),
      'label': label,
      'address': address,
      'lat': lat,
      'lng': lng,
      if (mapboxPlaceId != null) 'mapboxPlaceId': mapboxPlaceId,
      'isFavorite': isFavorite,
      if (lastUsedAt != null) 'lastUsedAt': lastUsedAt?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Place',
      if (id != null) 'id': id?.toJson(),
      'treeId': treeId.toJson(),
      'label': label,
      'address': address,
      'lat': lat,
      'lng': lng,
      if (mapboxPlaceId != null) 'mapboxPlaceId': mapboxPlaceId,
      'isFavorite': isFavorite,
      if (lastUsedAt != null) 'lastUsedAt': lastUsedAt?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  static PlaceInclude include() {
    return PlaceInclude._();
  }

  static PlaceIncludeList includeList({
    _is.WhereExpressionBuilder<PlaceTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PlaceTable>? orderBy,
    _is.OrderByListBuilder<PlaceTable>? orderByList,
    PlaceInclude? include,
  }) {
    return PlaceIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Place.t),
      orderByList: orderByList?.call(Place.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PlaceImpl extends Place {
  _PlaceImpl({
    _is.UuidValue? id,
    required _is.UuidValue treeId,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    bool? isFavorite,
    DateTime? lastUsedAt,
    DateTime? createdAt,
  }) : super._(
         id: id,
         treeId: treeId,
         label: label,
         address: address,
         lat: lat,
         lng: lng,
         mapboxPlaceId: mapboxPlaceId,
         isFavorite: isFavorite,
         lastUsedAt: lastUsedAt,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Place]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Place copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? treeId,
    String? label,
    String? address,
    double? lat,
    double? lng,
    Object? mapboxPlaceId = _Undefined,
    bool? isFavorite,
    DateTime? lastUsedAt = const _is.$UndefinedDateTime(),
    DateTime? createdAt,
  }) {
    return Place(
      id: id is _is.UndefinedSentinel ? this.id : id,
      treeId: treeId ?? this.treeId,
      label: label ?? this.label,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      mapboxPlaceId: mapboxPlaceId is String?
          ? mapboxPlaceId
          : this.mapboxPlaceId,
      isFavorite: isFavorite ?? this.isFavorite,
      lastUsedAt: lastUsedAt is _is.UndefinedSentinel
          ? this.lastUsedAt
          : lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class PlaceUpdateTable extends _is.UpdateTable<PlaceTable> {
  PlaceUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> treeId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.treeId,
        value,
      );

  _is.ColumnValue<String, String> label(String value) => _is.ColumnValue(
    table.label,
    value,
  );

  _is.ColumnValue<String, String> address(String value) => _is.ColumnValue(
    table.address,
    value,
  );

  _is.ColumnValue<double, double> lat(double value) => _is.ColumnValue(
    table.lat,
    value,
  );

  _is.ColumnValue<double, double> lng(double value) => _is.ColumnValue(
    table.lng,
    value,
  );

  _is.ColumnValue<String, String> mapboxPlaceId(String? value) =>
      _is.ColumnValue(
        table.mapboxPlaceId,
        value,
      );

  _is.ColumnValue<bool, bool> isFavorite(bool value) => _is.ColumnValue(
    table.isFavorite,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> lastUsedAt(DateTime? value) =>
      _is.ColumnValue(
        table.lastUsedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class PlaceTable extends _is.Table<_is.UuidValue?> {
  PlaceTable({super.tableRelation}) : super(tableName: 'places') {
    updateTable = PlaceUpdateTable(this);
    treeId = _is.ColumnUuid(
      'treeId',
      this,
    );
    label = _is.ColumnString(
      'label',
      this,
    );
    address = _is.ColumnString(
      'address',
      this,
    );
    lat = _is.ColumnDouble(
      'lat',
      this,
    );
    lng = _is.ColumnDouble(
      'lng',
      this,
    );
    mapboxPlaceId = _is.ColumnString(
      'mapboxPlaceId',
      this,
    );
    isFavorite = _is.ColumnBool(
      'isFavorite',
      this,
      hasDefault: true,
    );
    lastUsedAt = _is.ColumnDateTime(
      'lastUsedAt',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
  }

  late final PlaceUpdateTable updateTable;

  late final _is.ColumnUuid treeId;

  late final _is.ColumnString label;

  late final _is.ColumnString address;

  late final _is.ColumnDouble lat;

  late final _is.ColumnDouble lng;

  late final _is.ColumnString mapboxPlaceId;

  late final _is.ColumnBool isFavorite;

  late final _is.ColumnDateTime lastUsedAt;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    treeId,
    label,
    address,
    lat,
    lng,
    mapboxPlaceId,
    isFavorite,
    lastUsedAt,
    createdAt,
  ];
}

class PlaceInclude extends _is.IncludeObject {
  PlaceInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => Place.t;
}

class PlaceIncludeList extends _is.IncludeList {
  PlaceIncludeList._({
    _is.WhereExpressionBuilder<PlaceTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Place.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => Place.t;
}

class PlaceRepository {
  const PlaceRepository._();

  /// Returns a list of [Place]s matching the given query parameters.
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
  Future<List<Place>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PlaceTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PlaceTable>? orderBy,
    _is.OrderByListBuilder<PlaceTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Place>(
      where: where?.call(Place.t),
      orderBy: orderBy?.call(Place.t),
      orderByList: orderByList?.call(Place.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Place]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `Place.t`.
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
  _ida.Stream<List<Place>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PlaceTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PlaceTable>? orderBy,
    _is.OrderByListBuilder<PlaceTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Place>(
      where: where?.call(Place.t),
      orderBy: orderBy?.call(Place.t),
      orderByList: orderByList?.call(Place.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Place] matching the given query parameters.
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
  Future<Place?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PlaceTable>? where,
    int? offset,
    _is.OrderByBuilder<PlaceTable>? orderBy,
    _is.OrderByListBuilder<PlaceTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Place>(
      where: where?.call(Place.t),
      orderBy: orderBy?.call(Place.t),
      orderByList: orderByList?.call(Place.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Place] by its [id] or null if no such row exists.
  Future<Place?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Place>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Place]s in the list and returns the inserted rows.
  ///
  /// The returned [Place]s will have their `id` fields set.
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
  Future<List<Place>> insert(
    _is.DatabaseSession session,
    List<Place> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Place>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Place] and returns the inserted row.
  ///
  /// The returned [Place] will have its `id` field set.
  Future<Place> insertRow(
    _is.DatabaseSession session,
    Place row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Place>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Place]s in the list and returns the resulting rows.
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
  /// The returned [Place]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Place>> upsert(
    _is.DatabaseSession session,
    List<Place> rows, {
    required _is.ColumnSelections<PlaceTable> conflictColumns,
    _is.ColumnSelections<PlaceTable>? updateColumns,
    _is.WhereExpressionBuilder<PlaceTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Place>(
      rows,
      conflictColumns: conflictColumns(Place.t),
      updateColumns: updateColumns?.call(Place.t),
      updateWhere: updateWhere?.call(Place.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Place] and returns the resulting row.
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
  /// The returned [Place] will have its `id` field set.
  Future<Place?> upsertRow(
    _is.DatabaseSession session,
    Place row, {
    required _is.ColumnSelections<PlaceTable> conflictColumns,
    _is.ColumnSelections<PlaceTable>? updateColumns,
    _is.WhereExpressionBuilder<PlaceTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Place>(
      row,
      conflictColumns: conflictColumns(Place.t),
      updateColumns: updateColumns?.call(Place.t),
      updateWhere: updateWhere?.call(Place.t),
      transaction: transaction,
    );
  }

  /// Updates all [Place]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Place>> update(
    _is.DatabaseSession session,
    List<Place> rows, {
    _is.ColumnSelections<PlaceTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Place>(
      rows,
      columns: columns?.call(Place.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Place]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Place> updateRow(
    _is.DatabaseSession session,
    Place row, {
    _is.ColumnSelections<PlaceTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Place>(
      row,
      columns: columns?.call(Place.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Place] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Place?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<PlaceUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Place>(
      id,
      columnValues: columnValues(Place.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Place]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Place>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<PlaceUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<PlaceTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PlaceTable>? orderBy,
    _is.OrderByListBuilder<PlaceTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Place>(
      columnValues: columnValues(Place.t.updateTable),
      where: where(Place.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Place.t),
      orderByList: orderByList?.call(Place.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Place]s in the list and returns the deleted rows.
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
  Future<List<Place>> delete(
    _is.DatabaseSession session,
    List<Place> rows, {
    _is.OrderByBuilder<PlaceTable>? orderBy,
    _is.OrderByListBuilder<PlaceTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Place>(
      rows,
      orderBy: orderBy?.call(Place.t),
      orderByList: orderByList?.call(Place.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Place].
  Future<Place> deleteRow(
    _is.DatabaseSession session,
    Place row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Place>(
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
  Future<List<Place>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<PlaceTable> where,
    _is.OrderByBuilder<PlaceTable>? orderBy,
    _is.OrderByListBuilder<PlaceTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Place>(
      where: where(Place.t),
      orderBy: orderBy?.call(Place.t),
      orderByList: orderByList?.call(Place.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PlaceTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Place>(
      where: where?.call(Place.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Place] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<PlaceTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Place>(
      where: where(Place.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
