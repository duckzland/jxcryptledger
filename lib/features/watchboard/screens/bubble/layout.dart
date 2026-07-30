import 'dart:math';
import 'package:flutter/material.dart';

import '../../../../app/content.dart';
import '../../../../core/runtime/locator.dart';
import '../../../../core/utils.dart';
import '../../../../mixins/action_bar.dart';
import '../../markets/controller.dart';
import '../../markets/model.dart';
import 'data.dart';
import 'painter.dart';

class WatchboardScreensBubble extends StatefulWidget {
  final Widget screenNavigation;
  const WatchboardScreensBubble({super.key, required this.screenNavigation});

  @override
  State<WatchboardScreensBubble> createState() => _WatchboardScreensBubbleState();
}

class _WatchboardScreensBubbleState extends State<WatchboardScreensBubble>
    with MixinsActionBar<WatchboardScreensBubble>, SingleTickerProviderStateMixin {
  late List<MarketsModel> txs;
  List<WatchboardScreensBubbleData> bubbles = [];

  Size _lastSize = Size.zero;

  MarketsController get _controller => locator<MarketsController>();

  @override
  void initState() {
    super.initState();
    txs = [..._controller.items];
    _processTxs();
    _controller.addListener(onMarketChange);
  }

  @override
  void dispose() {
    _controller.removeListener(onMarketChange);
    super.dispose();
  }

  @override
  Widget actionbarLeftAction() {
    return Row(mainAxisSize: MainAxisSize.min, spacing: 10, children: [widget.screenNavigation]);
  }

  @override
  Widget build(BuildContext context) {
    actionbarRegister("Crypto Bubbles");

    return AppContent(
      boxConstraints: const BoxConstraints(maxWidth: 1600),
      padding: const EdgeInsets.all(16),
      spacing: 10,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final currentSize = Size(constraints.maxWidth, constraints.maxHeight);
            if (_lastSize != currentSize) {
              _lastSize = currentSize;
              _generateBubble(_lastSize);
            }
            return CustomPaint(size: currentSize, painter: WatchboardScreensBubblePainter(bubbles));
          },
        ),
      ],
    );
  }

  void _generateBubble(Size size) {
    if (txs.isEmpty || size == Size.zero) return;

    final dataList = _generateItems();
    if (dataList.isEmpty) return;

    final double maxRadius = min(size.width, size.height) * 0.15;
    final double minRadius = min(size.width, size.height) * 0.05;

    final rand = Random();
    final List<WatchboardScreensBubbleData> nextBubbles = [];

    final Map<String, WatchboardScreensBubbleData> existingMap = {for (var b in bubbles) b.data['uuid'].toString(): b};

    double angle = 0.0;
    double goldenRatio = (1 + sqrt(5)) / 2;

    for (int i = 0; i < dataList.length; i++) {
      final data = dataList[i];
      final String uuid = data['uuid'].toString();
      final double percent1h = data['_percent1h'] as double;

      double logScale = log(1.0 + percent1h.abs());
      double targetRadius = (minRadius + (logScale * 18.0)).clamp(minRadius, maxRadius);

      if (existingMap.containsKey(uuid)) {
        final existingBubble = existingMap[uuid]!;
        existingBubble.data = data;
        existingBubble.radius = targetRadius;
        nextBubbles.add(existingBubble);
      } else {
        double rDist = sqrt(i) * (maxRadius * 0.6);
        angle += goldenRatio * 2 * pi;

        double startX = (size.width / 2) + cos(angle) * rDist;
        double startY = (size.height / 2) + sin(angle) * rDist;

        nextBubbles.add(
          WatchboardScreensBubbleData(
            data: data,
            radius: targetRadius,
            x: startX.clamp(targetRadius, size.width - targetRadius),
            y: startY.clamp(targetRadius, size.height - targetRadius),
            vx: (rand.nextDouble() - 0.5) * 3.0,
            vy: (rand.nextDouble() - 0.5) * 3.0,
          ),
        );
      }
    }

    const double friction = 0.94;
    const double gravityForce = 0.06;
    const double bubbleMargin = 12.0;
    const int relaxationIterations = 90;

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    for (int pass = 0; pass < relaxationIterations; pass++) {
      for (var b in nextBubbles) {
        double dx = centerX - b.x;
        double dy = centerY - b.y;
        double dist = sqrt(dx * dx + dy * dy);

        if (dist > 1.0) {
          b.vx += (dx / dist) * gravityForce;
          b.vy += (dy / dist) * gravityForce;
        }

        b.vx *= friction;
        b.vy *= friction;
        b.x += b.vx;
        b.y += b.vy;

        if (b.x - b.radius < 0) {
          b.x = b.radius;
          b.vx = b.vx.abs() * 0.6;
        }
        if (b.x + b.radius > size.width) {
          b.x = size.width - b.radius;
          b.vx = -b.vx.abs() * 0.6;
        }
        if (b.y - b.radius < 0) {
          b.y = b.radius;
          b.vy = b.vy.abs() * 0.6;
        }
        if (b.y + b.radius > size.height) {
          b.y = size.height - b.radius;
          b.vy = -b.vy.abs() * 0.6;
        }
      }

      for (int step = 0; step < 2; step++) {
        for (int i = 0; i < nextBubbles.length; i++) {
          for (int j = i + 1; j < nextBubbles.length; j++) {
            final b1 = nextBubbles[i];
            final b2 = nextBubbles[j];

            double dx = b2.x - b1.x;
            double dy = b2.y - b1.y;
            double distance = sqrt(dx * dx + dy * dy);
            double minDist = b1.radius + b2.radius + bubbleMargin;

            if (distance < minDist) {
              double overlap = minDist - distance;
              double nx = distance == 0 ? 1.0 : dx / distance;
              double ny = distance == 0 ? 0.0 : dy / distance;

              b1.x -= nx * overlap * 0.5;
              b1.y -= ny * overlap * 0.5;
              b2.x += nx * overlap * 0.5;
              b2.y += ny * overlap * 0.5;

              double kx = b1.vx - b2.vx;
              double ky = b1.vy - b2.vy;
              double p = 2 * (nx * kx + ny * ky) / 2;

              b1.vx -= p * nx * 0.5;
              b1.vy -= p * ny * 0.5;
              b2.vx += p * nx * 0.5;
              b2.vy += p * ny * 0.5;
            }
          }
        }
      }
    }

    bubbles = nextBubbles;
  }

  List<Map<String, dynamic>> _generateItems() {
    final items = <Map<String, dynamic>>[];

    for (final m in txs) {
      items.add({
        'uuid': m.tid,
        'symbol': m.symbol,
        'percent1h': Utils.formatSmartDouble(m.percent1h ?? 0.0, maxDecimals: 2, smartDecimal: false),
        '_percent1h': m.percent1h ?? 0.0,
        '_hotness': (m.percent1h ?? 0.0).abs(),
      });
    }
    return items;
  }

  void onMarketChange() {
    txs = [..._controller.items];
    _processTxs();
    _generateBubble(_lastSize);
    setState(() {});
  }

  void _processTxs() {
    final stablecoins = {'usdt', 'usdc', 'dai', 'fdusd', 'usde', 'tusd', 'busd', 'pyusd', 'usdd', 'frax'};

    txs = txs.where((m) {
      if (m.rank < 1 || m.rank > 100) return false;

      final symbol = m.symbol.toLowerCase().trim();
      return !stablecoins.contains(symbol);
    }).toList();
  }
}
