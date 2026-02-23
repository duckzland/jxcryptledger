import 'package:decimal/decimal.dart';

class Utils {
  Utils._();

  static String formatSmartDouble(double value, {int maxDecimals = 6, int minDecimals = 0, int limitDecimals = 18}) {
    // 1. Handle non-finite values (Infinity/NaN)
    if (!value.isFinite) {
      if (value.isNaN) return 'NaN';
      return value >= 0 ? '∞' : '-∞';
    }

    // 2. Convert to Decimal to avoid double precision errors
    // We use toStringAsFixed(limitDecimals) to ensure Decimal.parse
    // doesn't receive scientific notation like 1e-9
    Decimal dec = Decimal.parse(value.toStringAsFixed(limitDecimals));
    if (dec == Decimal.zero) return "0";

    // 3. Automatic Dust Logic: Calculate effective precision
    int effectivePrecision = maxDecimals;

    if (value.abs() > 0 && value.abs() < 1) {
      String s = dec.toString();
      if (s.contains('.')) {
        String fraction = s.split('.')[1];
        // Find the index of the first non-zero digit
        int firstSignificantIndex = fraction.indexOf(RegExp(r'[1-9]'));

        if (firstSignificantIndex != -1) {
          // effective = leading zeros + requested significant digits
          effectivePrecision = firstSignificantIndex + maxDecimals;
        }
      }
    }

    // Apply the hard cap (e.g., 18 for EVM chains)
    if (effectivePrecision > limitDecimals) {
      effectivePrecision = limitDecimals;
    }

    // 4. Round to the calculated precision
    dec = dec.round(scale: effectivePrecision);

    // 5. Build the output string
    String s = dec.toString();

    // Use a simple regex for the integer part's thousands separator
    if (!s.contains('.')) {
      return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    }

    final parts = s.split('.');
    String intPart = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    String fracPart = parts[1];

    // 6. Clean trailing zeros but respect minDecimals
    fracPart = fracPart.replaceFirst(RegExp(r'0+$'), '');
    if (fracPart.length < minDecimals) {
      fracPart = fracPart.padRight(minDecimals, '0');
    }

    return fracPart.isEmpty ? intPart : '$intPart.$fracPart';
  }
}
