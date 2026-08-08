import 'package:decimal/decimal.dart';

class Math {
  static T add<T>(T a, T b) {
    if (a is double && b is double) {
      return double.parse((Decimal.parse(a.toString()) + Decimal.parse(b.toString())).toString()) as T;
    }
    if (a is Decimal && b is Decimal) {
      return (a + b) as T;
    }
    throw ArgumentError('Unsupported type');
  }

  static T subtract<T>(T a, T b) {
    if (a is double && b is double) {
      return double.parse((Decimal.parse(a.toString()) - Decimal.parse(b.toString())).toString()) as T;
    }
    if (a is Decimal && b is Decimal) {
      return (a - b) as T;
    }
    throw ArgumentError('Unsupported type');
  }

  static T multiply<T>(T a, T b) {
    if (a is double && b is double) {
      return double.parse((Decimal.parse(a.toString()) * Decimal.parse(b.toString())).toString()) as T;
    }
    if (a is Decimal && b is Decimal) {
      return (a * b) as T;
    }
    throw ArgumentError('Unsupported type');
  }

  static T divide<T>(T a, T b, {int scale = 18}) {
    if (a is double && b is double) {
      if (b == 0.0) return 0.0 as T;
      return double.parse((Decimal.parse(a.toString()) / Decimal.parse(b.toString())).toDecimal(scaleOnInfinitePrecision: scale).toString())
          as T;
    }
    if (a is Decimal && b is Decimal) {
      if (b == Decimal.zero) return Decimal.zero as T;
      return (a / b).toDecimal(scaleOnInfinitePrecision: scale) as T;
    }
    throw ArgumentError('Unsupported type');
  }
}
