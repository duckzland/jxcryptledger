import '../core/log.dart';

abstract class AppException implements Exception {
  final int code;
  final String devMessage;
  final String userMessage;
  final Object? details;
  final bool silent;

  AppException(this.code, this.devMessage, this.userMessage, {this.details, this.silent = false}) {
    if (!silent) {
      logln(devMessage);
    }
  }

  @override
  String toString() => '$runtimeType(code=$code, devMessage=$devMessage, userMessage=$userMessage)';
}

class ValidationException extends AppException {
  ValidationException(super.code, super.devMessage, super.userMessage, {super.details, super.silent});
}
