import 'package:serverpod/protocol.dart' show FutureCallEntry;
import 'package:tell_me_a_story_server/src/future_calls/schedule.dart';
import 'package:tell_me_a_story_server/src/generated/future_calls.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given the maintenance schedule', (sessionBuilder, endpoints) {
    test('when it is registered twice (two boots) then each identifier has '
        'one row', () async {
      final s = sessionBuilder.build();
      await scheduleMaintenance(FutureCalls());
      await scheduleMaintenance(FutureCalls());

      for (final id in [purgeFamiliesCallId, drainBlobsCallId]) {
        final rows = await FutureCallEntry.db.find(
          s,
          where: (t) => t.identifier.equals(id),
        );
        expect(rows, hasLength(1), reason: id);
      }
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
