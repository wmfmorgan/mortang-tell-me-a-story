import '../generated/future_calls.dart';

/// Identifiers of the recurring maintenance calls in `serverpod_future_call`.
const purgeFamiliesCallId = 'purge-families';
const drainBlobsCallId = 'drain-blobs';

/// Schedules the purge (daily, 03:00 UTC) and the blob drain (every 10
/// minutes). Each identifier is cancelled first, so a re-boot replaces the
/// row instead of adding a second one. Call it after `pod.start()`.
Future<void> scheduleMaintenance(FutureCalls calls) async {
  await calls.cancel(purgeFamiliesCallId);
  await calls
      .callRecurring(identifier: purgeFamiliesCallId)
      .cron('0 3 * * *')
      .maintenance
      .purgeFamilies();
  await calls.cancel(drainBlobsCallId);
  await calls
      .callRecurring(identifier: drainBlobsCallId)
      .every(const Duration(minutes: 10))
      .maintenance
      .drainBlobs();
}
