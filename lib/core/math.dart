import 'package:decimal/decimal.dart';

class Math {
  static double add(double a, double b) => _toDouble(Decimal.parse(a.toString()) + Decimal.parse(b.toString()));

  static double subtract(double a, double b) => _toDouble(Decimal.parse(a.toString()) - Decimal.parse(b.toString()));

  static double multiply(double a, double b) => _toDouble(Decimal.parse(a.toString()) * Decimal.parse(b.toString()));

  static double divide(double a, double b, {int scale = 18}) {
    if (b == 0.0) {
      return 0.0;
    }

    final da = Decimal.parse(a.toString());
    final db = Decimal.parse(b.toString());

    final rational = da / db;
    final decimalResult = rational.toDecimal(scaleOnInfinitePrecision: scale);

    return _toDouble(decimalResult);
  }

  static double _toDouble(Decimal d) => double.parse(d.toString());
}
