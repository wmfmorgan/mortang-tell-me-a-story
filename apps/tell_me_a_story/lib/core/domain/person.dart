import 'package:freezed_annotation/freezed_annotation.dart';

part 'person.freezed.dart';

/// A person in a family tree. [familyId] is the person's home family;
/// [avatarPath] is the picture's blob key.
@freezed
abstract class Person with _$Person {
  const factory Person({
    required String id,
    required String familyId,
    required String name,
    String? email,
    DateTime? birthDate,
    String? birthPrecision,
    DateTime? passingDate,
    String? passingPrecision,
    String? about,
    String? avatarPath,
    String? userId,
    @Default(false) bool passedAway,
  }) = _Person;
}

/// Year → YYYY-01-01, month → YYYY-MM-01, day → that date. Never a range.
({DateTime date, String precision}) storedPersonDate({
  required int year,
  int? month,
  int? day,
}) {
  if (month != null && day != null) {
    return (date: DateTime(year, month, day), precision: 'day');
  }
  if (month != null) {
    return (date: DateTime(year, month, 1), precision: 'month');
  }
  return (date: DateTime(year, 1, 1), precision: 'year');
}

/// Rejects an empty name, or an about longer than 500, before the network.
void ensureValidPersonCreate({required String name, String? about}) {
  if (name.trim().isEmpty) {
    throw ArgumentError.value(name, 'name', 'must not be empty');
  }
  if (about != null && about.length > 500) {
    throw ArgumentError.value(about, 'about', 'must be at most 500 characters');
  }
}
