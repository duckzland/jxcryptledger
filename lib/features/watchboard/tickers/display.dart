import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../widgets/panel.dart';
import 'model.dart';

class TickersDisplay extends StatefulWidget {
  final TickersModel tix;

  const TickersDisplay({super.key, required this.tix});

  @override
  State<TickersDisplay> createState() => _TickersDisplayState();
}

class _TickersDisplayState extends State<TickersDisplay> {
  Color _currentColor = AppTheme.darkGrey;

  Color _resolveBackground(Color currentColor) {
    final rawValue = widget.tix.value;
    final oldRawValue = widget.tix.meta['oldValue'] as String?;

    final current = double.tryParse(rawValue) ?? 0;
    final old = double.tryParse(oldRawValue ?? '') ?? 0;

    try {
      switch (widget.tix.getType()) {
        case TickerType.marketCap:
          if (current > old) return AppTheme.green;
          if (current < old) return AppTheme.red;
          return currentColor;

        case TickerType.cmc100:
          if (current > old) return AppTheme.green;
          if (current < old) return AppTheme.red;
          return currentColor;

        case TickerType.rsi:
          final index = double.tryParse(rawValue) ?? 0;
          if (index >= 70) return AppTheme.green;
          if (index >= 55) return AppTheme.darkGreen;
          if (index >= 45) return AppTheme.darkGrey;
          if (index >= 30) return AppTheme.red;
          return AppTheme.red;

        case TickerType.pulse:
          final pulse = double.tryParse(rawValue.replaceAll("%", "")) ?? 0;
          if (pulse > 0) return AppTheme.green;
          if (pulse < 0) return AppTheme.red;
          return AppTheme.darkGrey;

        case TickerType.etf:
          if (current > 0) return AppTheme.green;
          if (current < 0) return AppTheme.red;
          return currentColor;

        case TickerType.dominance:
          final dom = double.tryParse(rawValue) ?? 0;
          return dom >= 50 ? AppTheme.green : AppTheme.red;

        case TickerType.fearGreed:
          final index = double.tryParse(rawValue) ?? 0;
          if (index >= 75) return AppTheme.green;
          if (index >= 55) return AppTheme.teal;
          if (index >= 45) return AppTheme.yellow;
          if (index >= 25) return AppTheme.orange;
          return AppTheme.red;

        case TickerType.altcoinIndex:
          final pct = int.tryParse(rawValue) ?? 0;
          if (pct >= 75) return Colors.blue;
          if (pct >= 50) return Colors.purple;
          if (pct >= 25) return AppTheme.orange;
          return AppTheme.darkRed;

        case TickerType.unknown:
          return AppTheme.darkGrey;
      }
    } catch (_) {
      return AppTheme.darkGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tix = widget.tix;

    final targetColor = _resolveBackground(_currentColor);
    final hsl = HSLColor.fromColor(targetColor);
    final startColor = hsl.withLightness((hsl.lightness + 0.3).clamp(0.0, 1.0)).toColor();
    final mutedColor = Color.lerp(AppTheme.separator, targetColor, 0.70)!;

    if (targetColor != _currentColor) {
      setState(() {
        _currentColor = targetColor;
      });
    }

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 500),
      tween: ColorTween(begin: startColor, end: targetColor),
      curve: Curves.easeOutQuart,
      builder: (context, Color? animatedBgColor, child) {
        return WidgetsPanel(
          padding: const EdgeInsets.all(0),
          background: animatedBgColor,
          borderColor: mutedColor,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: tix.getContent() != ""
                ? [
                    Text(
                      tix.getTitle(),
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11, height: 1),
                    ),
                    Text(
                      tix.getContent(),
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 20, height: 1.1, fontWeight: FontWeight.bold),
                    ),
                  ]
                : [
                    Text(
                      "Loading...",
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(height: 1.4, fontWeight: FontWeight.bold),
                    ),
                  ],
          ),
        );
      },
    );
  }
}
