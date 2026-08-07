import 'package:flutter_test/flutter_test.dart';
import 'package:jxledger/widgets/numbers/flow.dart';

void main() {
  group('WidgetsNumberFlowTween', () {
    test('animates simple decimal with suffix', () {
      final tween = WidgetsNumberFlowTween(begin: '2.19T', end: '2.20T');
      expect(tween.lerp(0.0), '2.19T');
      expect(tween.lerp(1.0), '2.20T');
      final mid = tween.lerp(0.5);
      expect(mid.contains('.'), isTrue);
      expect(mid.contains('T'), isTrue);
    });

    test('handles long numeric string', () {
      final begin = '000000000000123456789';
      final end = '999999999999987654321';
      final tween = WidgetsNumberFlowTween(begin: begin, end: end);

      expect(tween.lerp(0.0), begin);
      expect(tween.lerp(1.0), end);

      // Midway should still be same length and contain only digits
      final mid = tween.lerp(0.5);
      expect(mid.length, end.length);
      expect(RegExp(r'^\d+$').hasMatch(mid), isTrue);
    });

    test('handles shorter start vs longer end', () {
      final tween = WidgetsNumberFlowTween(begin: '123', end: '123456');
      expect(tween.lerp(0.0), '123');
      expect(tween.lerp(1.0), '123456');
      final mid = tween.lerp(0.5);
      expect(mid.startsWith('123'), isTrue);
    });

    test('preserves non-digit characters', () {
      final tween = WidgetsNumberFlowTween(begin: 'A1B2C3', end: 'A9B8C7');
      expect(tween.lerp(0.0), 'A1B2C3');
      expect(tween.lerp(1.0), 'A9B8C7');
      final mid = tween.lerp(0.5);
      expect(mid.startsWith('A'), isTrue);
      expect(mid.contains('B'), isTrue);
      expect(mid.contains('C'), isTrue);
    });

    test('handles leading zeros correctly', () {
      final tween = WidgetsNumberFlowTween(begin: '00123', end: '00999');
      expect(tween.lerp(0.0), '00123');
      expect(tween.lerp(1.0), '00999');
      final mid = tween.lerp(0.5);
      expect(mid.length, 5);
      expect(mid.startsWith('00'), isTrue);
    });
  });
}
