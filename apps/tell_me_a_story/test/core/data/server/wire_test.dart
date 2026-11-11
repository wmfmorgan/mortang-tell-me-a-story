import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/data/server/wire.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

void main() {
  group('date-only values', () {
    test('a local calendar day travels as UTC midnight of that day', () {
      expect(
        toWireDate(DateTime(1974, 7, 14, 23, 30)),
        DateTime.utc(1974, 7, 14),
      );
      expect(toWireDate(null), isNull);
    });

    test('a wire date comes back as the same local calendar day', () {
      final day = fromWireDate(DateTime.utc(1974, 7, 14));
      expect(day, DateTime(1974, 7, 14));
      expect(day!.isUtc, isFalse);
      expect(fromWireDate(null), isNull);
    });

    test('a round trip keeps the calendar day', () {
      final day = DateTime(2000, 2, 29);
      expect(fromWireDate(toWireDate(day)), day);
    });
  });

  group('membership roles', () {
    test('server roles use the client role strings', () {
      expect(roleName(server.MembershipRole.owner), 'owner');
      expect(roleName(server.MembershipRole.coOwner), 'co_owner');
      expect(roleName(server.MembershipRole.member), 'member');
    });

    test('client role strings map back, and unknown strings are refused', () {
      for (final role in server.MembershipRole.values) {
        expect(roleFromName(roleName(role)), role);
      }
      expect(() => roleFromName('admin'), throwsArgumentError);
    });
  });

  group('date precision', () {
    test('year, month and day round-trip through their names', () {
      for (final precision in server.DatePrecision.values) {
        expect(precisionFromName(precisionName(precision)), precision);
      }
      expect(precisionFromName(null), isNull);
    });

    test('decade is refused: it was dropped (D9)', () {
      expect(() => precisionFromName('decade'), throwsArgumentError);
    });
  });
}
