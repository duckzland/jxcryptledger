import '../../../app/exceptions.dart';
import '../../../core/abstracts/models/base.dart';
import '../../../core/utils.dart';

enum TickerType { marketCap, cmc100, rsi, pulse, etf, dominance, fearGreed, altcoinIndex, unknown }

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

class TickersModel implements CoreModelBase {
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
      throw ValidationException(AppErrorCode.tickerBasicInvalidTid, "tid cannot be empty.", "Please enter a transaction ID.");
    }
    if (tid == '0') {
      throw ValidationException(AppErrorCode.tickerBasicInvalidTid, "tid cannot be '0'.", "This transaction ID is not allowed.");
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

  @override
  Map<String, dynamic> toJson() => toMap();

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

    final val = double.tryParse(raw);
    if (val == null) {
      return raw;
    }

    switch (fmt) {
      case TickerFormat.nodecimal:
        return val.toStringAsFixed(0);

      case TickerFormat.normalNumber:
        return val.toStringAsFixed(2);

      case TickerFormat.normalCurrency:
        return "\$${Utils.formatSmartDouble(val, maxDecimals: 2)}";

      case TickerFormat.shortCurrency:
        return _formatShortCurrency(val);

      case TickerFormat.shortCurrencyWithSign:
        final sign = val < 0 ? "-" : "+";
        return "$sign${_formatShortCurrency(val.abs())}";

      case TickerFormat.percentage:
        return "$raw/100";

      case TickerFormat.shortPercentage:
        return "${val.toStringAsFixed(2)}%";

      case TickerFormat.shortPercentageWithSign:
        final sign = val < 0 ? "" : "+";
        return "$sign${val.toStringAsFixed(2)}%";

      case TickerFormat.raw:
        return raw;
    }
  }

  String _formatShortCurrency(double val) {
    if (val >= 1e12) return "${(val / 1e12).toStringAsFixed(2)}T";
    if (val >= 1e9) return "${(val / 1e9).toStringAsFixed(2)}B";
    if (val >= 1e6) return "${(val / 1e6).toStringAsFixed(2)}M";
    if (val >= 1e3) return "${(val / 1e3).toStringAsFixed(2)}K";
    return val.toStringAsFixed(2);
  }
}
