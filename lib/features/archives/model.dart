import 'dart:convert';

import '../../app/exceptions.dart';
import '../../core/abstracts/models/exportable.dart';
import '../../core/abstracts/models/with_id.dart';
import '../../core/utils.dart';
import '../transactions/model.dart';
import '../watchboard/panels/model.dart';
import '../watchers/model.dart';

enum ArchivesDataType { transactions, watchboards, watchers }

class ArchivesModel implements CoreModelWithId, CoreModelExportable {
  final String aid;
  final int type;
  final String data;
  final int timestamp;
  final Map<String, dynamic> meta;

  @override
  String get uuid => aid;

  ArchivesModel({required this.aid, required this.type, required this.data, required this.timestamp, required this.meta}) {
    if (aid.isEmpty) {
      throw ValidationException(AppErrorCode.archiveAidEmpty, "Aid cannot be empty.", "Archive ID is missing.");
    }

    if (data.isEmpty) {
      throw ValidationException(AppErrorCode.archiveDataEmpty, "Data cannot be empty.", "Archive missing data.");
    }

    if (type < 0 || type >= ArchivesDataType.values.length) {
      throw ValidationException(AppErrorCode.archiveInvalidType, "Invalid type", "Invalid archive type detected");
    }

    final now = DateTime.now().toUtc().microsecondsSinceEpoch;

    if (timestamp <= 0) {
      throw ValidationException(AppErrorCode.archiveInvalidTimestamp, "Invalid timestamp", "Invalid timestamp");
    }

    if (timestamp > now) {
      throw ValidationException(
        AppErrorCode.archiveTimestampInFuture,
        "timestamp cannot be in the future (timestamp=$timestamp, now=$now).",
        "Date cannot be in the future.",
      );
    }
  }

  factory ArchivesModel.fromJson(Map<String, dynamic> json) {
    final aid = json['aid'] as String;
    final type = json['type'] as int;
    final data = json['data'] as String;
    final timestamp = json['timestamp'] as int;
    final meta = Map<String, dynamic>.from(json['meta'] as Map);

    if (data.isEmpty) {
      throw ValidationException(AppErrorCode.archiveDataEmpty, "Data cannot be empty.", "Archive missing data.");
    }

    final decoded = jsonDecode(data);

    switch (ArchivesDataType.values[type]) {
      case ArchivesDataType.transactions:
        (decoded as List).map((e) => TransactionsModel.fromJson(e as Map<String, dynamic>)).toList();
        break;

      case ArchivesDataType.watchboards:
        (decoded as List).map((e) => PanelsModel.fromJson(e as Map<String, dynamic>)).toList();
        break;

      case ArchivesDataType.watchers:
        (decoded as List).map((e) => WatchersModel.fromJson(e as Map<String, dynamic>)).toList();
        break;
    }

    return ArchivesModel(aid: aid, type: type, data: data, timestamp: timestamp, meta: meta);
  }

  @override
  Map<String, dynamic> toJson() {
    return {'aid': aid, 'type': type, 'data': data, 'timestamp': timestamp, 'meta': meta};
  }

  ArchivesModel copyWith({String? aid, int? type, String? data, int? timestamp, Map<String, dynamic>? meta}) {
    return ArchivesModel(
      aid: aid ?? this.aid,
      type: type ?? this.type,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      meta: meta ?? Map<String, dynamic>.from(this.meta),
    );
  }

  ArchivesDataType get typeEnum {
    switch (type) {
      case 0:
        return ArchivesDataType.transactions;
      case 1:
        return ArchivesDataType.watchboards;
      case 2:
        return ArchivesDataType.watchers;
    }

    throw ValidationException(AppErrorCode.archiveInvalidType, "Invalid type", "Invalid archive type detected");
  }

  String get typeText {
    switch (typeEnum) {
      case ArchivesDataType.transactions:
        return "Transactions";
      case ArchivesDataType.watchboards:
        return "Watchboards";
      case ArchivesDataType.watchers:
        return "Watchers";
    }
  }

  String get timestampAsFormattedDate {
    return Utils.timestampToFormattedDate(timestamp);
  }
}
