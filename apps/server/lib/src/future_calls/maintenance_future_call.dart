import 'package:serverpod/serverpod.dart';

import '../families/purge.dart';
import '../media/blob_outbox.dart';

/// Recurring maintenance jobs, scheduled in `server.dart` (slice 3f).
class MaintenanceFutureCall extends FutureCall {
  /// Hard-deletes families soft-deleted more than 60 days ago
  /// (schema-design.md §4.3, D6c).
  Future<void> purgeFamilies(Session session) async {
    await purgeExpiredFamilies(session);
  }

  /// Deletes queued blobs from storage (schema-design.md §4.3).
  Future<void> drainBlobs(Session session) async {
    await drainBlobDeletions(session);
  }
}
