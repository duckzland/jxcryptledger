import 'dart:math';
import 'package:flutter/material.dart';

import '../../../app/content.dart';
import '../../../core/locator.dart';
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

  MarketsController get _controller => CoreLocator.getit<MarketsController>();

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
      padding: EdgeInsets.all(16),
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
                return WatchboardsMarketsWidgetsBubble(
                  key: ObjectKey(item),
                  tx: item['tx'] as MarketsModel,
                  x: item['x'] as double,
                  y: item['y'] as double,
                  radius: item['radius'] as double,
                  value: marketFilterableGetPercentageValue(item['tx'] as MarketsModel),
                  text: marketFilterableGetPercentageText(item['tx'] as MarketsModel),
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
    double margin = 12.0;
    int maxSlot = 100;

    if (currentSize.width < 1200) {
      maxRadius = 110.0;
      minRadius = 20.0;
      margin = 8.0;
      maxSlot = 50;
    }

    if (currentSize.width < 800) {
      maxRadius = 90.0;
      minRadius = 20.0;
      margin = 8.0;
      maxSlot = 40;
    }

    if (currentSize.width < 560) {
      maxRadius = 65.0;
      minRadius = 16.0;
      margin = 6.0;
      maxSlot = 25;
    }

    if (maxRadius > currentSize.width) maxRadius = currentSize.width / 2;
    if (maxRadius > currentSize.height) maxRadius = currentSize.height / 2;

    double angle = 0.0;
    final double ratio = (1 + sqrt(5)) / 2;

    slots.clear();

    for (int i = 0; i < maxSlot; i++) {
      double radius = minRadius;

      if (i == 0) {
        radius = maxRadius;
      } else if (i == 1) {
        radius = maxRadius * 0.90;
      } else if (i == 2) {
        radius = maxRadius * 0.80;
      } else if (i == 3) {
        radius = maxRadius * 0.73;
      } else if (i >= 4 && i <= 9) {
        radius = maxRadius * (0.66 - ((i - 4) * 0.03));
      } else if (i >= 10 && i <= 34) {
        radius = maxRadius * (0.46 - ((i - 10) * 0.015));
      }

      radius = radius.clamp(minRadius, maxRadius);

      double rDist = sqrt(i) * (maxRadius * 0.6);
      angle += ratio * 2 * pi;

      double startX = (currentSize.width / 2) + cos(angle) * rDist;
      double startY = (currentSize.height / 2) + sin(angle) * rDist;

      slots.add({
        'uuid': i.toString(),
        'radius': radius,
        'x': startX.clamp(radius, (currentSize.width - radius).clamp(radius, currentSize.width)),
        'y': startY.clamp(radius, (currentSize.height - radius).clamp(radius, currentSize.height)),
      });
    }

    final double gravityForce = 0.35;
    final int relaxationIterations = 90;
    final double centerX = currentSize.width / 2;
    final double centerY = currentSize.height / 2;

    for (int pass = 0; pass < relaxationIterations; pass++) {
      for (var b in slots) {
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

      for (int i = 0; i < slots.length; i++) {
        for (int j = i + 1; j < slots.length; j++) {
          final b1 = slots[i];
          final b2 = slots[j];

          final double b1X = b1['x'] as double;
          final double b1Y = b1['y'] as double;
          final double b1R = b1['radius'] as double;

          final double b2X = b2['x'] as double;
          final double b2Y = b2['y'] as double;
          final double b2R = b2['radius'] as double;

          double dx = b2X - b1X;
          double dy = b2Y - b1Y;
          double distance = sqrt(dx * dx + dy * dy);
          double minDist = b1R + b2R + margin;

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

    // Normalizing decimals to prevent flutter key become invalid too soon.
    for (final item in slots) {
      item['radius'] = double.parse(item['radius'].toStringAsFixed(2));
      item['x'] = double.parse(item['x'].toStringAsFixed(2));
      item['y'] = double.parse(item['y'].toStringAsFixed(2));
    }
  }

  void _assignBubbles() {
    if (txs.isEmpty) return;

    final atxs = [...txs];

    atxs.sort((a, b) => marketFilterableGetPercentageValue(b).abs().compareTo(marketFilterableGetPercentageValue(a).abs()));
    final activeItems = atxs.take(slots.length).toList();

    bubbles.clear();

    for (int i = 0; i < activeItems.length; i++) {
      final slot = slots[i];
      slot['tx'] = activeItems[i];
      bubbles.add(slot);
    }
  }

  void onMarketChange() {
    if (_controller.isBothEqualGroup(txs, _controller.items)) {
      return;
    }

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
