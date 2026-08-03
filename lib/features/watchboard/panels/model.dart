import 'package:decimal/decimal.dart';
import '../../../app/exceptions.dart';
import '../../../core/abstracts/models/exportable.dart';
import '../../../core/abstracts/models/with_id.dart';
import '../../../core/abstracts/models/rateable.dart';
import '../../../core/extensions/decimals.dart';

class PanelsModel implements CoreModelWithId, CoreModelExportable, CoreModelRateable {
  final String tid;
  final Decimal srAmount;
  final int digit;
  Decimal rate;
  int? order;
  Map<String, dynamic> meta;

  @override
  final int srId;

  @override
  final int rrId;

  @override
  String get uuid => tid;

  PanelsModel({
    required this.tid,
    required this.srAmount,
    required this.srId,
    required this.rrId,
    required this.digit,
    required this.rate,
    this.order,
    Map<String, dynamic>? meta,
  }) : meta = meta ?? {} {
    if (tid.isEmpty) {
      throw ValidationException(AppErrorCode.panelBasicInvalidTid, "tid cannot be empty.", "Please enter a watchboard panel ID.");
    }

    if (tid == '0') {
      throw ValidationException(AppErrorCode.panelBasicInvalidTid, "tid cannot be '0'.", "This watchboard panel ID is not allowed.");
    }

    if (srAmount <= Decimal.zero) {
      throw ValidationException(AppErrorCode.panelBasicInvalidSrAmount, "srAmount must be > 0.", "Invalid watchboard data.");
    }

    if (srId <= 0) {
      throw ValidationException(AppErrorCode.panelBasicInvalidSrId, "srId must be > 0.", "Invalid watchboard data.");
    }

    if (rrId <= 0) {
      throw ValidationException(AppErrorCode.panelBasicInvalidRrId, "srId must be > 0.", "Invalid watchboard data.");
    }

    if (digit < 2) {
      throw ValidationException(AppErrorCode.panelBasicInvalidDigit, "digit must be > 2.", "Invalid watchboard data.");
    }

    if (order != null && order! < 0) {
      throw ValidationException(AppErrorCode.panelBasicInvalidOrder, "order must be > 0.", "Invalid ordering.");
    }

    this.meta.putIfAbsent("oldRate", () => null);
    this.meta.putIfAbsent("txLinx", () => null);
  }

  Map<String, dynamic> toMap() {
    return {'tid': tid, 'srAmount': srAmount, 'srId': srId, 'rrId': rrId, 'digit': digit, 'rate': rate, 'order': order, 'meta': meta};
  }

  factory PanelsModel.fromMap(Map<String, dynamic> map) {
    return PanelsModel(
      tid: map['tid'] as String,
      srAmount: map['srAmount'] as Decimal,
      srId: map['srId'] as int,
      rrId: map['rrId'] as int,
      digit: map['digit'] as int,
      rate: map['rate'] as Decimal,
      order: map['order'] as int?,
      meta: map['meta'] != null ? Map<String, dynamic>.from(map['meta']) : {},
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'tid': tid,
      'srAmount': srAmount.toString(),
      'srId': srId,
      'rrId': rrId,
      'digit': digit,
      'rate': rate.toString(),
      'order': order,
      'meta': meta,
    };
  }

  factory PanelsModel.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('tid')) {
      throw ValidationException(AppErrorCode.panelBasicInvalidTid, "Missing required field: tid", "Invalid watchboard data.");
    }

    if (json['tid'] is! String) {
      throw ValidationException(AppErrorCode.panelBasicInvalidTid, "tid must be a string.", "Invalid watchboard data.");
    }

    if (json['srAmount'] is! num && !(json['srAmount'] is String && Decimal.tryParse(json['srAmount'] as String) != null)) {
      throw ValidationException(AppErrorCode.panelBasicInvalidSrAmount, "srAmount must be numeric.", "Invalid watchboard data.");
    }

    if (json['srId'] is! num) {
      throw ValidationException(AppErrorCode.panelBasicInvalidSrId, "srId must be numeric.", "Invalid watchboard data.");
    }

    if (json['rrId'] is! num) {
      throw ValidationException(AppErrorCode.panelBasicInvalidRrId, "rrId must be numeric.", "Invalid watchboard data.");
    }

    if (json['digit'] is! num) {
      throw ValidationException(AppErrorCode.panelBasicInvalidDigit, "digit must be numeric.", "Invalid watchboard data.");
    }

    if (json['rate'] is! num && !(json['rate'] is String && Decimal.tryParse(json['rate'] as String) != null)) {
      throw ValidationException(AppErrorCode.panelBasicInvalidRate, "rate must be numeric.", "Invalid watchboard data.");
    }

    return PanelsModel(
      tid: json['tid'] as String,
      srAmount: (json['srAmount'] as Object?).toDecimal() ?? Decimal.zero,
      srId: (json['srId'] as num).toInt(),
      rrId: (json['rrId'] as num).toInt(),
      digit: (json['digit'] as num).toInt(),
      rate: (json['rate'] as Object?).toDecimal() ?? Decimal.zero,
      order: json['order'] as int?,
      meta: json['meta'] != null ? Map<String, dynamic>.from(json['meta']) : {},
    );
  }

  PanelsModel copyWith({
    String? tid,
    int? type,
    Decimal? srAmount,
    int? srId,
    int? rrId,
    int? digit,
    Decimal? rate,
    String? value,
    int? order,
    Map<String, dynamic>? meta,
  }) {
    return PanelsModel(
      tid: tid ?? this.tid,
      srAmount: srAmount ?? this.srAmount,
      srId: srId ?? this.srId,
      rrId: rrId ?? this.rrId,
      digit: digit ?? this.digit,
      rate: rate ?? this.rate,
      order: order ?? this.order,
      meta: meta ?? this.meta,
    );
  }

  void setRate(Decimal newRate) {
    final oldRateStr = meta["oldRate"]?.toString();
    final oldRate = oldRateStr != null ? Decimal.tryParse(oldRateStr) : null;

    if (newRate == Decimal.fromInt(-9999) && oldRate != Decimal.fromInt(-9999)) {
      return;
    }

    if (newRate != rate) {
      meta["oldRate"] = rate.toString();
      rate = newRate;
    }
  }

  int get status {
    if (rate == Decimal.fromInt(-9999)) {
      return 0;
    }

    final oldRateStr = meta["oldRate"]?.toString();
    if (oldRateStr == null || oldRateStr.isEmpty) return 0;

    final prevRate = Decimal.tryParse(oldRateStr);
    if (prevRate == null) return 0;

    if (rate > prevRate) return 1;
    if (rate < prevRate) return -1;
    return 0;
  }

  @override
  bool get isRateable {
    return true;
  }

  bool get isLinked {
    return meta.containsKey('txLink');
  }
}
