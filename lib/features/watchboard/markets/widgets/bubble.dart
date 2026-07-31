import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../model.dart';

class WatchboardsMarketsWidgetsBubble extends StatelessWidget {
  final MarketsModel tx;
  final double x;
  final double y;
  final double radius;
  final double value;
  final String text;

  const WatchboardsMarketsWidgetsBubble({
    super.key,
    required this.tx,
    required this.x,
    required this.y,
    required this.radius,
    required this.value,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    double diameter = radius * 2;
    double left = x - radius;
    double top = y - radius;

    final fontSizeSymbol = (radius * 0.36).clamp(8.0, 50.0);
    final fontSizePercent = (radius * 0.28).clamp(8.0, 16.0);
    final showPercentage = radius > 30.0;

    final neededWidth = (tx.symbol.length + 2) * (fontSizeSymbol * 0.8);
    if (diameter < neededWidth) {
      diameter = neededWidth;
      left = x - (diameter / 2);
      top = y - (diameter / 2);
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.linear,
      left: left,
      top: top,
      width: diameter,
      height: diameter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: value >= 0 ? AppTheme.green : AppTheme.red,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.background, width: 3.0),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              Text(
                tx.symbol.toUpperCase(),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.text, fontSize: fontSizeSymbol, fontWeight: FontWeight.w600, height: 1),
              ),
              if (showPercentage)
                Text(
                  "${value >= 0 ? '+' : ''}$text%",
                  style: TextStyle(color: AppTheme.text, fontSize: fontSizePercent, fontWeight: FontWeight.w400),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
