import 'package:tell_me_a_story/core/domain/family_roster.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'family_directory.freezed.dart';

@freezed
abstract class FamilyDirectory with _$FamilyDirectory {
  const factory FamilyDirectory({
    required List<FamilyRoster> active,
    required List<FamilyRoster> recoverable,
  }) = _FamilyDirectory;
}
