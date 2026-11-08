import 'package:serverpod/serverpod.dart';
import 'package:serverpod_cloud_storage_gcp/serverpod_cloud_storage_gcp.dart';

import '../auth/local_mode.dart';
import 'blob_keys.dart';

/// Where [blobStorageId] keeps its objects.
sealed class BlobStorageChoice {
  const BlobStorageChoice();
}

/// Local developer and test servers: blobs in Postgres.
final class DatabaseBlobStorage extends BlobStorageChoice {
  const DatabaseBlobStorage();
}

/// Every other server: the private Google Cloud Storage [bucket].
final class GcsBlobStorage extends BlobStorageChoice {
  const GcsBlobStorage(this.bucket);

  final String bucket;
}

/// A local server ([isLocalConfig]) keeps blobs in the database; anything
/// else must name its bucket in the `gcsBucket` password
/// (`SERVERPOD_PASSWORD_gcsBucket`), and throws [StateError] without one
/// rather than silently falling back to the database.
BlobStorageChoice chooseBlobStorage({
  required bool local,
  required String? gcsBucket,
}) {
  if (local) return const DatabaseBlobStorage();
  final bucket = gcsBucket?.trim() ?? '';
  if (bucket.isEmpty) {
    throw StateError(
      'gcsBucket must be set in config/passwords.yaml (or the '
      'SERVERPOD_PASSWORD_gcsBucket env var) unless running locally with '
      'embedded Postgres',
    );
  }
  return GcsBlobStorage(bucket);
}

/// Registers the [blobStorageId] storage chosen by [chooseBlobStorage].
///
/// GCS uses Application Default Credentials (the Cloud Run service account):
/// the server reads, writes and deletes through the JSON API and signs the
/// browsers' direct-upload PUT URLs with IAM signBlob, so no key is stored.
Future<void> addBlobStorage(Serverpod pod) async {
  final choice = chooseBlobStorage(
    local: isLocalPod(pod),
    gcsBucket: pod.getPassword('gcsBucket'),
  );
  pod.addCloudStorage(switch (choice) {
    DatabaseBlobStorage() => DatabaseCloudStorage(blobStorageId),
    GcsBlobStorage(:final bucket) =>
      await NativeGoogleCloudStorage.fromApplicationDefaultCredentials(
        storageId: blobStorageId,
        bucket: bucket,
        public: false,
      ),
  });
}
