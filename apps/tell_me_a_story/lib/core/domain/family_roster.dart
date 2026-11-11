import 'package:freezed_annotation/freezed_annotation.dart';

part 'family_roster.freezed.dart';

/// Hub card. Active rows have a null [deletedAt].
@freezed
abstract class FamilyRoster with _$FamilyRoster {
  const factory FamilyRoster({
    required String id,
    required String name,
    required String role,
    required int memberCount,
    required int publishedCount,
    DateTime? deletedAt,
  }) = _FamilyRoster;
}
