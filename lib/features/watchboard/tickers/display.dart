import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/runtime/locator.dart';
import '../../../widgets/panel.dart';
import 'controller.dart';
import 'model.dart';

class TickersDisplay extends StatefulWidget {
  final TickersModel tix;
  final bool isDragging;

  const TickersDisplay({super.key, required this.tix, required this.isDragging});

  @override
  State<TickersDisplay> createState() => _TickersDisplayState();
}

class _TickersDisplayState extends State<TickersDisplay> {
  TickersController get _controller => locator<TickersController>();

  Color _currentColor = AppTheme.darkGrey;

  @override
  void initState() {
    super.initState();
    _currentColor = _resolveBackground();
  }

  @override
  void didUpdateWidget(covariant TickersDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_controller.isBothEqual(widget.tix, oldWidget.tix)) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final tix = widget.tix;

    final targetColor = _resolveBackground();
    bool colorChanged = targetColor != _currentColor;

    final hsl = HSLColor.fromColor(targetColor);
    final startColor = hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
    final mutedColor = Color.lerp(AppTheme.separator, targetColor, 0.70)!;
    _currentColor = targetColor;

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 300),
      tween: ColorTween(begin: colorChanged ? startColor : targetColor, end: targetColor),
      curve: Curves.easeInOut,
      builder: (context, Color? animatedBgColor, child) {
        return MouseRegion(
          cursor: widget.isDragging ? SystemMouseCursors.move : SystemMouseCursors.basic,
          child: WidgetsPanel(
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
                        style: const TextStyle(fontSize: 10, height: 1.3, fontWeight: FontWeight.w400),
                      ),
                      Text(
                        tix.getContent(),
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(fontSize: 18, height: 1.2, fontWeight: FontWeight.w600),
                      ),
                    ]
                  : [
                      Text(
                        "Loading...",
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(fontSize: 10, height: 1.4, fontWeight: FontWeight.w600),
                      ),
                    ],
            ),
          ),
        );
      },
    );
  }

  Color _resolveBackground() {
    final rawValue = widget.tix.value;
    final oldRawValue = widget.tix.meta['oldValue'] as String?;

    final current = double.tryParse(rawValue) ?? 0;
    final old = double.tryParse(oldRawValue ?? '') ?? 0;

    try {
      switch (widget.tix.getType()) {
        case TickerType.marketCap:
          if (current > old) return AppTheme.green;
          if (current < old) return AppTheme.red;
          return _currentColor;

        case TickerType.cmc100:
          if (current > old) return AppTheme.green;
          if (current < old) return AppTheme.red;
          return _currentColor;

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
          return _currentColor;

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
}
