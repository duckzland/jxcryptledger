import '../log.dart';

class CoreBaseExceptionConfig {
  static final bool showCodeToUser = () {
    final raw = String.fromEnvironment('HIDE_ERROR_CODE');
    if (raw.isEmpty) return true;
    return raw != 'true';
  }();
}

abstract class CoreBaseException implements Exception {
  final int code;
  final String devMessage;
  final Object? details;
  final bool silent;

  final String _rawUserMessage;

  CoreBaseException(this.code, this.devMessage, String userMessage, {this.details, this.silent = false}) : _rawUserMessage = userMessage {
    if (!silent) {
      logln('[$code] $devMessage');
    }
  }

  String get formattedUserMessage {
    final show = CoreBaseExceptionConfig.showCodeToUser;
    return show ? '[$code] $_rawUserMessage' : _rawUserMessage;
  }

  String get userMessage => formattedUserMessage;

  @override
  String toString() => '$runtimeType(code=$code, devMessage=$devMessage, userMessage=$formattedUserMessage)';
}
