/// Typed failure for missing token or non-200 geocode responses.
class MapboxSearchException implements Exception {
  MapboxSearchException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? message : '$message (status $statusCode)';
}
