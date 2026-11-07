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

/// Junction story ↔ person (Serverpod tables always have an id; the old composite PK
/// becomes a unique index). https://docs.serverpod.dev/concepts/data-and-the-database/database/relations/many-to-many
abstract class StoryPerson
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  StoryPerson._({
    this.id,
    required this.storyId,
    required this.personId,
  });

  factory StoryPerson({
    _isc.UuidValue? id,
    required _isc.UuidValue storyId,
    required _isc.UuidValue personId,
  }) = _StoryPersonImpl;

  factory StoryPerson.fromJson(Map<String, dynamic> jsonSerialization) {
    return StoryPerson(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      storyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['storyId'],
      ),
      personId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['personId'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  _isc.UuidValue? id;

  _isc.UuidValue storyId;

  _isc.UuidValue personId;

  /// Returns a shallow copy of this [StoryPerson]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  StoryPerson copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? storyId,
    _isc.UuidValue? personId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StoryPerson',
      if (id != null) 'id': id?.toJson(),
      'storyId': storyId.toJson(),
      'personId': personId.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StoryPerson',
      if (id != null) 'id': id?.toJson(),
      'storyId': storyId.toJson(),
      'personId': personId.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _StoryPersonImpl extends StoryPerson {
  _StoryPersonImpl({
    _isc.UuidValue? id,
    required _isc.UuidValue storyId,
    required _isc.UuidValue personId,
  }) : super._(
         id: id,
         storyId: storyId,
         personId: personId,
       );

  /// Returns a shallow copy of this [StoryPerson]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  StoryPerson copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? storyId,
    _isc.UuidValue? personId,
  }) {
    return StoryPerson(
      id: id is _isc.UndefinedSentinel ? this.id : id,
      storyId: storyId ?? this.storyId,
      personId: personId ?? this.personId,
    );
  }
}
