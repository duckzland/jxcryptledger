import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
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
  late Color _bgColor;

  @override
  void initState() {
    super.initState();
    _bgColor = widget.value >= 0 ? AppTheme.green : AppTheme.red;
  }

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

    final currentColor = widget.value >= 0 ? AppTheme.green : AppTheme.red;
    final fontSizeSymbol = (widget.radius * 0.36).clamp(8.0, 50.0);
    final fontSizePercent = (widget.radius * 0.28).clamp(8.0, 16.0);
    final showPercentage = widget.radius > 30.0;

    final symbolStyle = TextStyle(color: AppTheme.text, fontSize: fontSizeSymbol, fontWeight: FontWeight.w600, height: 1);
    final percentStyle = TextStyle(color: AppTheme.text, fontSize: fontSizePercent, fontWeight: FontWeight.w400);

    final textSize = measureText("#W${widget.tx.symbol}W#", symbolStyle);

    diameter += _calcExtraRadius(widget.value);

    if (diameter < textSize.width) {
      diameter = textSize.width;
      left = widget.x - (diameter / 2);
      top = widget.y - (diameter / 2);
    }

    diameter = double.parse(diameter.toStringAsFixed(2));
    top = double.parse(top.toStringAsFixed(2));
    left = double.parse(left.toStringAsFixed(2));

    Color prevColor = _bgColor;
    _bgColor = currentColor;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
      left: left,
      top: top,
      width: diameter,
      height: diameter,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(begin: showPercentage ? prevColor : currentColor, end: currentColor),
        curve: Curves.linear,
        duration: const Duration(milliseconds: 200),
        builder: (context, color, child) {
          return Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.background, width: 3.0),
            ),
            child: child,
          );
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              (showPercentage)
                  ? AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                      child: Text(
                        widget.tx.symbol.toUpperCase(),
                        key: ValueKey(widget.tx.symbol),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: symbolStyle,
                      ),
                    )
                  : Text(widget.tx.symbol.toUpperCase(), maxLines: 1, textAlign: TextAlign.center, style: symbolStyle),

              if (showPercentage) Text("${widget.value >= 0 ? '+' : ''}${widget.text}%", textAlign: TextAlign.center, style: percentStyle),
            ],
          ),
        ),
      ),
    );
  }

  Size measureText(String text, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    return painter.size;
  }

  double _calcExtraRadius(double value) {
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
