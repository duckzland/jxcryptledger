import '../core/log.dart';

class AppErrorCode {
  static const int txSourceIdEqualResultId = 1001;

  static const int txUpdateNotFound = 1101;
  static const int txUpdateRootPidRid = 1102;
  static const int txUpdateLeafMissingParent = 1103;
  static const int txUpdateInvalidFields = 1104;
  static const int txUpdateCannotChangeSrRr = 1105;
  static const int txUpdateParentInsufficientBalance = 1106;
  static const int txUpdateStatusInvalidInactive = 1107;
  static const int txUpdateStatusInvalidActive = 1108;
  static const int txUpdateStatusInvalidPartial = 1109;
  static const int txUpdateStatusInvalidClosed = 1110;
  static const int txUpdateClosableInvalid = 1111;
  static const int txUpdateInactiveRequiresChildren = 1112;
  static const int txUpdateInactiveRequiresZeroBalance = 1113;
  static const int txUpdateActiveRequiresBalance = 1114;
  static const int txUpdateActiveRequiresChildrenClosed = 1115;
  static const int txUpdatePartialRequiresChildren = 1116;
  static const int txUpdatePartialCannotAllClosed = 1117;
  static const int txUpdateClosedRoot = 1118;
  static const int txUpdateClosedRequiresTarget = 1119;
  static const int txUpdateClosableRootRequiresClosed = 1120;
  static const int txUpdateClosableLeafRequiresActive = 1121;
  static const int txUpdateClosableLeafRequiresTarget = 1122;
  static const int txUpdateNotClosableRootAllClosed = 1123;
  static const int txUpdateNotClosableLeafActiveTarget = 1124;

  static const int txCloseRoot = 1201;
  static const int txCloseNotActive = 1202;
  static const int txCloseNoTarget = 1203;

  static const int txTradeInvalidId = 1301;
  static const int txTradeNotFound = 1302;
  static const int txTradeMissingParent = 1303;
  static const int txTradeInvalidState = 1304;
  static const int txTradeInvalidFields = 1305;
  static const int txTradeInvalidBalance = 1306;

  static const int txAddInvalidTid = 1401;
  static const int txAddPidZeroRidNotZero = 1402;
  static const int txAddRidZeroPidNotZero = 1403;
  static const int txAddInvalidFields = 1404;
  static const int txAddStatusNotActive = 1405;
  static const int txAddRootBalanceMismatch = 1406;
  static const int txAddRootNotClosable = 1407;
  static const int txAddLeafMissingRoot = 1408;
  static const int txAddLeafMissingParent = 1409;
  static const int txAddLeafSrIdMismatch = 1410;
  static const int txAddLeafAmountExceedsBalance = 1411;
  static const int txAddLeafClosableNoTarget = 1412;
  static const int txAddLeafNotClosableHasTarget = 1413;

  static const int txDeleteNotRoot = 1501;
  static const int txDeleteActiveChildren = 1502;
  static const int txDeleteInactiveLeaves = 1503;

  static const int netHttpFailure = 2001;
  static const int netEmptyResponse = 2002;
  static const int netParseFailure = 2003;
  static const int netUnknownFailure = 2004;
  static const int netInvalidRatePayload = 2100;
}

class AppExceptionConfig {
  static final bool showCodeToUser = () {
    const raw = String.fromEnvironment('HIDE_ERROR_CODE');
    if (raw.isEmpty) return true;
    return raw != 'true';
  }();
}

abstract class AppException implements Exception {
  final int code;
  final String devMessage;
  final String userMessage;
  final Object? details;
  final bool silent;

  AppException(this.code, this.devMessage, this.userMessage, {this.details, this.silent = false}) {
    if (!silent) {
      logln('[$code] $devMessage');
    }
  }

  String get formattedUserMessage {
    if (AppExceptionConfig.showCodeToUser) {
      return '$code - $userMessage';
    }
    return userMessage;
  }

  @override
  String toString() => '$runtimeType(code=$code, devMessage=$devMessage, userMessage=$formattedUserMessage)';
}

class ValidationException extends AppException {
  ValidationException(super.code, super.devMessage, super.userMessage, {super.details, super.silent});
}

class NetworkingException extends AppException {
  NetworkingException(super.code, super.devMessage, super.userMessage, {super.details, super.silent});
}
