/// Base class for all custom application exceptions.
abstract class AppException implements Exception {
  final String message;
  final Object? details;

  AppException(this.message, {this.details});

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when encryption or decryption fails.
class EncryptionException extends AppException {
  EncryptionException(super.message, {super.details});
}

/// Thrown when a required key is missing or invalid.
class MissingKeyException extends AppException {
  MissingKeyException(super.message, {super.details});
}

/// Thrown when reading or writing local storage fails.
class StorageException extends AppException {
  StorageException(super.message, {super.details});
}

/// Thrown when input validation fails.
class ValidationException extends AppException {
  ValidationException(super.message, {super.details});
}

/// Fallback for unexpected errors.
class UnknownAppException extends AppException {
  UnknownAppException(super.message, {super.details});
}
