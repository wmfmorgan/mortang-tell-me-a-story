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

/// A story photo as the story card needs it. key = editedKey ?? originalKey.
abstract class PhotoRefDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PhotoRefDto._({
    required this.id,
    required this.key,
    required this.sortOrder,
  });

  factory PhotoRefDto({
    required _isc.UuidValue id,
    required String key,
    required int sortOrder,
  }) = _PhotoRefDtoImpl;

  factory PhotoRefDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return PhotoRefDto(
      id: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      key: jsonSerialization['key'] as String,
      sortOrder: jsonSerialization['sortOrder'] as int,
    );
  }

  _isc.UuidValue id;

  String key;

  int sortOrder;

  /// Returns a shallow copy of this [PhotoRefDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PhotoRefDto copyWith({
    _isc.UuidValue? id,
    String? key,
    int? sortOrder,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PhotoRefDto',
      'id': id.toJson(),
      'key': key,
      'sortOrder': sortOrder,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PhotoRefDto',
      'id': id.toJson(),
      'key': key,
      'sortOrder': sortOrder,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PhotoRefDtoImpl extends PhotoRefDto {
  _PhotoRefDtoImpl({
    required _isc.UuidValue id,
    required String key,
    required int sortOrder,
  }) : super._(
         id: id,
         key: key,
         sortOrder: sortOrder,
       );

  /// Returns a shallow copy of this [PhotoRefDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PhotoRefDto copyWith({
    _isc.UuidValue? id,
    String? key,
    int? sortOrder,
  }) {
    return PhotoRefDto(
      id: id ?? this.id,
      key: key ?? this.key,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
