import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/people/person_rules.dart';
import 'package:test/test.dart';

Matcher throwsValidation(String message) => throwsA(
  isA<AppException>()
      .having((e) => e.code, 'code', AppErrorCode.validation)
      .having((e) => e.message, 'message', message),
);

PersonWriteDto write({
  String name = 'Ada',
  String? about,
  bool writeAbout = false,
  String? email,
  bool writeEmail = false,
  bool? passedAway,
  bool writePassedAway = false,
  DateTime? birthDate,
  DatePrecision? birthPrecision,
  bool writeBirth = false,
  DateTime? deathDate,
  DatePrecision? deathPrecision,
  bool writeDeath = false,
}) => PersonWriteDto(
  name: name,
  about: about,
  writeAbout: writeAbout,
  email: email,
  writeEmail: writeEmail,
  passedAway: passedAway,
  writePassedAway: writePassedAway,
  clearPicture: false,
  birthDate: birthDate,
  birthPrecision: birthPrecision,
  writeBirth: writeBirth,
  deathDate: deathDate,
  deathPrecision: deathPrecision,
  writeDeath: writeDeath,
);

void main() {
  final treeId = UuidValue.fromString(const Uuid().v7());
  final familyId = UuidValue.fromString(const Uuid().v7());
  Person unlinked() =>
      Person(treeId: treeId, homeFamilyId: familyId, name: 'Old');

  AppUser account(
    BirthVisibility visibility,
    DateTime date,
    DatePrecision precision,
  ) => AppUser(
    authUserId: UuidValue.fromString(const Uuid().v7()),
    birthDate: date,
    birthPrecision: precision,
    birthVisibility: visibility,
  );

  group('Given a life date', () {
    test('when the precision is month then it becomes the 1st', () {
      final d = normalizeLifeDate(
        'birth',
        DateTime.utc(1950, 3, 17),
        DatePrecision.month,
      );
      expect(d.date, DateTime.utc(1950, 3));
      expect(d.precision, DatePrecision.month);
    });

    test('when the precision is year then it becomes 1 January', () {
      final d = normalizeLifeDate(
        'death',
        DateTime.utc(1950, 3, 17),
        DatePrecision.year,
      );
      expect(d.date, DateTime.utc(1950));
    });

    test('when only one half is set then VALIDATION', () {
      expect(
        () => normalizeLifeDate('birth', DateTime.utc(1950), null),
        throwsValidation('birth date and precision must both be set'),
      );
    });

    test('when the year is 999 then VALIDATION', () {
      expect(
        () => normalizeLifeDate('birth', DateTime.utc(999), DatePrecision.year),
        throwsValidation('birth year must be between 1000 and 9999'),
      );
    });
  });

  group('Given an account birth', () {
    final day = DateTime.utc(1950, 3, 17);

    // BR 100
    test('when visibility is hidden then others see nothing', () {
      final b = shownBirth(
        account(BirthVisibility.hidden, day, DatePrecision.day),
        self: false,
      );
      expect(b.date, isNull);
      expect(b.precision, isNull);
    });

    // BR 100
    test('when visibility is year then others see 1 January', () {
      final b = shownBirth(
        account(BirthVisibility.year, day, DatePrecision.day),
        self: false,
      );
      expect(b.date, DateTime.utc(1950));
      expect(b.precision, DatePrecision.year);
    });

    // BR 100
    test('when visibility is yearMonth then others see the 1st', () {
      final b = shownBirth(
        account(BirthVisibility.yearMonth, day, DatePrecision.day),
        self: false,
      );
      expect(b.date, DateTime.utc(1950, 3));
      expect(b.precision, DatePrecision.month);
    });

    // BR 100
    test('when visibility is full then others see the stored day', () {
      final b = shownBirth(
        account(BirthVisibility.full, day, DatePrecision.day),
        self: false,
      );
      expect(b.date, day);
      expect(b.precision, DatePrecision.day);
    });

    // BR 100
    test('when visibility is full and precision month then month', () {
      final b = shownBirth(
        account(
          BirthVisibility.full,
          DateTime.utc(1950, 3),
          DatePrecision.month,
        ),
        self: false,
      );
      expect(b.date, DateTime.utc(1950, 3));
      expect(b.precision, DatePrecision.month);
    });

    // BR 100
    test('when visibility is year and precision day then year', () {
      final b = shownBirth(
        account(BirthVisibility.year, day, DatePrecision.day),
        self: false,
      );
      expect(b.precision, DatePrecision.year);
    });

    // BR 100
    test('when the caller is the linked self then the birth is raw', () {
      final b = shownBirth(
        account(BirthVisibility.hidden, day, DatePrecision.day),
        self: true,
      );
      expect(b.date, day);
      expect(b.precision, DatePrecision.day);
    });
  });

  group('Given a person write', () {
    test('when the name is blank then VALIDATION', () {
      expect(
        () => applyPersonWrite(unlinked(), write(name: '  ')),
        throwsValidation('name is required'),
      );
    });

    // BR 96
    test('when about is over 500 chars then VALIDATION', () {
      expect(
        () => applyPersonWrite(
          unlinked(),
          write(about: 'x' * 501, writeAbout: true),
        ),
        throwsValidation('about must be at most 500 characters'),
      );
    });

    test('when fields are written then they are trimmed and normalized', () {
      final p = applyPersonWrite(
        unlinked(),
        write(
          name: ' Bea ',
          about: '  ',
          writeAbout: true,
          email: ' Bea@X.COM ',
          writeEmail: true,
        ),
      );
      expect(p.name, 'Bea');
      expect(p.about, isNull);
      expect(p.email, 'bea@x.com');
    });

    test('when a write flag is off then the field is kept', () {
      final p = applyPersonWrite(
        unlinked().copyWith(about: 'kept', email: 'k@x.com'),
        write(about: 'new', email: 'n@x.com'),
      );
      expect(p.about, 'kept');
      expect(p.email, 'k@x.com');
    });

    test('when birth is written on a linked person then VALIDATION', () {
      expect(
        () => applyPersonWrite(
          unlinked().copyWith(userId: UuidValue.fromString(const Uuid().v7())),
          write(
            birthDate: DateTime.utc(1950),
            birthPrecision: DatePrecision.year,
            writeBirth: true,
          ),
        ),
        throwsValidation('birth date comes from the account'),
      );
    });

    test(
      'when a death date is written without passed away then VALIDATION',
      () {
        expect(
          () => applyPersonWrite(
            unlinked(),
            write(
              deathDate: DateTime.utc(2000),
              deathPrecision: DatePrecision.year,
              writeDeath: true,
            ),
          ),
          throwsValidation('death date needs passed away'),
        );
      },
    );

    test('when passed away is cleared then the death fields clear', () {
      final p = applyPersonWrite(
        unlinked().copyWith(
          passedAway: true,
          deathDate: DateTime.utc(2000),
          deathPrecision: DatePrecision.year,
        ),
        write(passedAway: false, writePassedAway: true),
      );
      expect(p.passedAway, isFalse);
      expect(p.deathDate, isNull);
      expect(p.deathPrecision, isNull);
    });

    test('when death is before birth then VALIDATION', () {
      expect(
        () => applyPersonWrite(
          unlinked(),
          write(
            passedAway: true,
            writePassedAway: true,
            birthDate: DateTime.utc(1950),
            birthPrecision: DatePrecision.year,
            writeBirth: true,
            deathDate: DateTime.utc(1949),
            deathPrecision: DatePrecision.year,
            writeDeath: true,
          ),
        ),
        throwsValidation('death is before birth'),
      );
    });

    // BR 102
    test('when a precision is chosen then decade is not one of them', () {
      expect(DatePrecision.values.map((p) => p.name), [
        'year',
        'month',
        'day',
      ]);
    });
  });
}
