import 'package:freezed_annotation/freezed_annotation.dart';

part 'origin_dependent.freezed.dart';

/// A live family whose effective origin is [storyId].
@freezed
abstract class OriginDependent with _$OriginDependent {
  const factory OriginDependent({
    required String familyId,
    required String name,
  }) = _OriginDependent;
}
