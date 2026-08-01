import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/log.dart';
import '../model.dart';

class WatchboardsMarketsWidgetsBubble extends StatefulWidget {
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
  State<WatchboardsMarketsWidgetsBubble> createState() => _WatchboardsMarketsWidgetsBubbleState();
}

class _WatchboardsMarketsWidgetsBubbleState extends State<WatchboardsMarketsWidgetsBubble> {
  @override
  void didUpdateWidget(covariant WatchboardsMarketsWidgetsBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.x != widget.x ||
        oldWidget.y != widget.y ||
        oldWidget.radius != widget.radius ||
        oldWidget.value != widget.value ||
        oldWidget.text != widget.text ||
        oldWidget.tx.symbol != widget.tx.symbol) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    double diameter = widget.radius * 2;
    double left = widget.x - widget.radius;
    double top = widget.y - widget.radius;

    final fontSizeSymbol = (widget.radius * 0.36).clamp(8.0, 50.0);
    final fontSizePercent = (widget.radius * 0.28).clamp(8.0, 16.0);
    final showPercentage = widget.radius > 30.0;

    final neededWidth = (widget.tx.symbol.length + 2) * (fontSizeSymbol * 0.8);
    if (diameter < neededWidth) {
      diameter = neededWidth;
      left = widget.x - (diameter / 2);
      top = widget.y - (diameter / 2);
    }

    diameter += calcExtraRadius(widget.value);

    logln("Bubbles ${widget.tx.symbol}, $top, $left, $diameter");

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.linear,
      left: left,
      top: top,
      width: diameter,
      height: diameter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: diameter,
        height: diameter,
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: widget.value >= 0 ? AppTheme.green : AppTheme.red,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.background, width: 3.0),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Text(
                  widget.tx.symbol.toUpperCase(),
                  key: ValueKey(widget.tx.symbol),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.text, fontSize: fontSizeSymbol, fontWeight: FontWeight.w600, height: 1),
                ),
              ),
              if (showPercentage)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                  child: Text(
                    "${widget.value >= 0 ? '+' : ''}${widget.text}%",
                    key: ValueKey(widget.value),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.text, fontSize: fontSizePercent, fontWeight: FontWeight.w400),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double calcExtraRadius(double value) {
    const double maxRadius = 10.0;
    if (value == 0) return 0.0;

    double absVal = value.abs();
    double magnitude = math.pow(10, (math.log(absVal) / math.log(10)).floor()).toDouble();
    double normalized = absVal / magnitude;

    if (normalized > 10.0) normalized = 10.0;
    double radius = (normalized / 10.0) * maxRadius;

    return value.isNegative ? -radius : radius;
  }
}
