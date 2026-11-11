/// A family cover save the app refused or the server rejected; [message]
/// is user copy.
class CoverPhotoException implements Exception {
  CoverPhotoException(this.message);

  final String message;
}
