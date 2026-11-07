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
import 'package:serverpod/serverpod.dart' as _is;

/// A person tagged on a story.
abstract class StoryPersonDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  StoryPersonDto._({
    required this.personId,
    required this.name,
    this.userId,
  });

  factory StoryPersonDto({
    required _is.UuidValue personId,
    required String name,
    _is.UuidValue? userId,
  }) = _StoryPersonDtoImpl;

  factory StoryPersonDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return StoryPersonDto(
      personId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['personId'],
      ),
      name: jsonSerialization['name'] as String,
      userId: jsonSerialization['userId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
    );
  }

  _is.UuidValue personId;

  String name;

  _is.UuidValue? userId;

  /// Returns a shallow copy of this [StoryPersonDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StoryPersonDto copyWith({
    _is.UuidValue? personId,
    String? name,
    _is.UuidValue? userId = const _is.$UndefinedUuidValue(),
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
    return _is.SerializationManager.encode(this);
  }
}

class _StoryPersonDtoImpl extends StoryPersonDto {
  _StoryPersonDtoImpl({
    required _is.UuidValue personId,
    required String name,
    _is.UuidValue? userId,
  }) : super._(
         personId: personId,
         name: name,
         userId: userId,
       );

  /// Returns a shallow copy of this [StoryPersonDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StoryPersonDto copyWith({
    _is.UuidValue? personId,
    String? name,
    _is.UuidValue? userId = const _is.$UndefinedUuidValue(),
  }) {
    return StoryPersonDto(
      personId: personId ?? this.personId,
      name: name ?? this.name,
      userId: userId is _is.UndefinedSentinel ? this.userId : userId,
    );
  }
}
