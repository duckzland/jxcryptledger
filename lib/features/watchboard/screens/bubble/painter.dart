import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import 'data.dart';

class WatchboardScreensBubblePainter extends CustomPainter {
  final List<WatchboardScreensBubbleData> bubbles;
  WatchboardScreensBubblePainter(this.bubbles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final bubble in bubbles) {
      final r = bubble.data;
      final percent1h = r['_percent1h'] as double;

      paint.color = percent1h >= 0 ? AppTheme.green : AppTheme.red;
      canvas.drawCircle(Offset(bubble.x, bubble.y), bubble.radius, paint);

      final String symbolText = r['symbol'] ?? '';
      final String percentText = "${percent1h >= 0 ? '+' : ''}${r['percent1h']}%";

      final double fontSizeSymbol = (bubble.radius * 0.36).clamp(8.0, 50.0);
      final double fontSizePercent = (bubble.radius * 0.28).clamp(9.0, 16.0);

      final bool showPercentage = bubble.radius > 30.0;

      final symbolPainter = TextPainter(
        text: TextSpan(
          text: symbolText,
          style: TextStyle(color: AppTheme.text, fontSize: fontSizeSymbol, fontWeight: FontWeight.w600),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(minWidth: 0, maxWidth: bubble.radius * 1.8);

      TextPainter? percentPainter;
      if (showPercentage) {
        percentPainter = TextPainter(
          text: TextSpan(
            text: percentText,
            style: TextStyle(color: AppTheme.text, fontSize: fontSizePercent, fontWeight: FontWeight.w400),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(minWidth: 0, maxWidth: bubble.radius * 1.8);
      }

      double totalHeight = symbolPainter.height;
      if (percentPainter != null) {
        totalHeight += percentPainter.height;
      }

      double startY = bubble.y - (totalHeight / 2);

      symbolPainter.paint(canvas, Offset(bubble.x - (symbolPainter.width / 2), startY));

      if (percentPainter != null) {
        percentPainter.paint(canvas, Offset(bubble.x - (percentPainter.width / 2), startY + symbolPainter.height));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
