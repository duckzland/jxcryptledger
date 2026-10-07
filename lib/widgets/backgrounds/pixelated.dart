import 'dart:math';

import 'package:flutter/material.dart';

class WidgetsBackgroundsPixelated extends StatefulWidget {
  final Color color;
  final Widget child;

  const WidgetsBackgroundsPixelated({super.key, required this.color, required this.child});

  @override
  State<WidgetsBackgroundsPixelated> createState() => _WidgetsBackgroundsPixelatedState();
}

class _WidgetsBackgroundsPixelatedState extends State<WidgetsBackgroundsPixelated> {
  Color? _previousColor;

  @override
  void didUpdateWidget(covariant WidgetsBackgroundsPixelated oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      _previousColor = oldWidget.color;
    }
  }

  @override
  Widget build(BuildContext context) {
    final previousColor = _previousColor;

    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.color),
      duration: Duration(milliseconds: 1100),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeInOutSine,
      onEnd: () {
        if (_previousColor != null && mounted) {
          setState(() => _previousColor = null);
        }
      },
      builder: (context, progress, _) {
        return CustomPaint(
          painter: _PixelatedColorPainter(backgroundColor: widget.color, previousColor: previousColor, progress: progress),
          child: widget.child,
        );
      },
    );
  }
}

class _PixelatedColorPainter extends CustomPainter {
  final Color backgroundColor;
  final Color? previousColor;
  final double progress;

  const _PixelatedColorPainter({required this.backgroundColor, required this.previousColor, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    final oldColor = previousColor;
    if (oldColor == null) return;

    const pixelSize = 16.0;
    const maxDelay = 0.55;
    const transitionDuration = 0.95;
    final columns = (size.width / pixelSize).ceil();
    final rows = (size.height / pixelSize).ceil();
    final random = Random(0);
    final paint = Paint();

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final startTime = random.nextDouble() * maxDelay;
        final tileProgress = ((progress - startTime) / transitionDuration).clamp(0.0, 1.0);
        final easedProgress = Curves.fastEaseInToSlowEaseOut.transform(tileProgress);
        paint.color = Color.lerp(oldColor, backgroundColor, easedProgress)!;

        final left = column * pixelSize;
        final top = row * pixelSize;
        canvas.drawRect(
          Rect.fromLTRB(left, top, (left + pixelSize).clamp(0.0, size.width), (top + pixelSize).clamp(0.0, size.height)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelatedColorPainter oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor || previousColor != oldDelegate.previousColor || progress != oldDelegate.progress;
  }
}
