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

    if (t <= 0.0) return safeStartValue;
    if (t >= 1.0) return safeTargetValue;

    if (safeStartValue.isEmpty && safeTargetValue.isEmpty) return '';

    final startChars = safeStartValue.split('');
    final targetChars = safeTargetValue.split('');
    final digitPositions = <int>[];

    for (int index = 0; index < targetChars.length; index++) {
      if (_isDigit(targetChars[index])) {
        digitPositions.add(index);
      }
    }

    if (digitPositions.isEmpty) return safeTargetValue;

    int firstChangingDigitOrder = -1;
    for (int digitOrder = 0; digitOrder < digitPositions.length; digitOrder++) {
      final position = digitPositions[digitOrder];
      final startChar = startChars.length > position ? startChars[position] : '0';
      final targetChar = targetChars[position];

      if (startChar != targetChar && _isDigit(startChar) && _isDigit(targetChar)) {
        firstChangingDigitOrder = digitOrder;
        break;
      }
    }

    if (firstChangingDigitOrder == -1) return safeTargetValue;

    final slotWeights = <double>[];
    double totalStepsSum = 0.0;

    for (int digitOrder = 0; digitOrder < digitPositions.length; digitOrder++) {
      if (digitOrder < firstChangingDigitOrder) {
        slotWeights.add(0.0);
        continue;
      }

      final position = digitPositions[digitOrder];
      final startChar = startChars.length > position ? startChars[position] : '0';
      final targetChar = targetChars[position];

      int sDigit = int.parse(_isDigit(startChar) ? startChar : '0');
      final tDigit = int.parse(_isDigit(targetChar) ? targetChar : '0');

      if (startChar == targetChar) {
        sDigit = 0;
      }

      final double distance = (tDigit - sDigit).abs().toDouble();
      final double weight = math.max(2.0, distance);

      slotWeights.add(weight);
      totalStepsSum += weight;
    }

    final accumulatedWeights = List<double>.filled(digitPositions.length, 0.0);
    double rightToLeftAccumulator = 0.0;

    for (int digitOrder = digitPositions.length - 1; digitOrder >= firstChangingDigitOrder; digitOrder--) {
      accumulatedWeights[digitOrder] = rightToLeftAccumulator;
      rightToLeftAccumulator += slotWeights[digitOrder];
    }

    const double staggerFactor = 0.4;
    final resultChars = List<String>.from(targetChars);

    for (int digitOrder = 0; digitOrder < digitPositions.length; digitOrder++) {
      final position = digitPositions[digitOrder];
      final startChar = startChars.length > position ? startChars[position] : '0';
      final targetChar = targetChars[position];

      if (!_isDigit(startChar) || !_isDigit(targetChar)) {
        resultChars[position] = targetChar;
        continue;
      }

      if (digitOrder < firstChangingDigitOrder) {
        resultChars[position] = targetChar;
        continue;
      }

      final double currentSlotWeight = slotWeights[digitOrder];
      final double slotStart = (accumulatedWeights[digitOrder] * staggerFactor) / totalStepsSum;
      final double slotEnd = (slotStart + (currentSlotWeight / totalStepsSum)).clamp(0.0, 1.0);

      double slotProgress = 0.0;
      if (t > slotStart) {
        slotProgress = ((t - slotStart) / (slotEnd - slotStart)).clamp(0.0, 1.0);
      }

      int startDigit = int.parse(startChar);
      final targetDigit = int.parse(targetChar);

      if (startChar == targetChar) {
        startDigit = 0;
      }

      resultChars[position] = _stepDigit(startDigit, targetDigit, slotProgress).toString();
    }

    return resultChars.join();
  }

  static bool _isDigit(String value) {
    return RegExp(r'\d').hasMatch(value);
  }

  static int _stepDigit(int start, int target, double progress) {
    if (progress <= 0.0) return start;
    if (progress >= 1.0) return target;
    return (start + (target - start) * progress).round().clamp(0, 9);
  }
}
