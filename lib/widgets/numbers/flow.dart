import 'dart:math' as math;

import 'package:flutter/material.dart';

class WidgetsNumbersFlow extends StatelessWidget {
  final String? begin;
  final String end;
  final Duration duration;
  final Curve curve;
  final TextStyle style;
  final String prefix;
  final String suffix;

  const WidgetsNumbersFlow({
    super.key,
    required this.end,
    this.begin,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeInOut,
    this.style = const TextStyle(),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<String>(
      tween: WidgetsNumberFlowTween(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Text(
          '$prefix$value$suffix',
          style: style.copyWith(fontFeatures: [...(style.fontFeatures ?? []), const FontFeature.tabularFigures()]),
        );
      },
    );
  }
}

class WidgetsNumberFlowTween extends Tween<String> {
  WidgetsNumberFlowTween({String? begin, required String end}) : super(begin: begin ?? end, end: end);

  @override
  String lerp(double t) {
    final startValue = begin ?? end;
    final targetValue = end;

    final safeStartValue = (startValue ?? end).toString();
    final safeTargetValue = (targetValue ?? end).toString();

    if (safeStartValue.isEmpty && safeTargetValue.isEmpty) return '';

    final startChars = safeStartValue.split('');
    final targetChars = safeTargetValue.split('');
    final digitPositions = <int>[];

    for (int index = 0; index < targetChars.length; index++) {
      if (_isDigit(targetChars[index])) {
        digitPositions.add(index);
      }
    }

    final slotCount = math.max(1, digitPositions.length);
    final totalSteps = slotCount * 6;
    final progressIndex = (t.clamp(0.0, 1.0) * totalSteps).floor();
    final slotIndex = (progressIndex / 6).floor();
    final slotProgress = ((progressIndex % 6) / 6).clamp(0.0, 1.0);

    final activeDigits = <int>[];
    for (int digitOrder = 0; digitOrder < digitPositions.length; digitOrder++) {
      final position = digitPositions[digitOrder];
      final startChar = startChars.length > position ? startChars[position] : '0';
      final targetChar = targetChars[position];

      if (_isDigit(startChar) && _isDigit(targetChar) && startChar != targetChar) {
        activeDigits.add(digitOrder);
      }
    }

    final resultChars = List<String>.from(targetChars);
    for (int digitOrder = 0; digitOrder < digitPositions.length; digitOrder++) {
      final position = digitPositions[digitOrder];
      final startChar = startChars.length > position ? startChars[position] : '0';
      final targetChar = targetChars[position];

      if (!_isDigit(startChar) || !_isDigit(targetChar)) {
        resultChars[position] = targetChar;
        continue;
      }

      if (startChar == targetChar) {
        resultChars[position] = targetChar;
        continue;
      }

      final startDigit = int.parse(startChar);
      final targetDigit = int.parse(targetChar);
      final activeIndex = activeDigits.indexOf(digitOrder);

      if (activeIndex < 0) {
        resultChars[position] = targetChar;
      } else if (activeIndex < slotIndex) {
        resultChars[position] = targetChar;
      } else if (activeIndex == slotIndex) {
        resultChars[position] = _stepDigit(startDigit, targetDigit, slotProgress).toString();
      } else {
        resultChars[position] = startChar;
      }
    }

    return resultChars.join();
  }

  static bool _isDigit(String value) {
    return RegExp(r'\d').hasMatch(value);
  }

  static int _stepDigit(int start, int target, double progress) {
    if (start == target) return start;

    final span = (target - start).abs();
    final steps = span.clamp(1, 6);
    final stepIndex = (progress * steps).round();
    final direction = target >= start ? 1 : -1;
    return (start + (direction * stepIndex)).clamp(0, 9);
  }
}
