// test/math_test.dart

import 'package:decimal/decimal.dart';
import 'package:jxledger/core/math.dart';
import 'package:test/test.dart';

void main() {
  group('SafeMath sanity checks', () {
    test('Addition exact', () {
      expect(Math.add(1.23456789, 0.00000011).toString(), "1.234568");
    });

    test('Subtraction simple', () {
      expect(Math.subtract(3.8, 1.8).toString(), "2.0");
    });

    test('Subtraction precise', () {
      expect(Math.subtract(3.8, 1.88888888).toString(), "1.91111112");
    });

    test('Multiplication', () {
      expect(Math.multiply(0.00008, 1000000).toString(), "80.0");
    });

    test('Division', () {
      // Division can produce repeating decimals, so match prefix
      expect(Math.divide(3.8, 1.8).toString().startsWith("2.111111"), isTrue);
      expect(Math.divide(1.23456789, 0.1).toString(), "12.3456789");
    });
  });

  group('SafeMath weird edge cases', () {
    test('Tiny subtraction near zero', () {
      // Difference between two very close decimals
      expect(Math.subtract(0.00000001, 0.000000009).toString(), "0.000000001");
    });

    test('Huge addition', () {
      // Add two massive values
      expect(Math.add(999999999999.99999999, 0.00000001).toString(), "1000000000000.0");
    });

    test('Multiplication with extreme scale', () {
      // Multiply tiny by huge
      expect(Math.multiply(0.0000000000000001, 10000000000000000).toString(), "1.0");
    });

    test('Division with repeating decimal', () {
      final da = Decimal.parse("1");
      final db = Decimal.parse("3");
      final result = (da / db).toDecimal(scaleOnInfinitePrecision: 18).toString();
      expect(result, "0.333333333333333333");
    });

    test('Division with irrational-like ratio exact', () {
      final da = Decimal.parse("22");
      final db = Decimal.parse("7");
      final result = (da / db).toDecimal(scaleOnInfinitePrecision: 18).toString();
      expect(result, "3.142857142857142857");
    });

    test('Subtraction with many decimals exact', () {
      final da = Decimal.parse("123456789.123456789");
      final db = Decimal.parse("0.000000001");
      final result = (da - db).toString();
      expect(result, "123456789.123456788");
    });

    test('Addition of scientific notation doubles', () {
      // Doubles expressed in scientific notation
      expect(Math.add(8.0e-5, 2.0e-5).toString(), "0.0001");
    });
  });

  group('Crypto Math: Bitcoin (8 decimals)', () {
    test('1 BTC = 100,000,000 satoshis', () {
      final sats = Math.multiply(1.0, 100000000.0);
      expect(sats.toString(), "100000000.0");
    });

    test('0.00000001 BTC = 1 satoshi', () {
      final sats = Math.multiply(0.00000001, 100000000.0);
      expect(sats.toString(), "1.0");
    });

    test('Subtracting satoshis exact', () {
      final da = Decimal.parse("0.00000002");
      final db = Decimal.parse("0.00000001");
      final result = (da - db).toString();
      expect(result, "0.00000001");
    });

    test('Division: split 1 BTC among 3 people', () {
      final share = Math.divide(1.0, 3.0, scale: 8);
      expect(share.toString(), "0.33333333"); // 8‑decimal precision
    });
  });

  group('Crypto Math: Ethereum (18 decimals)', () {
    test('1 ETH = 1e18 wei', () {
      final wei = Math.multiply(1.0, 1000000000000000000.0);
      expect(wei.toString(), "1000000000000000000.0");
    });

    test('0.000000000000000001 ETH = 1 wei', () {
      final wei = Math.multiply(0.000000000000000001, 1000000000000000000.0);
      expect(wei.toString(), "1.0");
    });

    test('Subtracting wei exact', () {
      final da = Decimal.parse("0.000000000000000002");
      final db = Decimal.parse("0.000000000000000001");
      final result = (da - db).toString();
      expect(result, "0.000000000000000001");
    });

    test('Division: split 1 ETH among 7 people exact', () {
      final da = Decimal.parse("1");
      final db = Decimal.parse("7");
      final result = (da / db).toDecimal(scaleOnInfinitePrecision: 18).toString();
      expect(result, "0.142857142857142857");
    });
  });
}
