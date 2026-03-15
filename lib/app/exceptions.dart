import '../core/log.dart';

class AppErrorCode {
  static const int txBasicInvalidTid = 1001;
  static const int txBasicInvalidRid = 1002;
  static const int txBasicInvalidPid = 1003;
  static const int txBasicInvalidRootRelation = 1004;
  static const int txBasicInvalidSrAmount = 1005;
  static const int txBasicInvalidRrAmount = 1006;
  static const int txBasicInvalidBalance = 1007;
  static const int txBasicInvalidSrId = 1008;
  static const int txBasicInvalidRrId = 1009;
  static const int txBasicSrIdEqualsRrId = 1010;
  static const int txBasicInvalidStatus = 1011;
  static const int txBasicInvalidTimestamp = 1012;
  static const int txBasicTimestampInFuture = 1013;
  static const int txBasicInvalidMeta = 1014;

  static const int txJsonMissingField = 1015;
  static const int txJsonInvalidTidType = 1016;
  static const int txJsonInvalidRidType = 1017;
  static const int txJsonInvalidPidType = 1018;
  static const int txJsonInvalidSrAmountType = 1019;
  static const int txJsonInvalidRrAmountType = 1020;
  static const int txJsonInvalidBalanceType = 1021;
  static const int txJsonInvalidSrIdType = 1022;
  static const int txJsonInvalidRrIdType = 1023;
  static const int txJsonInvalidStatusType = 1024;
  static const int txJsonInvalidTimestampType = 1025;
  static const int txJsonInvalidClosableType = 1026;
  static const int txJsonInvalidMetaType = 1027;

  static const int txUpdateNotFound = 1101;
  static const int txUpdateRootPidRid = 1102;
  static const int txUpdateLeafMissingParent = 1103;
  static const int txUpdateCannotChangeSrRr = 1104;
  static const int txUpdateParentInsufficientBalance = 1105;
  static const int txUpdateInactiveRequiresChildren = 1106;
  static const int txUpdateInactiveRequiresZeroBalance = 1107;
  static const int txUpdateActiveRequiresBalance = 1108;
  static const int txUpdateActiveRequiresChildrenClosed = 1109;
  static const int txUpdatePartialRequiresChildren = 1110;
  static const int txUpdatePartialCannotAllClosed = 1111;
  static const int txUpdateClosedRoot = 1112;
  static const int txUpdateClosedRequiresTarget = 1113;
  static const int txUpdateClosableRootRequiresClosed = 1114;
  static const int txUpdateClosableLeafRequiresActive = 1115;
  static const int txUpdateClosableLeafRequiresTarget = 1116;
  static const int txUpdateNotClosableRootAllClosed = 1117;
  static const int txUpdateNotClosableLeafActiveTarget = 1118;

  static const int txCloseNotLeaf = 1201;
  static const int txCloseNotActive = 1202;
  static const int txCloseNoTarget = 1203;

  static const int txTradeNotFound = 1301;
  static const int txTradeMissingParent = 1302;
  static const int txTradeInvalidState = 1303;
  static const int txTradeInvalidBalance = 1304;

  static const int txAddStatusNotActive = 1401;
  static const int txAddRootBalanceMismatch = 1402;
  static const int txAddRootNotClosable = 1403;

  static const int txAddLeafMissingRoot = 1404;
  static const int txAddLeafMissingParent = 1405;
  static const int txAddLeafSrIdMismatch = 1406;
  static const int txAddLeafAmountExceedsBalance = 1407;
  static const int txAddLeafClosableNoTarget = 1408;
  static const int txAddLeafNotClosableHasTarget = 1409;

  static const int txDeleteNotRoot = 1501;
  static const int txDeleteActiveChildren = 1502;
  static const int txDeleteInactiveLeaves = 1503;

  static const int txRefundInactive = 1601;
  static const int txRefundRootClosed = 1602;
  static const int txRefundInsufficientBalance = 1603;
  static const int txRefundNotFound = 1604;
  static const int txRefundInvalidLinkage = 1605;
  static const int txRefundHasChildren = 1606;
  static const int txRefundParentMismatch = 1607;

  static const int txImportInvalidParent = 1701;
  static const int txImportInvalidRootStructure = 1702;
  static const int txImportSrIdMismatch = 1703;
  static const int txImportSrAmountExceedsParent = 1704;
  static const int txImportChildAmountSumExceeded = 1705;
  static const int txImportZeroBalanceNotInactive = 1706;
  static const int txImportNonZeroBalanceNotPartial = 1707;
  static const int txImportInvalidClosableState = 1708;
  static const int txImportDuplicateTid = 1709;
  static const int txImportNonZeroBalanceNotActive = 1710;
  static const int txImportInvalidRid = 1711;
  static const int txImportInvalidJSON = 1712;

  static const int netHttpFailure = 2001;
  static const int netEmptyResponse = 2002;
  static const int netParseFailure = 2003;
  static const int netUnknownFailure = 2004;
  static const int netMissingCryptos = 2005;
  static const int netInvalidRatePayload = 2100;

  static const int watcherWidEmpty = 3001;
  static const int watcherSourceInvalid = 3002;
  static const int watcherReferenceInvalid = 3003;
  static const int watcherPairSame = 3004;
  static const int watcherRateInvalid = 3005;
  static const int watcherLimitInvalid = 3006;
  static const int watcherDurationInvalid = 3007;
  static const int watcherMessageEmpty = 3008;
  static const int watcherInvalidOperator = 3009;

  static const int tickerBasicInvalidType = 4001;
  static const int tickerBasicInvalidSrAmount = 4002;
  static const int tickerBasicInvalidSrId = 4003;
  static const int tickerBasicInvalidRrId = 4004;
  static const int tickerBasicInvalidDigit = 4005;
  static const int tickerBasicInvalidRate = 4006;
  static const int tickerBasicInvalidValue = 4007;
  static const int tickerBasicInvalidOrder = 4008;
  static const int tickerBasicInvalidMeta = 4009;
  static const int tickerBasicInvalidTid = 4010;
  static const int tickerCannotRemoveStaticType = 4011;
  static const int tickerBasicInvalidTitle = 4012;
  static const int tickerBasicInvalidFormat = 4013;
}

class AppExceptionConfig {
  static final bool showCodeToUser = () {
    final raw = String.fromEnvironment('HIDE_ERROR_CODE');
    if (raw.isEmpty) return true;
    return raw != 'true';
  }();
}

abstract class AppException implements Exception {
  final int code;
  final String devMessage;
  final Object? details;
  final bool silent;

  final String _rawUserMessage;

  AppException(this.code, this.devMessage, String userMessage, {this.details, this.silent = false}) : _rawUserMessage = userMessage {
    if (!silent) {
      logln('[$code] $devMessage');
    }
  }

  String get formattedUserMessage {
    final show = AppExceptionConfig.showCodeToUser;
    return show ? '[$code] $_rawUserMessage' : _rawUserMessage;
  }

  String get userMessage => formattedUserMessage;

  @override
  String toString() => '$runtimeType(code=$code, devMessage=$devMessage, userMessage=$formattedUserMessage)';
}

class ValidationException extends AppException {
  ValidationException(super.code, super.devMessage, super.userMessage, {super.details, super.silent});
}

class NetworkingException extends AppException {
  NetworkingException(super.code, super.devMessage, super.userMessage, {super.details, super.silent});
}
