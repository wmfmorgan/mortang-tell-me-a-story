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

/// A person tagged on a story.
abstract class StoryPersonDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  StoryPersonDto._({
    required this.personId,
    required this.name,
    this.userId,
  });

  factory StoryPersonDto({
    required _isc.UuidValue personId,
    required String name,
    _isc.UuidValue? userId,
  }) = _StoryPersonDtoImpl;

  factory StoryPersonDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return StoryPersonDto(
      personId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['personId'],
      ),
      name: jsonSerialization['name'] as String,
      userId: jsonSerialization['userId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
    );
  }

  _isc.UuidValue personId;

  String name;

  _isc.UuidValue? userId;

  /// Returns a shallow copy of this [StoryPersonDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  StoryPersonDto copyWith({
    _isc.UuidValue? personId,
    String? name,
    _isc.UuidValue? userId = const _isc.$UndefinedUuidValue(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StoryPersonDto',
      'personId': personId.toJson(),
      'name': name,
      if (userId != null) 'userId': userId?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StoryPersonDto',
      'personId': personId.toJson(),
      'name': name,
      if (userId != null) 'userId': userId?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _StoryPersonDtoImpl extends StoryPersonDto {
  _StoryPersonDtoImpl({
    required _isc.UuidValue personId,
    required String name,
    _isc.UuidValue? userId,
  }) : super._(
         personId: personId,
         name: name,
         userId: userId,
       );

  /// Returns a shallow copy of this [StoryPersonDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  StoryPersonDto copyWith({
    _isc.UuidValue? personId,
    String? name,
    _isc.UuidValue? userId = const _isc.$UndefinedUuidValue(),
  }) {
    return StoryPersonDto(
      personId: personId ?? this.personId,
      name: name ?? this.name,
      userId: userId is _isc.UndefinedSentinel ? this.userId : userId,
    );
  }
}
