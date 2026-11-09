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
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// Groups a root family and all its branches. Every family has exactly one tree;
/// "same tree" checks become an equality on treeId (no recursive parent walk).
abstract class Tree
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Tree._({
    this.id,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Tree({
    _isc.UuidValue? id,
    DateTime? createdAt,
  }) = _TreeImpl;

  factory Tree.fromJson(Map<String, dynamic> jsonSerialization) {
    return Tree(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  _isc.UuidValue? id;

  DateTime createdAt;

  /// Returns a shallow copy of this [Tree]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Tree copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
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

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _TreeImpl extends Tree {
  _TreeImpl({
    _isc.UuidValue? id,
    DateTime? createdAt,
  }) : super._(
         id: id,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Tree]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Tree copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    DateTime? createdAt,
  }) {
    return Tree(
      id: id is _isc.UndefinedSentinel ? this.id : id,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
