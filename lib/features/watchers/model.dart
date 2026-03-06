import '../../app/exceptions.dart';

class WatchersModel {
  final String wid;
  final int srId;
  final int rrId;
  final double rates;
  final int sent;
  final int limit;
  final int duration;
  final String message;
  final int timestamp;

  WatchersModel({
    required this.wid,
    required this.srId,
    required this.rrId,
    required this.rates,
    required this.sent,
    required this.limit,
    required this.duration,
    required this.message,
    required this.timestamp,
  }) {
    if (wid.isEmpty) {
      throw ValidationException(AppErrorCode.watcherWidEmpty, "wid cannot be empty.", "Watcher ID is missing.");
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

    if (duration <= 1) {
      throw ValidationException(AppErrorCode.watcherDurationInvalid, "duration must be >= 1.", "Duration must be at least 1 minute.");
    }

    if (message.trim().isEmpty) {
      throw ValidationException(AppErrorCode.watcherMessageEmpty, "message cannot be empty.", "Please enter a notification message.");
    }
  }

  factory WatchersModel.fromJson(Map<String, dynamic> json) {
    return WatchersModel(
      wid: json['wid'] as String,
      srId: json['srId'] as int,
      rrId: json['rrId'] as int,
      rates: (json['rates'] as num).toDouble(),
      sent: json['sent'] as int,
      limit: json['limit'] as int,
      duration: json['duration'] as int,
      message: json['message'] as String,
      timestamp: json['timestamp'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wid': wid,
      'srId': srId,
      'rrId': rrId,
      'rates': rates,
      'sent': sent,
      'limit': limit,
      'duration': duration,
      'message': message,
      'timestamp': timestamp,
    };
  }

  WatchersModel copyWith({
    String? wid,
    int? srId,
    int? rrId,
    double? rates,
    int? sent,
    int? limit,
    int? duration,
    String? message,
    int? timestamp,
  }) {
    return WatchersModel(
      wid: wid ?? this.wid,
      srId: srId ?? this.srId,
      rrId: rrId ?? this.rrId,
      rates: rates ?? this.rates,
      sent: sent ?? this.sent,
      limit: limit ?? this.limit,
      duration: duration ?? this.duration,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
