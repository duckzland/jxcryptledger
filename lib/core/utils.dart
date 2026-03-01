import 'package:decimal/decimal.dart';

import 'log.dart';

class Utils {
  Utils._();

  static String formatSmartDouble(double value, {int maxDecimals = 6, int minDecimals = 0, int limitDecimals = 18}) {
    if (!value.isFinite) {
      if (value.isNaN) return 'NaN';
      return value >= 0 ? '∞' : '-∞';
    }

    Decimal dec = Decimal.parse(value.toStringAsFixed(limitDecimals));
    if (dec == Decimal.zero) return "0";

    int effectivePrecision = maxDecimals;

    if (value.abs() > 0 && value.abs() < 1) {
      String s = dec.toString();
      if (s.contains('.')) {
        String fraction = s.split('.')[1];
        int firstSignificantIndex = fraction.indexOf(RegExp(r'[1-9]'));

        if (firstSignificantIndex != -1) {
          effectivePrecision = firstSignificantIndex + maxDecimals;
        }
      }
    }

    if (effectivePrecision > limitDecimals) {
      effectivePrecision = limitDecimals;
    }

    dec = dec.round(scale: effectivePrecision);

    String s = dec.toString();

    if (!s.contains('.')) {
      return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    }

    final parts = s.split('.');
    String intPart = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    String fracPart = parts[1];

    fracPart = fracPart.replaceFirst(RegExp(r'0+$'), '');
    if (fracPart.length < minDecimals) {
      fracPart = fracPart.padRight(minDecimals, '0');
    }

    return fracPart.isEmpty ? intPart : '$intPart.$fracPart';
  }

  static String sanitizeNumber(String input) {
    return input.replaceAll(RegExp(r'[^0-9\.\-]'), '');
  }

  static int dateToTimestamp(DateTime? date) {
    final now = DateTime.now();
    final base = date ?? now;
    final mergedLocal = DateTime(base.year, base.month, base.day, now.hour, now.minute, now.second, now.millisecond, now.microsecond);

    return mergedLocal.toUtc().microsecondsSinceEpoch;
  }

  static String timestampToFormattedDate(int timestamp) {
    final date = DateTime.fromMicrosecondsSinceEpoch(sanitizeTimestamp(timestamp), isUtc: true).toLocal();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  static int sanitizeTimestamp(int timestamp) {
    logln("Trying to sanitize: $timestamp");
    if (timestamp < 10000000000) {
      return timestamp * 1000000;
    }

    if (timestamp < 100000000000000) {
      return timestamp * 1000;
    }

    return timestamp;
  }
}
