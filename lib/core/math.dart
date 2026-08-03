import 'package:decimal/decimal.dart';

class Math {
  static T add<T>(T a, T b) {
    if (a is double && b is double) {
      final da = Decimal.parse(a.toString());
      final db = Decimal.parse(b.toString());
      return double.parse((da + db).toString()) as T;
    }
    if (a is Decimal && b is Decimal) {
      return (a + b) as T;
    }
    throw ArgumentError('Unsupported type');
  }

  static T subtract<T>(T a, T b) {
    if (a is double && b is double) {
      final da = Decimal.parse(a.toString());
      final db = Decimal.parse(b.toString());
      return double.parse((da - db).toString()) as T;
    }
    if (a is Decimal && b is Decimal) {
      return (a - b) as T;
    }
    throw ArgumentError('Unsupported type');
  }

  static T multiply<T>(T a, T b) {
    if (a is double && b is double) {
      final da = Decimal.parse(a.toString());
      final db = Decimal.parse(b.toString());
      return double.parse((da * db).toString()) as T;
    }
    if (a is Decimal && b is Decimal) {
      return (a * b) as T;
    }
    throw ArgumentError('Unsupported type');
  }

  static T divide<T>(T a, T b, {int scale = 18}) {
    if (a is double && b is double) {
      if (b == 0.0) return 0.0 as T;
      final da = Decimal.parse(a.toString());
      final db = Decimal.parse(b.toString());
      final rational = da / db;
      final decimalResult = rational.toDecimal(scaleOnInfinitePrecision: scale);
      return double.parse(decimalResult.toString()) as T;
    }
    if (a is Decimal && b is Decimal) {
      if (b == Decimal.zero) return Decimal.zero as T;
      return (a / b).toDecimal(scaleOnInfinitePrecision: scale) as T;
    }
    throw ArgumentError('Unsupported type');
  }
}
