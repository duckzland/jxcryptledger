import '../../app/exceptions.dart';
import '../../core/abstracts/models/exportable.dart';
import '../../core/abstracts/models/with_id.dart';
import '../../core/abstracts/models/rateable.dart';

enum WatchersOperator { equal, lessThan, greaterThan }

class WatchersModel implements CoreModelWithId, CoreModelExportable, CoreModelRateable {
  final String wid;
  final int sent;
  final int operator;
  final int limit;
  final double rates;
  final int duration;
  final String message;
  final int timestamp;
  final Map<String, dynamic> meta;

  @override
  final int srId;

  @override
  final int rrId;

  @override
  String get uuid => wid;

  WatchersModel({
    required this.wid,
    required this.srId,
    required this.rrId,
    required this.rates,
    required this.sent,
    required this.operator,
    required this.limit,
    required this.duration,
    required this.message,
    required this.timestamp,
    required this.meta,
  }) {
    if (wid.isEmpty) {
      throw ValidationException(AppErrorCode.watcherWidEmpty, "wid cannot be empty.", "Rate Watcher ID is missing.");
    }

    if (srId <= 0) {
      throw ValidationException(AppErrorCode.watcherSourceInvalid, "srId must be a valid crypto ID.", "Please select a source coin.");
    }

    if (rrId <= 0) {
      throw ValidationException(AppErrorCode.watcherReferenceInvalid, "rrId must be a valid crypto ID.", "Please select a reference coin.");
    }

    if (srId == rrId) {
      throw ValidationException(
        AppErrorCode.watcherPairSame,
        "srId and rrId cannot be the same.",
        "Source and reference coins must be different.",
      );
    }

    if (rates <= 0) {
      throw ValidationException(AppErrorCode.watcherRateInvalid, "rates must be greater than zero.", "Enter a valid target rate.");
    }

    if (limit < 1) {
      throw ValidationException(AppErrorCode.watcherLimitInvalid, "limit must be >= 1.", "Limit must be at least 1.");
    }

    if (duration < 1) {
      throw ValidationException(AppErrorCode.watcherDurationInvalid, "duration must be >= 1.", "Duration must be at least 1 minute.");
    }

    if (operator < 0 || operator >= WatchersOperator.values.length) {
      throw ValidationException(AppErrorCode.watcherInvalidOperator, "invalid operator", "Invalid operator detected");
    }
  }

  factory WatchersModel.fromJson(Map<String, dynamic> json) {
    return WatchersModel(
      wid: json['wid'] as String,
      srId: json['srId'] as int,
      rrId: json['rrId'] as int,
      rates: (json['rate'] as num).toDouble(),
      sent: json['sent'] as int,
      operator: json['operator'] as int,
      limit: json['limit'] as int,
      duration: json['duration'] as int,
      message: json['message'] as String,
      timestamp: json['timestamp'] as int,
      meta: Map<String, dynamic>.from(json['meta'] as Map),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'wid': wid,
      'srId': srId,
      'rrId': rrId,
      'rates': rates,
      'sent': sent,
      'operator': operator,
      'limit': limit,
      'duration': duration,
      'message': message,
      'timestamp': timestamp,
      'meta': meta,
    };
  }

  WatchersModel copyWith({
    String? wid,
    int? srId,
    int? rrId,
    double? rate,
    int? sent,
    int? operator,
    int? limit,
    int? duration,
    String? message,
    int? timestamp,
    Map<String, dynamic>? meta,
  }) {
    return WatchersModel(
      wid: wid ?? this.wid,
      srId: srId ?? this.srId,
      rrId: rrId ?? this.rrId,
      rates: rate ?? this.rates,
      sent: sent ?? this.sent,
      operator: operator ?? this.operator,
      limit: limit ?? this.limit,
      duration: duration ?? this.duration,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      meta: meta ?? Map<String, dynamic>.from(this.meta),
    );
  }

  WatchersOperator get operatorEnum {
    switch (operator) {
      case 0:
        return WatchersOperator.equal;
      case 1:
        return WatchersOperator.lessThan;
      default:
        return WatchersOperator.greaterThan;
    }
  }

  String get operatorMessage {
    switch (operatorEnum) {
      case WatchersOperator.equal:
        return "equal to";
      case WatchersOperator.lessThan:
        return "less than";
      case WatchersOperator.greaterThan:
        return "greater than";
    }
  }

  String get operatorText {
    switch (operatorEnum) {
      case WatchersOperator.equal:
        return '=';
      case WatchersOperator.lessThan:
        return '<';
      case WatchersOperator.greaterThan:
        return '>';
    }
  }

  bool isLinked() {
    return meta.containsKey('txLink');
  }

  bool isSpent() {
    return sent > 0 && limit > 0 && sent >= limit;
  }
}
