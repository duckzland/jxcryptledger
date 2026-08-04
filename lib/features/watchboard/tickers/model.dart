import 'package:decimal/decimal.dart';

import '../../../app/exceptions.dart';
import '../../../core/abstracts/models/with_id.dart';
import '../../../core/utils.dart';

enum TickerType {
  marketCap,
  cmc100,
  rsi,
  pulse,
  etf,
  dominance,
  fearGreed,
  altcoinIndex,
  topGainer100_1h,
  topGainer100_24h,
  topLoser100_1h,
  topLoser100_24h,
  topGainer200_1h,
  topGainer200_24h,
  topLoser200_1h,
  topLoser200_24h,
  unknown,
}

enum TickerFormat {
  nodecimal,
  normalNumber,
  normalCurrency,
  shortCurrency,
  shortCurrencyWithSign,
  percentage,
  shortPercentage,
  shortPercentageWithSign,
  raw,
}

class TickersModel implements CoreModelWithId {
  final String tid;
  final int type;
  final int format;
  final String title;
  int order;
  Map<String, dynamic> meta;

  String _value;

  @override
  String get uuid => tid;

  TickersModel({
    required this.tid,
    required this.type,
    required this.format,
    required this.title,
    required this.order,
    String value = "",
    Map<String, dynamic>? meta,
  }) : _value = value,
       meta = meta ?? {} {
    if (tid.isEmpty) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidTid, "tid cannot be empty.", "Please enter a ticker ID.");
    }
    if (tid == '0') {
      throw ValidationException(AppErrorCode.tickerBasicInvalidTid, "tid cannot be '0'.", "This ticker ID is not allowed.");
    }
    if (order < 0) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidOrder, "order must be > 0.", "Invalid ordering.");
    }
    if (title.isEmpty) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidTitle, "title cannot be empty.", "Invalid ticker data.");
    }
    if (format < 0 || format >= TickerFormat.values.length) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidFormat, "format must be valid.", "Invalid ticker data.");
    }
    if (type < 0 || type >= TickerType.values.length) {
      throw ValidationException(AppErrorCode.tickerBasicInvalidType, "type must be valid.", "Invalid ticker data.");
    }
  }

  Map<String, dynamic> toMap() {
    return {'tid': tid, 'type': type, 'format': format, 'title': title, 'order': order, 'value': value, 'meta': meta};
  }

  factory TickersModel.fromMap(Map<String, dynamic> map) {
    return TickersModel(
      tid: map['tid'] as String,
      type: map['type'] as int,
      format: map['format'] as int,
      title: map['title'] as String,
      order: map['order'] as int,
      value: map['value'] as String? ?? "",
      meta: map['meta'] != null ? Map<String, dynamic>.from(map['meta']) : {},
    );
  }

  TickersModel copyWith({
    String? tid,
    int? type,
    int? format,
    String? title,
    int? order,
    String? value,
    double? rate,
    Map<String, dynamic>? meta,
  }) {
    return TickersModel(
      tid: tid ?? this.tid,
      type: type ?? this.type,
      format: format ?? this.format,
      title: title ?? this.title,
      order: order ?? this.order,
      value: value ?? this.value,
      meta: meta ?? Map<String, dynamic>.from(this.meta),
    );
  }

  String get value => _value;

  set value(String newValue) {
    if (newValue.isNotEmpty && newValue != _value) {
      meta['oldValue'] = _value;
      _value = newValue;
    }
  }

  TickerType getType() {
    switch (type) {
      case 0:
        return TickerType.marketCap;
      case 1:
        return TickerType.cmc100;
      case 2:
        return TickerType.rsi;
      case 3:
        return TickerType.pulse;
      case 4:
        return TickerType.etf;
      case 5:
        return TickerType.dominance;
      case 6:
        return TickerType.fearGreed;
      case 7:
        return TickerType.altcoinIndex;
      case 8:
        return TickerType.topGainer100_1h;
      case 9:
        return TickerType.topGainer100_24h;
      case 10:
        return TickerType.topLoser100_1h;
      case 11:
        return TickerType.topLoser100_24h;
      case 12:
        return TickerType.topGainer200_1h;
      case 13:
        return TickerType.topGainer200_24h;
      case 14:
        return TickerType.topLoser200_1h;
      case 15:
        return TickerType.topLoser200_24h;
      default:
        return TickerType.unknown;
    }
  }

  String getTitle() {
    return title;
  }

  String getContent() {
    final raw = value;
    final fmt = (format >= 0 && format < TickerFormat.values.length) ? TickerFormat.values[format] : TickerFormat.raw;

    final val = Decimal.tryParse(raw);
    if (val == null) {
      return raw;
    }

    switch (fmt) {
      case TickerFormat.nodecimal:
        return val.toStringAsFixed(0);

      case TickerFormat.normalNumber:
        return val.toStringAsFixed(2);

      case TickerFormat.normalCurrency:
        return "\$${Utils.formatSmartDecimal(val, maxDecimals: 2)}";

      case TickerFormat.shortCurrency:
        return _formatShortCurrency(val);

      case TickerFormat.shortCurrencyWithSign:
        final sign = val < Decimal.zero ? "-" : "+";
        return "$sign${_formatShortCurrency(val.abs())}";

      case TickerFormat.percentage:
        return "$raw/100";

      case TickerFormat.shortPercentage:
        return "${val.toStringAsFixed(2)}%";

      case TickerFormat.shortPercentageWithSign:
        final sign = val < Decimal.zero ? "" : "+";
        return "$sign${val.toStringAsFixed(2)}%";

      case TickerFormat.raw:
        return raw;
    }
  }

  String _formatShortCurrency(Decimal val) {
    final thousand = Decimal.fromInt(1000);
    final million = Decimal.fromInt(1000000);
    final billion = Decimal.fromInt(1000000000);
    final trillion = Decimal.fromInt(1000000000000);

    if (val >= trillion) {
      return "${(val / trillion).toDecimal().round(scale: 2)}T";
    }

    if (val >= billion) {
      return "${(val / billion).toDecimal().round(scale: 2)}B";
    }

    if (val >= million) {
      return "${(val / million).toDecimal().round(scale: 2)}M";
    }

    if (val >= thousand) {
      return "${(val / thousand).toDecimal().round(scale: 2)}K";
    }

    return val.round(scale: 2).toString();
  }
}
