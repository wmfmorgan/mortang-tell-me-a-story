import 'dart:math';

import '../accounts/accounts.dart';
import '../errors.dart';
import '../generated/protocol.dart';

/// A calendar date and its precision; both null or both set.
typedef LifeDate = ({DateTime? date, DatePrecision? precision});

const LifeDate _noDate = (date: null, precision: null);

/// [date] aligned to [precision] as UTC midnight (schema-design.md §0.3):
/// a year is 1 January, a month the 1st. Both null gives no date. [label]
/// (`birth` or `death`) names the field in the `VALIDATION` message.
LifeDate normalizeLifeDate(
  String label,
  DateTime? date,
  DatePrecision? precision,
) {
  if (date == null && precision == null) return _noDate;
  if (date == null || precision == null) {
    throw validation('$label date and precision must both be set');
  }
  final d = date.toUtc();
  if (d.year < 1000 || d.year > 9999) {
    throw validation('$label year must be between 1000 and 9999');
  }
  return (
    date: switch (precision) {
      DatePrecision.year => DateTime.utc(d.year),
      DatePrecision.month => DateTime.utc(d.year, d.month),
      DatePrecision.day => DateTime.utc(d.year, d.month, d.day),
    },
    precision: precision,
  );
}

/// The account birth of a linked person as the caller sees it
/// (business-rules.md §4.6): [self] sees it raw; others see it coarsened to
/// the lower of `birthVisibility` and the stored precision.
LifeDate shownBirth(AppUser? account, {required bool self}) {
  final date = account?.birthDate;
  final precision = account?.birthPrecision;
  if (account == null || date == null || precision == null) return _noDate;
  if (self) return (date: date, precision: precision);
  final visibility = switch (account.birthVisibility) {
    BirthVisibility.hidden => 0,
    BirthVisibility.year => 1,
    BirthVisibility.yearMonth => 2,
    BirthVisibility.full => 3,
  };
  return switch (min(visibility, precision.index + 1)) {
    0 => _noDate,
    1 => (date: DateTime.utc(date.year), precision: DatePrecision.year),
    2 => (
      date: DateTime.utc(date.year, date.month),
      precision: DatePrecision.month,
    ),
    _ => (
      date: DateTime.utc(date.year, date.month, date.day),
      precision: DatePrecision.day,
    ),
  };
}

/// [person] with the field groups [input] writes, validated and normalized
/// (business-rules.md §4.3; schema-design.md §3.2 life dates). Authorization
/// (who may write a linked person, the name lock) is the caller's job.
Person applyPersonWrite(Person person, PersonWriteDto input) {
  final name = input.name.trim();
  if (name.isEmpty) throw validation('name is required');
  var next = person.copyWith(name: name);
  if (input.writeAbout) {
    final about = input.about?.trim() ?? '';
    if (about.length > 500) {
      throw validation('about must be at most 500 characters');
    }
    next = next.copyWith(about: about.isEmpty ? null : about);
  }
  if (input.writeEmail) {
    final email = normalizeEmail(input.email ?? '');
    next = next.copyWith(email: email.isEmpty ? null : email);
  }
  if (input.writePassedAway) {
    next = next.copyWith(passedAway: input.passedAway ?? false);
  }
  if (input.writeBirth) {
    if (person.userId != null) {
      throw validation('birth date comes from the account');
    }
    final birth = normalizeLifeDate(
      'birth',
      input.birthDate,
      input.birthPrecision,
    );
    next = next.copyWith(
      birthDate: birth.date,
      birthPrecision: birth.precision,
    );
  }
  if (input.writeDeath) {
    final death = normalizeLifeDate(
      'death',
      input.deathDate,
      input.deathPrecision,
    );
    if (death.date != null && !next.passedAway) {
      throw validation('death date needs passed away');
    }
    next = next.copyWith(
      deathDate: death.date,
      deathPrecision: death.precision,
    );
  }
  if (!next.passedAway) {
    next = next.copyWith(deathDate: null, deathPrecision: null);
  }
  final birth = next.birthDate;
  final death = next.deathDate;
  if (birth != null && death != null && death.year < birth.year) {
    throw validation('death is before birth');
  }
  return next;
}
