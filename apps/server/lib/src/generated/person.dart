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

/// A human in one tree, shared by every family (timeline) in the tree.
abstract class Person
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  Person._({
    this.id,
    required this.treeId,
    required this.homeFamilyId,
    this.userId,
    required this.name,
    this.email,
    this.about,
    this.avatarKey,
    this.birthDate,
    this.birthPrecision,
    this.deathDate,
    this.deathPrecision,
    bool? passedAway,
    this.createdById,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : passedAway = passedAway ?? false,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Person({
    _is.UuidValue? id,
    required _is.UuidValue treeId,
    required _is.UuidValue homeFamilyId,
    _is.UuidValue? userId,
    required String name,
    String? email,
    String? about,
    String? avatarKey,
    DateTime? birthDate,
    _ilvyd2nu.DatePrecision? birthPrecision,
    DateTime? deathDate,
    _ilvyd2nu.DatePrecision? deathPrecision,
    bool? passedAway,
    _is.UuidValue? createdById,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _PersonImpl;

  factory Person.fromJson(Map<String, dynamic> jsonSerialization) {
    return Person(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      treeId: _is.UuidValueJsonExtension.fromJson(jsonSerialization['treeId']),
      homeFamilyId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['homeFamilyId'],
      ),
      userId: jsonSerialization['userId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      name: jsonSerialization['name'] as String,
      email: jsonSerialization['email'] as String?,
      about: jsonSerialization['about'] as String?,
      avatarKey: jsonSerialization['avatarKey'] as String?,
      birthDate: jsonSerialization['birthDate'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['birthDate']),
      birthPrecision: jsonSerialization['birthPrecision'] == null
          ? null
          : _ilvyd2nu.DatePrecision.fromJson(
              (jsonSerialization['birthPrecision'] as int),
            ),
      deathDate: jsonSerialization['deathDate'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['deathDate']),
      deathPrecision: jsonSerialization['deathPrecision'] == null
          ? null
          : _ilvyd2nu.DatePrecision.fromJson(
              (jsonSerialization['deathPrecision'] as int),
            ),
      passedAway: jsonSerialization['passedAway'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['passedAway']),
      createdById: jsonSerialization['createdById'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['createdById'],
            ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
    );
  }

  static final t = PersonTable();

  static const db = PersonRepository._();

  @override
  _is.UuidValue? id;

  /// Owning tree. Deleted with the tree, or explicitly.
  _is.UuidValue treeId;

  /// Family the person was added in; its stewards hold steward-only rights.
  /// Same tree enforced by people_home_family_tree_fk. The purge job reassigns it before deleting the family (§4.3).
  _is.UuidValue homeFamilyId;

  /// Linked account. Unique per tree; NULLs are distinct.
  _is.UuidValue? userId;

  /// For linked people this mirrors AppUser.displayName (app-layer sync, §3.2).
  String name;

  /// Lower-cased, trimmed, non-empty or null (CHECK).
  String? email;

  /// ≤ 500 chars (CHECK).
  String? about;

  /// Blob key, see §4. trees/{treeId}/people/{personId}/avatar/{blobId}.jpg
  String? avatarKey;

  /// UTC midnight aligned to precision (CHECK people_birth_shape). While linked, AppUser birth wins on read.
  DateTime? birthDate;

  _ilvyd2nu.DatePrecision? birthPrecision;

  /// UTC midnight aligned to precision (CHECK people_death_shape). Requires passedAway.
  DateTime? deathDate;

  _ilvyd2nu.DatePrecision? deathPrecision;

  bool passedAway;

  _is.UuidValue? createdById;

  DateTime createdAt;

  DateTime updatedAt;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Person]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Person copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? treeId,
    _is.UuidValue? homeFamilyId,
    _is.UuidValue? userId = const _is.$UndefinedUuidValue(),
    String? name,
    String? email,
    String? about,
    String? avatarKey,
    DateTime? birthDate = const _is.$UndefinedDateTime(),
    _ilvyd2nu.DatePrecision? birthPrecision,
    DateTime? deathDate = const _is.$UndefinedDateTime(),
    _ilvyd2nu.DatePrecision? deathPrecision,
    bool? passedAway,
    _is.UuidValue? createdById = const _is.$UndefinedUuidValue(),
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Person',
      if (id != null) 'id': id?.toJson(),
      'treeId': treeId.toJson(),
      'homeFamilyId': homeFamilyId.toJson(),
      if (userId != null) 'userId': userId?.toJson(),
      'name': name,
      if (email != null) 'email': email,
      if (about != null) 'about': about,
      if (avatarKey != null) 'avatarKey': avatarKey,
      if (birthDate != null) 'birthDate': birthDate?.toJson(),
      if (birthPrecision != null) 'birthPrecision': birthPrecision?.toJson(),
      if (deathDate != null) 'deathDate': deathDate?.toJson(),
      if (deathPrecision != null) 'deathPrecision': deathPrecision?.toJson(),
      'passedAway': passedAway,
      if (createdById != null) 'createdById': createdById?.toJson(),
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Person',
      if (id != null) 'id': id?.toJson(),
      'treeId': treeId.toJson(),
      'homeFamilyId': homeFamilyId.toJson(),
      if (userId != null) 'userId': userId?.toJson(),
      'name': name,
      if (email != null) 'email': email,
      if (about != null) 'about': about,
      if (avatarKey != null) 'avatarKey': avatarKey,
      if (birthDate != null) 'birthDate': birthDate?.toJson(),
      if (birthPrecision != null) 'birthPrecision': birthPrecision?.toJson(),
      if (deathDate != null) 'deathDate': deathDate?.toJson(),
      if (deathPrecision != null) 'deathPrecision': deathPrecision?.toJson(),
      'passedAway': passedAway,
      if (createdById != null) 'createdById': createdById?.toJson(),
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  static PersonInclude include() {
    return PersonInclude._();
  }

  static PersonIncludeList includeList({
    _is.WhereExpressionBuilder<PersonTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PersonTable>? orderBy,
    _is.OrderByListBuilder<PersonTable>? orderByList,
    PersonInclude? include,
  }) {
    return PersonIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Person.t),
      orderByList: orderByList?.call(Person.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PersonImpl extends Person {
  _PersonImpl({
    _is.UuidValue? id,
    required _is.UuidValue treeId,
    required _is.UuidValue homeFamilyId,
    _is.UuidValue? userId,
    required String name,
    String? email,
    String? about,
    String? avatarKey,
    DateTime? birthDate,
    _ilvyd2nu.DatePrecision? birthPrecision,
    DateTime? deathDate,
    _ilvyd2nu.DatePrecision? deathPrecision,
    bool? passedAway,
    _is.UuidValue? createdById,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super._(
         id: id,
         treeId: treeId,
         homeFamilyId: homeFamilyId,
         userId: userId,
         name: name,
         email: email,
         about: about,
         avatarKey: avatarKey,
         birthDate: birthDate,
         birthPrecision: birthPrecision,
         deathDate: deathDate,
         deathPrecision: deathPrecision,
         passedAway: passedAway,
         createdById: createdById,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [Person]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Person copyWith({
    _is.UuidValue? id = const _is.$UndefinedUuidValue(),
    _is.UuidValue? treeId,
    _is.UuidValue? homeFamilyId,
    _is.UuidValue? userId = const _is.$UndefinedUuidValue(),
    String? name,
    Object? email = _Undefined,
    Object? about = _Undefined,
    Object? avatarKey = _Undefined,
    DateTime? birthDate = const _is.$UndefinedDateTime(),
    Object? birthPrecision = _Undefined,
    DateTime? deathDate = const _is.$UndefinedDateTime(),
    Object? deathPrecision = _Undefined,
    bool? passedAway,
    _is.UuidValue? createdById = const _is.$UndefinedUuidValue(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Person(
      id: id is _is.UndefinedSentinel ? this.id : id,
      treeId: treeId ?? this.treeId,
      homeFamilyId: homeFamilyId ?? this.homeFamilyId,
      userId: userId is _is.UndefinedSentinel ? this.userId : userId,
      name: name ?? this.name,
      email: email is String? ? email : this.email,
      about: about is String? ? about : this.about,
      avatarKey: avatarKey is String? ? avatarKey : this.avatarKey,
      birthDate: birthDate is _is.UndefinedSentinel
          ? this.birthDate
          : birthDate,
      birthPrecision: birthPrecision is _ilvyd2nu.DatePrecision?
          ? birthPrecision
          : this.birthPrecision,
      deathDate: deathDate is _is.UndefinedSentinel
          ? this.deathDate
          : deathDate,
      deathPrecision: deathPrecision is _ilvyd2nu.DatePrecision?
          ? deathPrecision
          : this.deathPrecision,
      passedAway: passedAway ?? this.passedAway,
      createdById: createdById is _is.UndefinedSentinel
          ? this.createdById
          : createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PersonUpdateTable extends _is.UpdateTable<PersonTable> {
  PersonUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> treeId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.treeId,
        value,
      );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> homeFamilyId(
    _is.UuidValue value,
  ) => _is.ColumnValue(
    table.homeFamilyId,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> userId(_is.UuidValue? value) =>
      _is.ColumnValue(
        table.userId,
        value,
      );

  _is.ColumnValue<String, String> name(String value) => _is.ColumnValue(
    table.name,
    value,
  );

  _is.ColumnValue<String, String> email(String? value) => _is.ColumnValue(
    table.email,
    value,
  );

  _is.ColumnValue<String, String> about(String? value) => _is.ColumnValue(
    table.about,
    value,
  );

  _is.ColumnValue<String, String> avatarKey(String? value) => _is.ColumnValue(
    table.avatarKey,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> birthDate(DateTime? value) =>
      _is.ColumnValue(
        table.birthDate,
        value,
      );

  _is.ColumnValue<_ilvyd2nu.DatePrecision, _ilvyd2nu.DatePrecision>
  birthPrecision(_ilvyd2nu.DatePrecision? value) => _is.ColumnValue(
    table.birthPrecision,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> deathDate(DateTime? value) =>
      _is.ColumnValue(
        table.deathDate,
        value,
      );

  _is.ColumnValue<_ilvyd2nu.DatePrecision, _ilvyd2nu.DatePrecision>
  deathPrecision(_ilvyd2nu.DatePrecision? value) => _is.ColumnValue(
    table.deathPrecision,
    value,
  );

  _is.ColumnValue<bool, bool> passedAway(bool value) => _is.ColumnValue(
    table.passedAway,
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

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );
}

class PersonTable extends _is.Table<_is.UuidValue?> {
  PersonTable({super.tableRelation}) : super(tableName: 'people') {
    updateTable = PersonUpdateTable(this);
    treeId = _is.ColumnUuid(
      'treeId',
      this,
    );
    homeFamilyId = _is.ColumnUuid(
      'homeFamilyId',
      this,
    );
    userId = _is.ColumnUuid(
      'userId',
      this,
    );
    name = _is.ColumnString(
      'name',
      this,
    );
    email = _is.ColumnString(
      'email',
      this,
    );
    about = _is.ColumnString(
      'about',
      this,
    );
    avatarKey = _is.ColumnString(
      'avatarKey',
      this,
    );
    birthDate = _is.ColumnDateTime(
      'birthDate',
      this,
    );
    birthPrecision = _is.ColumnEnum(
      'birthPrecision',
      this,
      _is.EnumSerialization.byIndex,
    );
    deathDate = _is.ColumnDateTime(
      'deathDate',
      this,
    );
    deathPrecision = _is.ColumnEnum(
      'deathPrecision',
      this,
      _is.EnumSerialization.byIndex,
    );
    passedAway = _is.ColumnBool(
      'passedAway',
      this,
      hasDefault: true,
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
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
      hasDefault: true,
    );
  }

  late final PersonUpdateTable updateTable;

  /// Owning tree. Deleted with the tree, or explicitly.
  late final _is.ColumnUuid treeId;

  /// Family the person was added in; its stewards hold steward-only rights.
  /// Same tree enforced by people_home_family_tree_fk. The purge job reassigns it before deleting the family (§4.3).
  late final _is.ColumnUuid homeFamilyId;

  /// Linked account. Unique per tree; NULLs are distinct.
  late final _is.ColumnUuid userId;

  /// For linked people this mirrors AppUser.displayName (app-layer sync, §3.2).
  late final _is.ColumnString name;

  /// Lower-cased, trimmed, non-empty or null (CHECK).
  late final _is.ColumnString email;

  /// ≤ 500 chars (CHECK).
  late final _is.ColumnString about;

  /// Blob key, see §4. trees/{treeId}/people/{personId}/avatar/{blobId}.jpg
  late final _is.ColumnString avatarKey;

  /// UTC midnight aligned to precision (CHECK people_birth_shape). While linked, AppUser birth wins on read.
  late final _is.ColumnDateTime birthDate;

  late final _is.ColumnEnum<_ilvyd2nu.DatePrecision> birthPrecision;

  /// UTC midnight aligned to precision (CHECK people_death_shape). Requires passedAway.
  late final _is.ColumnDateTime deathDate;

  late final _is.ColumnEnum<_ilvyd2nu.DatePrecision> deathPrecision;

  late final _is.ColumnBool passedAway;

  late final _is.ColumnUuid createdById;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    treeId,
    homeFamilyId,
    userId,
    name,
    email,
    about,
    avatarKey,
    birthDate,
    birthPrecision,
    deathDate,
    deathPrecision,
    passedAway,
    createdById,
    createdAt,
    updatedAt,
  ];
}

class PersonInclude extends _is.IncludeObject {
  PersonInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => Person.t;
}

class PersonIncludeList extends _is.IncludeList {
  PersonIncludeList._({
    _is.WhereExpressionBuilder<PersonTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Person.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => Person.t;
}

class PersonRepository {
  const PersonRepository._();

  /// Returns a list of [Person]s matching the given query parameters.
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
  Future<List<Person>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PersonTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PersonTable>? orderBy,
    _is.OrderByListBuilder<PersonTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Person>(
      where: where?.call(Person.t),
      orderBy: orderBy?.call(Person.t),
      orderByList: orderByList?.call(Person.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Person]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `Person.t`.
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
  _ida.Stream<List<Person>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PersonTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PersonTable>? orderBy,
    _is.OrderByListBuilder<PersonTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Person>(
      where: where?.call(Person.t),
      orderBy: orderBy?.call(Person.t),
      orderByList: orderByList?.call(Person.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Person] matching the given query parameters.
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
  Future<Person?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PersonTable>? where,
    int? offset,
    _is.OrderByBuilder<PersonTable>? orderBy,
    _is.OrderByListBuilder<PersonTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Person>(
      where: where?.call(Person.t),
      orderBy: orderBy?.call(Person.t),
      orderByList: orderByList?.call(Person.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Person] by its [id] or null if no such row exists.
  Future<Person?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Person>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Person]s in the list and returns the inserted rows.
  ///
  /// The returned [Person]s will have their `id` fields set.
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
  Future<List<Person>> insert(
    _is.DatabaseSession session,
    List<Person> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Person>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Person] and returns the inserted row.
  ///
  /// The returned [Person] will have its `id` field set.
  Future<Person> insertRow(
    _is.DatabaseSession session,
    Person row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Person>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Person]s in the list and returns the resulting rows.
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
  /// The returned [Person]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Person>> upsert(
    _is.DatabaseSession session,
    List<Person> rows, {
    required _is.ColumnSelections<PersonTable> conflictColumns,
    _is.ColumnSelections<PersonTable>? updateColumns,
    _is.WhereExpressionBuilder<PersonTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Person>(
      rows,
      conflictColumns: conflictColumns(Person.t),
      updateColumns: updateColumns?.call(Person.t),
      updateWhere: updateWhere?.call(Person.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Person] and returns the resulting row.
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
  /// The returned [Person] will have its `id` field set.
  Future<Person?> upsertRow(
    _is.DatabaseSession session,
    Person row, {
    required _is.ColumnSelections<PersonTable> conflictColumns,
    _is.ColumnSelections<PersonTable>? updateColumns,
    _is.WhereExpressionBuilder<PersonTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Person>(
      row,
      conflictColumns: conflictColumns(Person.t),
      updateColumns: updateColumns?.call(Person.t),
      updateWhere: updateWhere?.call(Person.t),
      transaction: transaction,
    );
  }

  /// Updates all [Person]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Person>> update(
    _is.DatabaseSession session,
    List<Person> rows, {
    _is.ColumnSelections<PersonTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Person>(
      rows,
      columns: columns?.call(Person.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Person]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Person> updateRow(
    _is.DatabaseSession session,
    Person row, {
    _is.ColumnSelections<PersonTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Person>(
      row,
      columns: columns?.call(Person.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Person] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Person?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<PersonUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Person>(
      id,
      columnValues: columnValues(Person.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Person]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Person>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<PersonUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<PersonTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PersonTable>? orderBy,
    _is.OrderByListBuilder<PersonTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Person>(
      columnValues: columnValues(Person.t.updateTable),
      where: where(Person.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Person.t),
      orderByList: orderByList?.call(Person.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Person]s in the list and returns the deleted rows.
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
  Future<List<Person>> delete(
    _is.DatabaseSession session,
    List<Person> rows, {
    _is.OrderByBuilder<PersonTable>? orderBy,
    _is.OrderByListBuilder<PersonTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Person>(
      rows,
      orderBy: orderBy?.call(Person.t),
      orderByList: orderByList?.call(Person.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Person].
  Future<Person> deleteRow(
    _is.DatabaseSession session,
    Person row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Person>(
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
  Future<List<Person>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<PersonTable> where,
    _is.OrderByBuilder<PersonTable>? orderBy,
    _is.OrderByListBuilder<PersonTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Person>(
      where: where(Person.t),
      orderBy: orderBy?.call(Person.t),
      orderByList: orderByList?.call(Person.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PersonTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Person>(
      where: where?.call(Person.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Person] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<PersonTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Person>(
      where: where(Person.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
