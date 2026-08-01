import 'dart:math';
import 'package:flutter/material.dart';

import '../../../app/content.dart';
import '../../../core/runtime/locator.dart';
import '../../../mixins/action_bar.dart';
import '../../../mixins/state.dart';
import '../../../widgets/separator.dart';
import '../markets/controller.dart';
import '../markets/mixins/filterable.dart';
import '../markets/model.dart';
import '../markets/widgets/bubble.dart';
import '../markets/widgets/notice.dart';

class WatchboardScreensBubble extends StatefulWidget {
  final Widget screenNavigation;
  const WatchboardScreensBubble({super.key, required this.screenNavigation});

  @override
  State<WatchboardScreensBubble> createState() => _WatchboardScreensBubbleState();
}

class _WatchboardScreensBubbleState extends State<WatchboardScreensBubble>
    with
        MixinsState,
        MixinsActionBar<WatchboardScreensBubble>,
        WatchboardMarketsMixinsFilterable<WatchboardScreensBubble>,
        SingleTickerProviderStateMixin {
  late List<MarketsModel> txs;
  List<Map<String, dynamic>> bubbles = [];
  List<Map<String, dynamic>> slots = [];

  Size _lastSize = Size.zero;
  Size _currentSize = Size.zero;

  MarketsController get _controller => locator<MarketsController>();

  @override
  String get marketFilterableKey => "px-group-bubbles";

  @override
  void initState() {
    super.initState();
    _controller.addListener(onMarketChange);
    _processTxs();
  }

  @override
  void dispose() {
    _controller.removeListener(onMarketChange);
    super.dispose();
  }

  @override
  void marketFilterableOnPriceFiltering(int value) => onMarketChange();

  @override
  void marketFilterableOnPercentFiltering(int value) => onMarketChange();

  @override
  Widget actionbarLeftAction() {
    List<Widget> navigation = [widget.screenNavigation];
    if (_controller.isNotEmpty()) {
      navigation = [widget.screenNavigation, const WidgetsSeparator(), marketFilterableRankFilters(), marketFilterablePercentFilters()];
    }
    return Row(mainAxisSize: MainAxisSize.min, spacing: 10, children: navigation);
  }

  @override
  Widget build(BuildContext context) {
    actionbarRegister("Crypto Bubbles");

    if (_controller.isEmpty()) {
      return WatchboardsMarketsWidgetsNotice(callback: () => setState(() {}));
    }

    return AppContent(
      boxConstraints: const BoxConstraints(maxWidth: 1600),
      padding: const EdgeInsets.all(16),
      spacing: 10,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            _currentSize = Size(constraints.maxWidth, constraints.maxHeight);

            if (_lastSize != _currentSize) {
              _generateSlots(_currentSize, _lastSize);
              _lastSize = _currentSize;
            }

            _assignBubbles();

            return Stack(
              children: bubbles.map((item) {
                final tx = item['tx'] as MarketsModel;
                return WatchboardsMarketsWidgetsBubble(
                  tx: tx,
                  x: item['x'] as double,
                  y: item['y'] as double,
                  radius: item['radius'] as double,
                  value: marketFilterableGetPercentageValue(tx),
                  text: marketFilterableGetPercentageText(tx),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _generateSlots(Size currentSize, Size oldSize) {
    if (txs.isEmpty || currentSize == Size.zero) return;

    double maxRadius = 150.0;
    double minRadius = 24.0;
    double bubbleMargin = 12.0;
    int maxAllowedBubbles = 100;

    if (currentSize.width < 1200) {
      maxRadius = 110.0;
      minRadius = 20.0;
      bubbleMargin = 8.0;
      maxAllowedBubbles = 50;
    }

    if (currentSize.width < 800) {
      maxRadius = 90.0;
      minRadius = 20.0;
      bubbleMargin = 8.0;
      maxAllowedBubbles = 40;
    }

    if (currentSize.width < 560) {
      maxRadius = 65.0;
      minRadius = 16.0;
      bubbleMargin = 6.0;
      maxAllowedBubbles = 25;
    }

    if (maxRadius > currentSize.width) maxRadius = currentSize.width / 2;
    if (maxRadius > currentSize.height) maxRadius = currentSize.height / 2;

    final List<Map<String, dynamic>> nextBubbles = [];
    final Map<String, Map<String, dynamic>> existingMap = {for (var b in slots) (b['uuid'] as String): b};

    double scaleX = (oldSize != Size.zero && oldSize.width > 0) ? currentSize.width / oldSize.width : 1.0;
    double scaleY = (oldSize != Size.zero && oldSize.height > 0) ? currentSize.height / oldSize.height : 1.0;

    double angle = 0.0;
    final double goldenRatio = (1 + sqrt(5)) / 2;

    for (int i = 0; i < maxAllowedBubbles; i++) {
      double targetRadius;
      if (i == 0) {
        targetRadius = maxRadius;
      } else if (i == 1) {
        targetRadius = maxRadius * 0.90;
      } else if (i == 2) {
        targetRadius = maxRadius * 0.80;
      } else if (i == 3) {
        targetRadius = maxRadius * 0.73;
      } else if (i >= 4 && i <= 9) {
        targetRadius = maxRadius * (0.66 - ((i - 4) * 0.03));
      } else if (i >= 10 && i <= 24) {
        targetRadius = maxRadius * (0.46 - ((i - 10) * 0.015));
      } else {
        targetRadius = minRadius;
      }

      targetRadius = targetRadius.clamp(minRadius, maxRadius);
      final double doubleRadius = targetRadius.toDouble();

      if (existingMap.containsKey(i.toString())) {
        final oldMap = existingMap[i.toString()]!;
        oldMap['radius'] = doubleRadius;

        oldMap['x'] = (oldMap['x'] as double) * scaleX;
        oldMap['y'] = (oldMap['y'] as double) * scaleY;

        nextBubbles.add(oldMap);
      } else {
        double rDist = sqrt(i) * (maxRadius * 0.6);
        angle += goldenRatio * 2 * pi;

        double startX = (currentSize.width / 2) + cos(angle) * rDist;
        double startY = (currentSize.height / 2) + sin(angle) * rDist;

        final double minX = doubleRadius;
        final double maxX = (currentSize.width - doubleRadius).clamp(minX, currentSize.width);
        final double minY = doubleRadius;
        final double maxY = (currentSize.height - doubleRadius).clamp(minY, currentSize.height);

        Map<String, dynamic> item = {
          'uuid': i.toString(),
          'radius': doubleRadius,
          'x': startX.clamp(minX, maxX),
          'y': startY.clamp(minY, maxY),
        };

        nextBubbles.add(item);
      }
    }

    const double gravityForce = 0.35;
    const int relaxationIterations = 90;
    final double centerX = currentSize.width / 2;
    final double centerY = currentSize.height / 2;

    for (int pass = 0; pass < relaxationIterations; pass++) {
      for (var b in nextBubbles) {
        final double bX = b['x'] as double;
        final double bY = b['y'] as double;
        final double bRadius = b['radius'] as double;

        double dx = centerX - bX;
        double dy = centerY - bY;
        double dist = sqrt(dx * dx + dy * dy);

        if (dist > 1.0) {
          b['x'] = bX + (dx / dist) * gravityForce;
          b['y'] = bY + (dy / dist) * gravityForce;
        }

        if ((b['x'] as double) - bRadius < 0) b['x'] = bRadius;
        if ((b['x'] as double) + bRadius > currentSize.width) b['x'] = currentSize.width - bRadius;
        if ((b['y'] as double) - bRadius < 0) b['y'] = bRadius;
        if ((b['y'] as double) + bRadius > currentSize.height) b['y'] = currentSize.height - bRadius;
      }

      for (int i = 0; i < nextBubbles.length; i++) {
        for (int j = i + 1; j < nextBubbles.length; j++) {
          final b1 = nextBubbles[i];
          final b2 = nextBubbles[j];

          final double b1X = b1['x'] as double;
          final double b1Y = b1['y'] as double;
          final double b1R = b1['radius'] as double;

          final double b2X = b2['x'] as double;
          final double b2Y = b2['y'] as double;
          final double b2R = b2['radius'] as double;

          double dx = b2X - b1X;
          double dy = b2Y - b1Y;
          double distance = sqrt(dx * dx + dy * dy);
          double minDist = b1R + b2R + bubbleMargin;

          if (distance < minDist) {
            double overlap = minDist - distance;
            double nx = distance == 0 ? 1.0 : dx / distance;
            double ny = distance == 0 ? 0.0 : dy / distance;

            b1['x'] = b1X - nx * overlap * 0.5;
            b1['y'] = b1Y - ny * overlap * 0.5;
            b2['x'] = b2X + nx * overlap * 0.5;
            b2['y'] = b2Y + ny * overlap * 0.5;
          }
        }
      }
    }

    slots = nextBubbles;
  }

  void _assignBubbles() {
    if (txs.isEmpty) return;

    final atxs = [...txs];
    final maxAllowedBubbles = slots.length;

    atxs.sort((a, b) => marketFilterableGetPercentageValue(b).abs().compareTo(marketFilterableGetPercentageValue(a).abs()));
    final activeItems = atxs.take(maxAllowedBubbles).toList();

    bubbles.clear();

    for (int i = 0; i < activeItems.length; i++) {
      final slot = slots[i];
      slot['tx'] = activeItems[i];
      bubbles.add(slot);
    }
  }

  void onMarketChange() {
    setState(() {
      _processTxs();
    });
  }

  void _processTxs() {
    txs = [..._controller.items];
    txs = txs.where((m) => !m.isStableCoin).toList();
    txs = marketFilterableFilter(txs);
    txs.sort((a, b) => a.rank.compareTo(b.rank));

    _assignBubbles();
  }
}
