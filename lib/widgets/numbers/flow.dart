import 'package:flutter/material.dart';

class WidgetsNumbersFlow extends StatelessWidget {
  final double? begin;
  final double end;
  final Duration duration;
  final Curve curve;
  final TextStyle style;
  final String prefix;
  final String suffix;
  final String Function(double)? formatter;

  const WidgetsNumbersFlow({
    super.key,
    required this.end,
    this.begin,
    this.prefix = '',
    this.suffix = '',
    this.formatter,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeInOut,
    this.style = const TextStyle(),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        final formatted = (formatter ?? (val) => val.toStringAsFixed(2))(value);
        return Text(
          '$prefix$formatted$suffix',
          style: style.copyWith(fontFeatures: [...(style.fontFeatures ?? []), const FontFeature.tabularFigures()]),
        );
      },
    );
  }
}
