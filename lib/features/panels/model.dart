import '../../app/exceptions.dart';

enum TickerType { marketCap, cmc100, rsi, pulse, etf, dominance, fearGreed, altcoinIndex, unknown }

enum TickerFormat { nodecimal, number, currency, shortCurrency, shortCurrencyWithSign, percentage, shortPercentage, raw }

class PanelsModel {
  final String tid;
  final double srAmount;
  final int srId;
  final int rrId;
  final int digit;
  double? rate;
  int? order;
  Map<String, dynamic> meta;

  PanelsModel({
    required this.tid,
    required this.srAmount,
    required this.srId,
    required this.rrId,
    required this.digit,
    this.rate,
    this.order,
    Map<String, dynamic>? meta,
  }) : meta = meta ?? {} {
    if (tid.isEmpty) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidTid, "tid cannot be empty.", "Please enter a transaction ID.");
    }
    if (tid == '0') {
      throw ValidationException(AppErrorCode.tickerBasicInvalidTid, "tid cannot be '0'.", "This transaction ID is not allowed.");
    }

    if (srAmount <= 0) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidSrAmount, "srAmount must be > 0.", "Invalid panel data.");
    }
    if (srId <= 0) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidSrId, "srId must be > 0.", "Invalid panel data.");
    }
    if (rrId <= 0) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidRrId, "srId must be > 0.", "Invalid panel data.");
    }
    if (digit < 2) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidDigit, "digit must be > 2.", "Invalid panel data.");
    }

    if (order != null && order! < 0) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidOrder, "order must be > 0.", "Invalid ordering.");
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
      srAmount: (map['srAmount'] as num).toDouble(),
      srId: map['srId'] as int,
      rrId: map['rrId'] as int,
      digit: map['digit'] as int,
      rate: (map['rate'] as num?)?.toDouble(),
      order: map['order'] as int?,
      meta: map['meta'] != null ? Map<String, dynamic>.from(map['meta']) : {},
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory PanelsModel.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('tid')) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidTid, "Missing required field: tid", "Invalid ticker data.");
    }
    if (json['tid'] is! String) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidTid, "tid must be a string.", "Invalid ticker data.");
    }
    if (json['srAmount'] is! num) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidSrAmount, "srAmount must be numeric.", "Invalid ticker data.");
    }
    if (json['srId'] is! num) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidSrId, "srId must be numeric.", "Invalid ticker data.");
    }
    if (json['rrId'] is! num) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidRrId, "rrId must be numeric.", "Invalid ticker data.");
    }
    if (json['digit'] is! num) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidDigit, "digit must be numeric.", "Invalid ticker data.");
    }

    return PanelsModel(
      tid: json['tid'] as String,
      srAmount: (json['srAmount'] as num).toDouble(),
      srId: (json['srId'] as num).toInt(),
      rrId: (json['rrId'] as num).toInt(),
      digit: (json['digit'] as num).toInt(),
      rate: (json['rate'] as num?)?.toDouble(),
      order: json['order'] as int?,
      meta: json['meta'] != null ? Map<String, dynamic>.from(json['meta']) : {},
    );
  }

  PanelsModel copyWith({
    String? tid,
    int? type,
    double? srAmount,
    int? srId,
    int? rrId,
    int? digit,
    double? rate,
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

  void setRate(double newRate) {
    if (newRate != rate) {
      meta["oldRate"] = rate;
      rate = newRate;
    }
  }

  bool isLinked() {
    return meta.containsKey('txLink');
  }

  int getStatus() {
    final prevRate = (meta["oldRate"] is num) ? (meta["oldRate"] as num).toDouble() : double.tryParse(meta["oldRate"]?.toString() ?? "");

    if (rate == null || prevRate == null) return 0;
    if (rate! > prevRate) return 1;
    if (rate! < prevRate) return -1;
    return 0;
  }
}
